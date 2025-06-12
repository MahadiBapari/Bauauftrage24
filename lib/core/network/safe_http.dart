import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SafeHttp {
  static Future<void> logoutAndRedirect(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // or selectively remove only auth/session keys
    if (context.mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please log in again.')),
      );
    }
  }

  static Future<http.Response> safeGet(BuildContext context, Uri url, {Map<String, String>? headers}) async {
    final response = await http.get(url, headers: headers);
    if (response.statusCode == 401 || response.statusCode == 403) {
      await logoutAndRedirect(context);
      throw Exception('Session expired');
    }
    return response;
  }

  static Future<http.Response> safePost(BuildContext context, Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    final response = await http.post(url, headers: headers, body: body, encoding: encoding);
    if (response.statusCode == 401 || response.statusCode == 403) {
      await logoutAndRedirect(context);
      throw Exception('Session expired');
    }
    return response;
  }

  static Future<http.Response> safePut(BuildContext context, Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    final response = await http.put(url, headers: headers, body: body, encoding: encoding);
    if (response.statusCode == 401 || response.statusCode == 403) {
      await logoutAndRedirect(context);
      throw Exception('Session expired');
    }
    return response;
  }

  static Future<http.Response> safeDelete(BuildContext context, Uri url, {Map<String, String>? headers, Object? body, Encoding? encoding}) async {
    final response = await http.delete(url, headers: headers, body: body, encoding: encoding);
    if (response.statusCode == 401 || response.statusCode == 403) {
      await logoutAndRedirect(context);
      throw Exception('Session expired');
    }
    return response;
  }
} 