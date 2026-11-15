import 'api_client.dart';

/// AI Coach suhbat xizmati — Railway API orqali.
class CoachService {
  CoachService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// AI Coach'ga xabar yuborish.
  Future<CoachReply> sendMessage(String message) async {
    final res = await _api.post('/coach/message', body: {'message': message});
    if (!res.isOk) throw ApiException(res.error ?? 'AI xato', statusCode: res.statusCode);
    final data = res.data as Map<String, dynamic>;
    return CoachReply(
      reply: data['reply'] as String,
      remainingMessages: data['remaining'] as int? ?? 0,
    );
  }

  /// Suhbat tarixini olish.
  Future<List<ChatMessage>> getHistory() async {
    final res = await _api.get('/coach/history');
    if (!res.isOk) return [];
    final list = res.data as List;
    return list.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Smart coach xabarini olish (dashboard uchun).
  Future<String?> getSmartMessage() async {
    final res = await _api.get('/coach/smart-message');
    if (!res.isOk) return null;
    final data = res.data as Map<String, dynamic>;
    return data['message'] as String?;
  }
}

class CoachReply {
  const CoachReply({required this.reply, this.remainingMessages = 0});
  final String reply;
  final int remainingMessages;
}

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.createdAt,
  });

  final String role; // "user" | "assistant"
  final String content;
  final String? createdAt;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      createdAt: json['created_at'] as String?,
    );
  }
}
