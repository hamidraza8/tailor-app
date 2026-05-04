import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/constants.dart';
import 'auth_service.dart';

class ApiService {
  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: await _headers(),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 401) {
        final refreshed = await AuthService.refreshToken();
        if (refreshed) {
          final retryResponse = await http
              .get(
                Uri.parse('${ApiConfig.baseUrl}$endpoint'),
                headers: await _headers(),
              )
              .timeout(ApiConfig.timeout);
          return _parseResponse(retryResponse);
        }
        return {'success': false, 'message': 'Session expired'};
      }

      return _parseResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> post(
      String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);

      if (response.statusCode == 401) {
        final refreshed = await AuthService.refreshToken();
        if (refreshed) {
          final retryResponse = await http
              .post(
                Uri.parse('${ApiConfig.baseUrl}$endpoint'),
                headers: await _headers(),
                body: jsonEncode(body),
              )
              .timeout(ApiConfig.timeout);
          return _parseResponse(retryResponse);
        }
        return {'success': false, 'message': 'Session expired'};
      }

      return _parseResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> put(
      String endpoint, Map<String, dynamic> body) async {
    try {
      final response = await http
          .put(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: await _headers(),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);
      if (response.statusCode == 401) {
        final refreshed = await AuthService.refreshToken();
        if (refreshed) {
          final retryResponse = await http
              .put(
                Uri.parse('${ApiConfig.baseUrl}$endpoint'),
                headers: await _headers(),
                body: jsonEncode(body),
              )
              .timeout(ApiConfig.timeout);
          return _parseResponse(retryResponse);
        }
        return {'success': false, 'message': 'Session expired'};
      }
      return _parseResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final response = await http
          .delete(
            Uri.parse('${ApiConfig.baseUrl}$endpoint'),
            headers: await _headers(),
          )
          .timeout(ApiConfig.timeout);
      if (response.statusCode == 401) {
        final refreshed = await AuthService.refreshToken();
        if (refreshed) {
          final retry = await http
              .delete(
                Uri.parse('${ApiConfig.baseUrl}$endpoint'),
                headers: await _headers(),
              )
              .timeout(ApiConfig.timeout);
          return _parseResponse(retry);
        }
        return {'success': false, 'message': 'Session expired'};
      }
      return _parseResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>> uploadFile(
      String endpoint, String filePath,
      {Map<String, String>? fields}) async {
    try {
      final token = await AuthService.getToken();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
      );

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.files.add(await http.MultipartFile.fromPath('file', filePath));

      if (fields != null) {
        request.fields.addAll(fields);
      }

      final streamedResponse = await request.send().timeout(ApiConfig.timeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _parseResponse(response);
    } catch (e) {
      return {'success': false, 'message': 'Upload error: $e'};
    }
  }

  static Map<String, dynamic> _parseResponse(http.Response response) {
    // 204 No Content (e.g. DELETE) — empty body is a success
    if (response.statusCode == 204 || response.body.isEmpty) {
      return response.statusCode >= 200 && response.statusCode < 300
          ? {'success': true}
          : {'success': false, 'message': 'Request failed (${response.statusCode})'};
    }
    try {
      final data = jsonDecode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (data is Map<String, dynamic>) {
          return {'success': true, ...data};
        }
        return {'success': true, 'data': data};
      } else {
        if (data is Map<String, dynamic>) {
          return {'success': false, ...data};
        }
        return {'success': false, 'message': 'Request failed'};
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Invalid response from server',
      };
    }
  }
}
