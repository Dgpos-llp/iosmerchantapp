//no changes
import 'dart:convert';
  import 'package:flutter/services.dart';

  class Config {
    final String apiUrl;
    final String clientCode;

    Config({required this.apiUrl, required this.clientCode});

    factory Config.fromJson(Map<String, dynamic> json) {
      return Config(
        apiUrl: json['apiUrl'],
        clientCode: json['clientCode'],
      );
    }

    static Future<Config> loadFromAsset() async {
      final jsonString = await rootBundle.loadString('assets/config.json');
      final jsonMap = json.decode(jsonString);
      return Config.fromJson(jsonMap);
    }
  }
