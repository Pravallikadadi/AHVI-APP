import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:myapp/config/env.dart';
import 'package:myapp/services/appwrite_service.dart';

Map<String, dynamic> _parseJsonMap(String payload) =>
    Map<String, dynamic>.from(jsonDecode(payload) as Map);

String _encodeBytes(Uint8List bytes) => base64Encode(bytes);

String _demoChatFallback(String query, String moduleContext) {
  final q = query.toLowerCase();
  final isStyle = moduleContext == 'style' || moduleContext == 'wardrobe';
  if (q.contains('joke')) {
    return 'Here is a tiny one: Why did the shirt get promoted? Because it had outstanding style.';
  }
  if (q.contains('how are you') || q == 'hi' || q == 'hello' || q == 'hey') {
    return 'I am here and ready. Ask me for an outfit, a capsule wardrobe, or just talk to me.';
  }
  if (isStyle ||
      q.contains('outfit') ||
      q.contains('wear') ||
      q.contains('style')) {
    return 'I will assume a smart casual look for now: choose one clean hero piece, pair it with a neutral base, and finish with footwear or an accessory that matches the occasion. If your wardrobe is synced, I will use those saved pieces first.';
  }
  return 'I can help with that. Tell me a little more, or ask me to style an outfit, plan your day, or build a capsule wardrobe.';
}

class BackendService {
  final String baseUrl = Env.backendApiUrl;
  final AppwriteService _appwriteService;

  BackendService({AppwriteService? appwriteService})
    : _appwriteService = appwriteService ?? AppwriteService();

  Future<String> _currentUserId() async {
    final user = await _appwriteService.getCurrentUser();

    if (user != null && user.$id.trim().isNotEmpty) {
      return user.$id.trim();
    }

    // Appwrite session may still be restoring on app start.
    // Use the last authenticated id only as a continuity fallback.
    final cachedUserId = await _appwriteService.getCachedUserId();
    if (cachedUserId != null && cachedUserId.trim().isNotEmpty) {
      return cachedUserId.trim();
    }

    // Never send user_1, empty string, ID.unique(), or any fake user id.
    throw StateError(
      'No authenticated Appwrite user. User must sign in before backend requests.',
    );
  }

  Future<Map<String, String>> _authHeaders() async {
    final jwt = await _appwriteService.account.createJWT();
    final token = jwt.jwt;
    if (token.isEmpty) throw Exception('Could not create Appwrite JWT');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Object _memoryPayload(String currentMemory) {
    final trimmed = currentMemory.trim();
    if (trimmed.isEmpty) return <String, dynamic>{};
    return {'summary': trimmed};
  }

  String _messageText(Map<String, dynamic> data) {
    final message = data['message'];
    if (message is String) return message;
    if (message is Map) return (message['content'] ?? '').toString();
    return data['response']?.toString() ??
        "I'm having trouble thinking right now.";
  }

  Map<String, dynamic> _normalizeChatResponse(Map<String, dynamic> data) {
    var cleanText = _messageText(data);
    var extractedChips = List<dynamic>.from(data['chips'] as List? ?? []);
    String? extractedBoardData =
        (data['board_ids'] != null && data['board_ids'].toString().isNotEmpty)
        ? data['board_ids'].toString()
        : null;
    String? extractedPackData;
    var hiddenMenuText = '';

    final chipsMatch = RegExp(r'\[CHIPS:\s*(.*?)\]').firstMatch(cleanText);
    if (chipsMatch != null) {
      extractedChips = chipsMatch
          .group(1)!
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      cleanText = cleanText.replaceAll(chipsMatch.group(0)!, '').trim();
    }

    final boardMatch = RegExp(
      r'\[STYLE_BOARD:\s*(.*?)\]',
    ).firstMatch(cleanText);
    if (boardMatch != null) {
      extractedBoardData = boardMatch.group(1);
      cleanText = cleanText.replaceAll(boardMatch.group(0)!, '').trim();
    }

    final packMatch = RegExp(r'\[PACK_LIST:\s*(.*?)\]').firstMatch(cleanText);
    if (packMatch != null) {
      extractedPackData = packMatch.group(1);
      hiddenMenuText = cleanText.replaceAll(packMatch.group(0)!, '').trim();
      cleanText = "I've prepared your custom packing menu.";
    }

    return {
      ...data,
      'message': {'role': 'assistant', 'content': cleanText},
      'message_text': cleanText,
      'chips': extractedChips,
      'board_ids': extractedBoardData,
      'pack_ids': extractedPackData,
      'full_menu_text': hiddenMenuText,
      'has_actions': extractedBoardData != null || extractedPackData != null,
    };
  }

  // Chat and styling engine.
  Future<Map<String, dynamic>> sendChatQuery(
    String query,
    String userId,
    List<Map<String, String>> chatHistory,
    String currentMemory, {
    bool isRetry = false,
    List<Map<String, dynamic>>? fetchedWardrobe,
    String moduleContext = 'chat',
    Map<String, dynamic>? userProfile,
  }) async {
    try {
      final authedUserId = await _currentUserId();
      var wardrobeForRequest = fetchedWardrobe;
      if (wardrobeForRequest == null &&
          (moduleContext == 'style' || moduleContext == 'wardrobe')) {
        try {
          wardrobeForRequest = await _appwriteService.getWardrobeItems();
        } catch (_) {
          wardrobeForRequest = const [];
        }
      }
      final safeWardrobePayload = (wardrobeForRequest ?? []).map((item) {
        final copy = Map<String, dynamic>.from(item);
        return copy;
      }).toList();
      final historyForRequest = List<Map<String, String>>.from(chatHistory);
      if (historyForRequest.isEmpty ||
          historyForRequest.last['role'] != 'user' ||
          historyForRequest.last['content'] != query) {
        historyForRequest.add({'role': 'user', 'content': query});
      }

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/text'),
            headers: await _authHeaders(),
            body: jsonEncode({
              'messages': historyForRequest,
              'language': 'en',
              'current_memory': _memoryPayload(currentMemory),
              'user_profile': {...?userProfile, 'user_id': authedUserId},
              'user_id': authedUserId,
              'module_context': moduleContext,
              'include_base64':
                  moduleContext == 'style' || moduleContext == 'wardrobe',
              if (safeWardrobePayload.isNotEmpty)
                'wardrobe': safeWardrobePayload,
            }),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode == 200) {
        final data = await compute(_parseJsonMap, response.body);

        if (data['requires_wardrobe'] == true && !isRetry) {
          final items = await _appwriteService.getWardrobeItems();
          return sendChatQuery(
            query,
            authedUserId,
            chatHistory,
            currentMemory,
            isRetry: true,
            fetchedWardrobe: items,
            moduleContext: moduleContext,
            userProfile: userProfile,
          );
        }

        return _normalizeChatResponse(data);
      }

      throw Exception(
        'Failed to get AI response: ${response.statusCode} ${response.body}',
      );
    } catch (e) {
      debugPrint('Backend Error: $e');
      final fallback = _demoChatFallback(query, moduleContext);
      return {
        'error': 'Backend fallback: $e',
        'message': {'role': 'assistant', 'content': fallback},
        'message_text': fallback,
        'meta': {'used_local_fallback': true},
      };
    }
  }

