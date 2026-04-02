import 'package:flutter_test/flutter_test.dart';
import 'package:pody/features/ai/domain/ai_models.dart';

void main() {
  test('AIVoiceProfile parses sample_audio_url from API payload', () {
    final profile = AIVoiceProfile.fromJson(const {
      'id': 'voice-1',
      'name': 'Zephyr',
      'provider': 'google',
      'provider_voice_id': 'Zephyr',
      'language_code': 'mul',
      'gender': 'female',
      'sample_audio_url':
          'https://storage.googleapis.com/tryapi-489314-pody-audio/voice-profiles/samples-mp3/zephyr.mp3',
    });

    expect(profile.name, 'Zephyr');
    expect(
      profile.sampleAudioUrl,
      'https://storage.googleapis.com/tryapi-489314-pody-audio/voice-profiles/samples-mp3/zephyr.mp3',
    );
  });
}
