#!/usr/bin/env python3
"""
align.py - Dialogue-aware transcript alignment for Pody episodes.

Adapted from the legacy project:
- tries MMS forced alignment first when torch/torchaudio are available
- falls back to proportional alignment when MMS is unavailable or disabled
"""

from __future__ import annotations

import json
import os
import re
import sys
import unicodedata
import warnings
from datetime import datetime

warnings.filterwarnings("ignore")

MAX_THREADS = os.environ.get("ALIGN_THREADS", "8")
os.environ["OMP_NUM_THREADS"] = MAX_THREADS
os.environ["MKL_NUM_THREADS"] = MAX_THREADS
os.environ["OPENBLAS_NUM_THREADS"] = MAX_THREADS
os.environ["VECLIB_MAXIMUM_THREADS"] = MAX_THREADS
os.environ["NUMEXPR_NUM_THREADS"] = MAX_THREADS

LOG_PATH: str | None = None


def log(message: str) -> None:
    try:
        timestamp = datetime.now().isoformat()
        print(f"[{timestamp}] {message}")
        if LOG_PATH:
            with open(LOG_PATH, "a", encoding="utf-8") as handle:
                handle.write(f"[{timestamp}] {message}\n")
    except Exception:
        return


def normalize_for_alignment(text: str) -> str:
    text = text.lower().replace("đ", "d").replace("Đ", "d")
    nfkd = unicodedata.normalize("NFD", text)
    result = "".join(ch for ch in nfkd if not unicodedata.combining(ch))
    result = re.sub(r"[^a-z\s]", "", result)
    return " ".join(result.split())


def load_audio_custom(audio_path: str):
    import wave

    import numpy as np
    import torch

    with wave.open(audio_path, "rb") as wav_file:
        sample_rate = wav_file.getframerate()
        frame_count = wav_file.getnframes()
        channels = wav_file.getnchannels()
        sample_width = wav_file.getsampwidth()
        frames = wav_file.readframes(frame_count)

    if sample_width == 2:
        dtype = np.int16
        max_value = 32768.0
    elif sample_width == 1:
        dtype = np.uint8
        max_value = 128.0
    else:
        raise ValueError(f"Unsupported bit width: {sample_width}")

    audio_np = np.frombuffer(frames, dtype=dtype).astype(np.float32)
    if sample_width == 1:
        audio_np = (audio_np - 128) / max_value
    else:
        audio_np = audio_np / max_value

    if channels > 1:
        audio_np = audio_np.reshape(-1, channels).T
    else:
        audio_np = audio_np.reshape(1, -1)
    return torch.from_numpy(audio_np), sample_rate


