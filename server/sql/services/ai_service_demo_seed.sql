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
  (
    '71000000-0000-0000-0000-000000000001',
    'Nova',
    'google',
    'gemini-nova-vi-001',
    'vi',
    'neutral',
    'https://example.com/audio/voices/nova.mp3',
    0,
    true,
    '{"avatar_url":"https://picsum.photos/seed/ai-voice-nova/200/200"}'::jsonb
  ),
  (
    '71000000-0000-0000-0000-000000000002',
    'Mira',
    'google',
    'gemini-mira-vi-001',
    'vi',
    'female',
    'https://example.com/audio/voices/mira.mp3',
    0,
    true,
    '{"avatar_url":"https://picsum.photos/seed/ai-voice-mira/200/200"}'::jsonb
  ),
  (
    '71000000-0000-0000-0000-000000000003',
    'Lumi',
    'google',
    'gemini-lumi-vi-001',
    'vi',
    'female',
    'https://example.com/audio/voices/lumi.mp3',
    0,
    true,
    '{"avatar_url":"https://picsum.photos/seed/ai-voice-lumi/200/200"}'::jsonb
  ),
  (
    '71000000-0000-0000-0000-000000000004',
    'Minh Tra',
    'google',
    'gemini-minh-tra-vi-001',
    'vi',
    'neutral',
    'https://example.com/audio/voices/minh-tra.mp3',
    0,
    true,
    '{"avatar_url":"https://picsum.photos/seed/ai-voice-minh-tra/200/200"}'::jsonb
  ),
  (
    '71000000-0000-0000-0000-000000000005',
    'Atlas',
    'google',
    'gemini-atlas-vi-001',
    'vi',
    'male',
    'https://example.com/audio/voices/atlas.mp3',
    0,
    true,
    '{"avatar_url":"https://picsum.photos/seed/ai-voice-atlas/200/200"}'::jsonb
  )
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
