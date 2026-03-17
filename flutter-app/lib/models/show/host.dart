class Host {
  final String id;
  final String name;
  final String avatarUrl;
  final String? voiceId; // ID giọng nói AI (TTS)
  final String role; // 'host', 'co-host', 'guest'

  const Host({
    required this.id,
    required this.name,
    required this.avatarUrl,
    this.voiceId,
    this.role = 'host',
  });
}
