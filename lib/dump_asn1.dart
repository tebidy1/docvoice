import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  SharedPreferences.setMockInitialValues({});
  try {
    var prefs = await SharedPreferences.getInstance();
    // Wait, desktop flutter apps store shared preferences in a JSON file on Windows!
    // Since this is a simple Dart script, it won't have access to the Windows shared preferences file natively unless run as a Flutter app!
  } catch (e) {
    print("Cannot read prefs from dart script.");
  }
}


