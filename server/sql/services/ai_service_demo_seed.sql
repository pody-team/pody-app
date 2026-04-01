BEGIN;

INSERT INTO voice_profiles (
  id,
  name,
  provider,
  provider_voice_id,
  language_code,
  gender,
  sample_audio_url,
  cost_credits_per_minute,
  is_active,
  metadata
)
VALUES
  ('71000000-0000-0000-0000-000000000001', 'Aoede', 'google', 'Aoede', 'mul', 'female', NULL, 0, true, '{"tts_voice_name":"Aoede","style":"Breezy","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000002', 'Charon', 'google', 'Charon', 'mul', 'male', NULL, 0, true, '{"tts_voice_name":"Charon","style":"Informative","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000003', 'Sulafat', 'google', 'Sulafat', 'mul', 'female', NULL, 0, true, '{"tts_voice_name":"Sulafat","style":"Warm","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000004', 'Fenrir', 'google', 'Fenrir', 'mul', 'male', NULL, 0, true, '{"tts_voice_name":"Fenrir","style":"Excitable","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000005', 'Puck', 'google', 'Puck', 'mul', 'male', NULL, 0, true, '{"tts_voice_name":"Puck","style":"Upbeat","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000006', 'Zephyr', 'google', 'Zephyr', 'mul', 'female', NULL, 0, true, '{"tts_voice_name":"Zephyr","style":"Bright","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000007', 'Kore', 'google', 'Kore', 'mul', 'female', NULL, 0, true, '{"tts_voice_name":"Kore","style":"Firm","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000008', 'Leda', 'google', 'Leda', 'mul', 'female', NULL, 0, true, '{"tts_voice_name":"Leda","style":"Youthful","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000009', 'Orus', 'google', 'Orus', 'mul', 'male', NULL, 0, true, '{"tts_voice_name":"Orus","style":"Firm","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000010', 'Callirrhoe', 'google', 'Callirrhoe', 'mul', 'female', NULL, 0, true, '{"tts_voice_name":"Callirrhoe","style":"Easy-going","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000011', 'Autonoe', 'google', 'Autonoe', 'mul', 'female', NULL, 0, true, '{"tts_voice_name":"Autonoe","style":"Bright","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000012', 'Enceladus', 'google', 'Enceladus', 'mul', 'male', NULL, 0, true, '{"tts_voice_name":"Enceladus","style":"Breathy","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000013', 'Iapetus', 'google', 'Iapetus', 'mul', 'male', NULL, 0, true, '{"tts_voice_name":"Iapetus","style":"Clear","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000014', 'Umbriel', 'google', 'Umbriel', 'mul', 'male', NULL, 0, true, '{"tts_voice_name":"Umbriel","style":"Easy-going","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000015', 'Algieba', 'google', 'Algieba', 'mul', 'male', NULL, 0, true, '{"tts_voice_name":"Algieba","style":"Smooth","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000016', 'Despina', 'google', 'Despina', 'mul', 'female', NULL, 0, true, '{"tts_voice_name":"Despina","style":"Smooth","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000017', 'Erinome', 'google', 'Erinome', 'mul', 'female', NULL, 0, true, '{"tts_voice_name":"Erinome","style":"Clear","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000018', 'Algenib', 'google', 'Algenib', 'mul', 'male', NULL, 0, true, '{"tts_voice_name":"Algenib","style":"Gravelly","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000019', 'Rasalgethi', 'google', 'Rasalgethi', 'mul', 'male', NULL, 0, true, '{"tts_voice_name":"Rasalgethi","style":"Informative","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000020', 'Laomedeia', 'google', 'Laomedeia', 'mul', 'female', NULL, 0, true, '{"tts_voice_name":"Laomedeia","style":"Upbeat","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000021', 'Achernar', 'google', 'Achernar', 'mul', 'female', NULL, 0, true, '{"tts_voice_name":"Achernar","style":"Soft","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000022', 'Alnilam', 'google', 'Alnilam', 'mul', 'male', NULL, 0, true, '{"tts_voice_name":"Alnilam","style":"Firm","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000023', 'Schedar', 'google', 'Schedar', 'mul', 'male', NULL, 0, true, '{"tts_voice_name":"Schedar","style":"Even","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000024', 'Gacrux', 'google', 'Gacrux', 'mul', 'female', NULL, 0, true, '{"tts_voice_name":"Gacrux","style":"Mature","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000025', 'Pulcherrima', 'google', 'Pulcherrima', 'mul', 'female', NULL, 0, true, '{"tts_voice_name":"Pulcherrima","style":"Forward","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000026', 'Achird', 'google', 'Achird', 'mul', 'male', NULL, 0, true, '{"tts_voice_name":"Achird","style":"Friendly","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000027', 'Zubenelgenubi', 'google', 'Zubenelgenubi', 'mul', 'male', NULL, 0, true, '{"tts_voice_name":"Zubenelgenubi","style":"Casual","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000028', 'Vindemiatrix', 'google', 'Vindemiatrix', 'mul', 'female', NULL, 0, true, '{"tts_voice_name":"Vindemiatrix","style":"Gentle","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000029', 'Sadachbia', 'google', 'Sadachbia', 'mul', 'male', NULL, 0, true, '{"tts_voice_name":"Sadachbia","style":"Lively","source":"gemini-2.5-flash-tts"}'::jsonb),
  ('71000000-0000-0000-0000-000000000030', 'Sadaltager', 'google', 'Sadaltager', 'mul', 'male', NULL, 0, true, '{"tts_voice_name":"Sadaltager","style":"Knowledgeable","source":"gemini-2.5-flash-tts"}'::jsonb)
ON CONFLICT (id) DO UPDATE
SET
  name = EXCLUDED.name,
  provider = EXCLUDED.provider,
  provider_voice_id = EXCLUDED.provider_voice_id,
  language_code = EXCLUDED.language_code,
  gender = EXCLUDED.gender,
  sample_audio_url = EXCLUDED.sample_audio_url,
  cost_credits_per_minute = EXCLUDED.cost_credits_per_minute,
  is_active = EXCLUDED.is_active,
  metadata = EXCLUDED.metadata,
  updated_at = now();

COMMIT;
