enum MessageRole { user, assistant }

class ChatMessage {
  final String content;
  final MessageRole role;
  final DateTime timestamp;

  const ChatMessage({
    required this.content,
    required this.role,
    required this.timestamp,
  });

  Map<String, String> toApiFormat() => {
    'role': role == MessageRole.user ? 'user' : 'assistant',
    'content': content,
  };

  Map<String, dynamic> toFirestore() => {
    'role': role.name,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ChatMessage.fromFirestore(Map<String, dynamic> data) {
    return ChatMessage(
      content: data['content'] as String,
      role: data['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
      timestamp: DateTime.parse(data['timestamp'] as String),
    );
  }
}