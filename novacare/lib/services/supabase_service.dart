import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/recent_activity.dart';
import '../models/chat_conversation.dart';

class SupabaseService {
  final _client = Supabase.instance.client;

  Future<void> logActivity(String type, String description) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('recent_activity').insert({
      'user_id': userId,
      'type': type,
      'description': description,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<RecentActivity>> fetchRecentActivities() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('recent_activity')
        .select()
        .eq('user_id', userId)
        .order('timestamp', ascending: false)
        .limit(5);

    return (response as List).map((e) => RecentActivity.fromMap(e)).toList();
  }

  // Chat conversation methods
  Future<String> createChatConversation(String title) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _client
        .from('chat_conversations')
        .insert({
          'user_id': userId,
          'title': title,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    return response['id'].toString();
  }

  Future<void> saveChatMessage(ChatMessage message) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('chat_messages').insert({
      'conversation_id': message.conversationId,
      'user_id': userId,
      'role': message.role,
      'text': message.text,
      'timestamp': message.timestamp.toIso8601String(),
      'type': message.type,
    });
  }

  Future<void> saveChatConversation(
    List<Map<String, dynamic>> messages, {
    String? conversationId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      String convId;

      if (conversationId == null) {
        // Create new conversation
        final title = ChatConversation.generateTitle(messages);
        convId = await createChatConversation(title);
      } else {
        convId = conversationId;
        // Update conversation timestamp
        await _client.from('chat_conversations').update({
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', convId);
      }

      // Save all messages
      final messagesToInsert = messages.map((msg) {
        final chatMessage = ChatMessage.fromLocalMessage(msg, convId);
        return {
          'conversation_id': convId,
          'user_id': userId,
          'role': chatMessage.role,
          'text': chatMessage.text,
          'timestamp': chatMessage.timestamp.toIso8601String(),
          'type': chatMessage.type,
        };
      }).toList();

      if (messagesToInsert.isNotEmpty) {
        await _client.from('chat_messages').insert(messagesToInsert);
      }
    } catch (e) {
      print('Error saving chat conversation: $e');
      rethrow;
    }
  }

  Future<List<ChatConversation>> fetchChatConversations() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('chat_conversations')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    return (response as List).map((e) => ChatConversation.fromMap(e)).toList();
  }

  Future<List<ChatMessage>> fetchChatMessages(String conversationId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    final response = await _client
        .from('chat_messages')
        .select()
        .eq('conversation_id', conversationId)
        .eq('user_id', userId)
        .order('timestamp', ascending: true);

    return (response as List).map((e) => ChatMessage.fromMap(e)).toList();
  }

  Future<void> deleteChatConversation(String conversationId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    // Delete messages first (due to foreign key constraint)
    await _client
        .from('chat_messages')
        .delete()
        .eq('conversation_id', conversationId)
        .eq('user_id', userId);

    // Delete conversation
    await _client
        .from('chat_conversations')
        .delete()
        .eq('id', conversationId)
        .eq('user_id', userId);
  }
}
