/// Represents a file attached to a chat message (image, document, audio).
enum AttachmentType { image, document, audio }

class Attachment {
  final String id;
  final String fileName;
  final AttachmentType type;
  final String? url;        // remote URL after upload
  final String? localPath;  // local path before upload
  final int? sizeBytes;

  const Attachment({
    required this.id,
    required this.fileName,
    required this.type,
    this.url,
    this.localPath,
    this.sizeBytes,
  });

  String get extension => fileName.split('.').last.toLowerCase();
}
