import 'dart:convert';

import 'package:http/http.dart' as http;

import '../local/local_storage_service.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'http://bk29ivj2gwbb5vh9le4r704m.87.106.3.145.sslip.io',
  );

  Map<String, String> get _headers {
    final token = LocalStorageService().loadToken();
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  Future<Map<String, dynamic>> get(String path) async {
    final res = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
    return _parse(res);
  }

  Future<Map<String, dynamic>> patch(
    String path, [
    Map<String, dynamic>? body,
  ]) async {
    final res = await http.patch(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
    return _parse(res);
  }

  Future<Map<String, dynamic>> put(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _parse(res);
  }

  Map<String, dynamic> _parse(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) {
      final msg = body['message'] ?? 'Erreur serveur (${res.statusCode})';
      throw Exception(msg is List ? msg.join(', ') : msg.toString());
    }
    return body;
  }
}
