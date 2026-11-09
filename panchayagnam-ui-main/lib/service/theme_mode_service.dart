import 'dart:html' as html;
import 'package:flutter/material.dart';

class ThemeModeService {
  static final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier<bool>(
    html.window.sessionStorage['is_dark_mode'] == 'true',
  );

  static bool get isDark => isDarkModeNotifier.value;

  static void toggle() {
    isDarkModeNotifier.value = !isDarkModeNotifier.value;
    html.window.sessionStorage['is_dark_mode'] =
        isDarkModeNotifier.value ? 'true' : 'false';
  }

  static void setDark(bool value) {
    isDarkModeNotifier.value = value;
    html.window.sessionStorage['is_dark_mode'] = value ? 'true' : 'false';
  }
}