def align_with_mms(audio_path: str, dialogue: list[dict[str, object]]):
    import gc

    import torch
    import torchaudio

    torch.set_num_threads(int(MAX_THREADS))
    torch.set_num_interop_threads(1)

    requested_device = os.environ.get("ALIGN_DEVICE", "").lower().strip()
    if requested_device == "cpu":
        device = torch.device("cpu")
    elif requested_device == "mps" and torch.backends.mps.is_available():
        device = torch.device("mps")
    elif requested_device == "cuda" and torch.cuda.is_available():
        device = torch.device("cuda")
    elif torch.backends.mps.is_available():
        device = torch.device("mps")
    elif torch.cuda.is_available():
        device = torch.device("cuda")
    else:
        device = torch.device("cpu")

    log(f"Using alignment device: {device}")
    bundle = torchaudio.pipelines.MMS_FA
    try:
        model = bundle.get_model().to(device)
    except Exception as exc:
        log(f"Failed to load MMS model on {device}: {exc}. Falling back to CPU.")
        device = torch.device("cpu")
        model = bundle.get_model().to(device)

    tokenizer = bundle.get_tokenizer()
    aligner = bundle.get_aligner()
    try:
        waveform, sample_rate = load_audio_custom(audio_path)
    except Exception as exc:
        log(f"Custom WAV loader failed: {exc}. Falling back to torchaudio.load.")
        waveform, sample_rate = torchaudio.load(audio_path)

    if waveform.shape[0] > 1:
        waveform = waveform.mean(dim=0, keepdim=True)
    if sample_rate != bundle.sample_rate:
        waveform = torchaudio.functional.resample(waveform, sample_rate, bundle.sample_rate)

    total_duration = waveform.shape[1] / bundle.sample_rate
    all_normalized_words: list[str] = []
    all_original_words: list[str] = []
    turn_word_counts: list[int] = []
    for turn in dialogue:
        text = str(turn.get("text") or "").strip()
        original_words = text.split()
        normalized_words = [word for word in normalize_for_alignment(text).split() if word]
        if len(normalized_words) != len(original_words):
            original_words = [re.sub(r"[^\w\s]", "", word).strip() for word in original_words]
            original_words = [word for word in original_words if word]
            while len(original_words) < len(normalized_words):
                original_words.append("")
            original_words = original_words[: len(normalized_words)]
        if not normalized_words:
            normalized_words = ["a"]
            original_words = [""]
        all_normalized_words.extend(normalized_words)
        all_original_words.extend(original_words)
        turn_word_counts.append(len(normalized_words))

    tokens = tokenizer(all_normalized_words)
    unique_tokens: set[int] = {0}
    for token_list in tokens:
        unique_tokens.update(token_list)
    sorted_indices = sorted(unique_tokens)
    old_to_new = {old: new for new, old in enumerate(sorted_indices)}
    new_tokens = [[old_to_new[token] for token in token_list] for token_list in tokens]

    chunk_seconds = 30
    chunk_samples = int(chunk_seconds * bundle.sample_rate)
    emissions_list = []
    total_samples = waveform.shape[1]
    device_indices = torch.tensor(sorted_indices, device=device)
    log(f"Running MMS alignment with compact vocab of {len(sorted_indices)} tokens")
    with torch.no_grad():
        try:
            for start in range(0, total_samples, chunk_samples):
                end = min(start + chunk_samples, total_samples)
                chunk = waveform[:, start:end].to(device)
                emission, _ = model(chunk)
                subset = emission[0].index_select(1, device_indices)
                emissions_list.append(subset.cpu())
                del chunk, emission, subset
                if device.type == "mps":
                    torch.mps.empty_cache()
                elif device.type == "cuda":
                    torch.cuda.empty_cache()
        except RuntimeError as exc:
            if device.type == "cpu":
                raise
            log(f"GPU alignment failed: {exc}. Re-running on CPU.")
            device = torch.device("cpu")
            model = model.to(device)
            device_indices = device_indices.to(device)
            emissions_list = []
            for start in range(0, total_samples, chunk_samples):
                end = min(start + chunk_samples, total_samples)
                chunk = waveform[:, start:end].to(device)
                emission, _ = model(chunk)
                subset = emission[0].index_select(1, device_indices)
                emissions_list.append(subset)

    full_emission = torch.cat(emissions_list, dim=0)
    word_spans = aligner(full_emission, new_tokens)
    num_frames = full_emission.shape[0] if full_emission.dim() == 2 else full_emission.shape[1]
    ratio = waveform.shape[1] / num_frames / bundle.sample_rate

    all_word_times = []
    for index, char_spans in enumerate(word_spans):
        if char_spans:
            word_start = round(char_spans[0].start * ratio, 2)
            word_end = round(char_spans[-1].end * ratio, 2)
        else:
            word_start = 0.0
            word_end = 0.0
        all_word_times.append(
            {
                "start": word_start,
                "end": word_end,
                "text": all_original_words[index],
            }
        )

    segments = []
    word_index = 0
    for index, count in enumerate(turn_word_counts):
        turn_words = all_word_times[word_index : word_index + count]
        if turn_words:
            start_time = turn_words[0]["start"]
            end_time = turn_words[-1]["end"]
        else:
            previous_end = segments[-1]["end"] if segments else 0.0
            start_time = previous_end
            end_time = previous_end
        segments.append(
            {
                "start": start_time,
                "end": end_time,
                "text": str(dialogue[index].get("text") or "").strip(),
                "speaker": dialogue[index].get("speaker"),
                "words": turn_words,
            }
        )
        word_index += count

    if segments:
        segments[-1]["end"] = round(total_duration, 2)
    for index in range(1, len(segments)):
        if segments[index]["start"] < segments[index - 1]["end"]:
            midpoint = (segments[index]["start"] + segments[index - 1]["end"]) / 2
            segments[index - 1]["end"] = round(midpoint, 2)
            segments[index]["start"] = round(midpoint, 2)
            segments[index - 1]["end"] = segments[index]["start"]

    del model, tokenizer, aligner, waveform, full_emission
    gc.collect()
    return segments, total_duration


