import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart'; // Make sure Config is accessible here or import the config file

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  Future<void> saveJwtToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("auth_token", "Bearer $token");
  }

  // FIXED: Changed to async to allow loading the Config asset
  Future<String> _prepareUrl(String url) async {
    // Load config dynamically since it's not a global singleton
    final config = await Config.loadFromAsset();

    String separator = url.contains('?') ? '&' : '?';
    if (!url.contains('DB=') && !url.contains('B=')) {
      return '$url${separator}DB=${config.clientCode}';
    }
    return url;
  }

  Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final auth = prefs.getString("auth_token");
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth != null && auth.isNotEmpty) {
      headers['Authorization'] = auth;
    }
    return headers;
  }

  Future<void> _handleUnauthorized(int statusCode) async {
    if (statusCode == 401) {
      print("Unauthorized access (401). Check if user is logged in.");
    }
  }

  // --- HTTP METHODS UPDATED TO AWAIT URL PREPARATION ---

  Future<http.Response> get(String url) async {
    final finalUrl = await _prepareUrl(url); // Added await
    final headers = await _getHeaders();
    final response = await http.get(Uri.parse(finalUrl), headers: headers);
    await _handleUnauthorized(response.statusCode);
    return response;
  }

  Future<http.Response> post(String url, dynamic body) async {
    final finalUrl = await _prepareUrl(url); // Added await
    final headers = await _getHeaders();
    final response = await http.post(
      Uri.parse(finalUrl),
      headers: headers,
      body: jsonEncode(body),
    );
    await _handleUnauthorized(response.statusCode);
    return response;
  }

  Future<http.Response> put(String url, dynamic body) async {
    final finalUrl = await _prepareUrl(url); // Added await
    final headers = await _getHeaders();
    final response = await http.put(
      Uri.parse(finalUrl),
      headers: headers,
      body: jsonEncode(body),
    );
    await _handleUnauthorized(response.statusCode);
    return response;
  }

  Future<http.Response> delete(String url) async {
    final finalUrl = await _prepareUrl(url); // Added await
    final headers = await _getHeaders();
    final response = await http.delete(Uri.parse(finalUrl), headers: headers);
    await _handleUnauthorized(response.statusCode);
    return response;
  }
}