import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:myapp/config/env.dart';
import 'package:myapp/models/ahvi_contact.dart';
import 'package:myapp/services/appwrite_service.dart';

class ContactService {
  ContactService({AppwriteService? appwriteService})
      : _appwriteService = appwriteService ?? AppwriteService();

  final AppwriteService _appwriteService;

  String get _baseUrl => Env.backendApiUrl.replaceAll(RegExp(r'/+$'), '');

  Future<Map<String, String>> _headers() async {
    final jwt = await _appwriteService.account.createJWT();
    final token = jwt.jwt;
    if (token.isEmpty) throw Exception('Could not create Appwrite JWT');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, String?> query = const {}]) {
    final filtered = <String, String>{};
    query.forEach((key, value) {
      if (value != null && value.trim().isNotEmpty) filtered[key] = value;
    });
    return Uri.parse('$_baseUrl$path').replace(queryParameters: filtered);
  }

  List<AhviContact> _contactsFromBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) return const [];
    final raw = decoded['contacts'] ?? decoded['items'] ?? [];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => AhviContact.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  AhviContact _contactFromBody(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      final raw = decoded['contact'];
      if (raw is Map) {
        return AhviContact.fromJson(Map<String, dynamic>.from(raw));
      }
    }
    throw Exception('Invalid contact response');
  }

  Exception _httpError(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['detail'] != null) {
        return Exception(decoded['detail'].toString());
      }
    } catch (_) {}
    return Exception('Contacts request failed (${response.statusCode})');
  }

  Future<List<AhviContact>> listContacts({String query = ''}) async {
    final response = await http
        .get(_uri('/api/contacts', {'q': query}), headers: await _headers())
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response);
    }
    return _contactsFromBody(response.body);
  }

  Future<AhviContact> createContact(AhviContactInput input) async {
    final response = await http
        .post(
          _uri('/api/contacts'),
          headers: await _headers(),
          body: jsonEncode(input.toJson()),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response);
    }
    return _contactFromBody(response.body);
  }

  Future<AhviContact> updateContact(
    String id,
    Map<String, dynamic> fields,
  ) async {
    final response = await http
        .patch(
          _uri('/api/contacts/$id'),
          headers: await _headers(),
          body: jsonEncode(fields),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response);
    }
    return _contactFromBody(response.body);
  }

  Future<void> deleteContact(String id) async {
    final response = await http
        .delete(_uri('/api/contacts/$id'), headers: await _headers())
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _httpError(response);
    }
  }
}
