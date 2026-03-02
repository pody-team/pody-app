import 'attachment.dart';
import 'production_plan.dart';

/// Role of a chat message in the creation flow.
enum ChatRole { user, assistant, system }

/// A single message in the AI creation chat.
class ChatMessage {
  final String id;
  final ChatRole role;
  final String text;
  final DateTime timestamp;
  final List<Attachment> attachments;
  final ProductionPlan? plan; // non-null when assistant returns a plan card

  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.timestamp,
    this.attachments = const [],
    this.plan,
  });

  bool get hasPlan => plan != null;
  bool get hasAttachments => attachments.isNotEmpty;
}

/// The full conversation thread for creating a podcast.
class ChatThread {
  final String id;
  final String title;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ChatThread({
    required this.id,
    this.title = 'New Podcast',
    this.messages = const [],
    required this.createdAt,
    required this.updatedAt,
  });
}