def align_proportional(audio_path: str, dialogue: list[dict[str, object]]):
    import wave

    try:
        with wave.open(audio_path, "rb") as wav_file:
            total_duration = wav_file.getnframes() / wav_file.getframerate()
    except Exception:
        size = os.path.getsize(audio_path)
        total_duration = max(1.0, (size - 44) / (24000 * 2))

    segments = []
    current = 0.0
    all_turn_words = [str(turn.get("text") or "").strip().split() for turn in dialogue]
    total_words = sum(len(words) if words else 1 for words in all_turn_words)
    for index, words in enumerate(all_turn_words):
        count = len(words) if words else 1
        proportion = count / total_words if total_words > 0 else 1.0 / max(1, len(dialogue))
        segment_duration = total_duration * proportion
        segment_start = round(current, 2)
        segment_end = round(current + segment_duration, 2)
        word_segments = []
        if words:
            word_duration = segment_duration / len(words)
            word_cursor = segment_start
            for word in words:
                word_segments.append(
                    {
                        "start": round(word_cursor, 2),
                        "end": round(word_cursor + word_duration, 2),
                        "text": word,
                    }
                )
                word_cursor += word_duration
        segments.append(
            {
                "start": segment_start,
                "end": segment_end,
                "text": " ".join(words) if words else str(dialogue[index].get("text") or "").strip(),
                "speaker": dialogue[index].get("speaker"),
                "words": word_segments,
            }
        )
        current += segment_duration
    if segments:
        segments[-1]["end"] = round(total_duration, 2)
    return segments, total_duration


def main() -> None:
    global LOG_PATH
    if len(sys.argv) < 4:
        print(json.dumps({"success": False, "error": "Usage: align.py <audio> <dialogue.json> <output.json>"}))
        sys.exit(1)

    audio_path = sys.argv[1]
    dialogue_path = sys.argv[2]
    output_path = sys.argv[3]
    LOG_PATH = os.path.join(os.path.dirname(output_path), "align_log.txt")

    with open(dialogue_path, "r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if isinstance(payload, list):
        dialogue = payload
    elif isinstance(payload, dict):
        dialogue = payload.get("dialogue", [])
    else:
        dialogue = []
    if not dialogue:
        print(json.dumps({"success": False, "error": "Empty dialogue"}))
        sys.exit(1)

    align_mode = os.environ.get("ALIGN_MODE", "auto").strip().lower() or "auto"
    if align_mode not in {"auto", "mms", "proportional"}:
        align_mode = "auto"

    method = "proportional"
    try:
        if align_mode == "proportional":
            segments, total_duration = align_proportional(audio_path, dialogue)
        else:
            try:
                segments, total_duration = align_with_mms(audio_path, dialogue)
                method = "mms_fa"
            except Exception as exc:
                if align_mode == "mms":
                    raise
                log(f"MMS alignment unavailable, falling back to proportional: {exc}")
                segments, total_duration = align_proportional(audio_path, dialogue)
                method = "proportional"
    except Exception as exc:
        print(json.dumps({"success": False, "error": f"Alignment failed: {exc}"}))
        sys.exit(1)

    transcript = {
        "segments": segments,
        "text": " ".join(str(turn.get("text") or "").strip() for turn in dialogue).strip(),
        "language": "vi",
        "duration": round(total_duration, 2),
        "alignment_method": method,
    }
    with open(output_path, "w", encoding="utf-8") as handle:
        json.dump(transcript, handle, ensure_ascii=False, indent=2)
    print(
        json.dumps(
            {
                "success": True,
                "path": os.path.basename(output_path),
                "segments_count": len(segments),
                "duration": round(total_duration, 2),
                "method": method,
            }
        )
    )


if __name__ == "__main__":
    main()