  // Wardrobe vision and background removal.
  Future<String?> removeBackground(String base64Image) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/background/remove-bg'),
            headers: await _authHeaders(),
            body: jsonEncode({'image_base64': base64Image}),
          )
          .timeout(const Duration(seconds: 45));
      if (response.statusCode == 200) {
        final data = await compute(_parseJsonMap, response.body);
        return data['image_base64'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Background removal error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> analyzeImage(
    Uint8List imageBytes, {
    bool autoSave = false,
    bool saveDuplicates = false,
  }) async {
    try {
      final base64String = await compute(_encodeBytes, imageBytes);
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/wardrobe/capture/analyze'),
            headers: await _authHeaders(),
            body: jsonEncode({
              'user_id': await _currentUserId(),
              'image_base64': base64String,
              'auto_save': autoSave,
              'save_duplicates': saveDuplicates,
            }),
          )
          .timeout(const Duration(seconds: 55));

      if (response.statusCode == 200) {
        return await compute(_parseJsonMap, response.body);
      }

      debugPrint(
        'Analyze API failed: ${response.statusCode} - ${response.body}',
      );
      return null;
    } catch (e) {
      debugPrint('Garment analysis error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> saveWardrobeLabels(
    List<Map<String, dynamic>> detectedItems,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/wardrobe/capture/save-selected'),
            headers: await _authHeaders(),
            body: jsonEncode({
              'user_id': await _currentUserId(),
              'selected_item_ids': detectedItems
                  .map((item) => item['item_id']?.toString() ?? '')
                  .where((id) => id.isNotEmpty)
                  .toList(),
              'detected_items': detectedItems,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return await compute(_parseJsonMap, response.body);
      }

      debugPrint(
        'Wardrobe label save failed: ${response.statusCode} - ${response.body}',
      );
      return null;
    } catch (e) {
      debugPrint('Wardrobe label save error: $e');
      return null;
    }
  }

  Future<bool> scheduleReminder({
    required String eventId,
    required String message,
    required DateTime sendAt,
    String source = 'app',
    String priority = 'light',
    int offsetMinutes = 0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/notifications/reminders/schedule'),
        headers: await _authHeaders(),
        body: jsonEncode({
          'eventId': eventId,
          'source': source,
          'reminders': [
            {
              'sendAtISO': sendAt.toUtc().toIso8601String(),
              'message': message,
              'priority': priority,
              'offsetMinutes': offsetMinutes,
            },
          ],
        }),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      debugPrint('Reminder schedule error: $e');
      return false;
    }
  }
}
