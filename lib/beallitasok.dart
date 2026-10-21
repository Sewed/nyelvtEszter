import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Beallitasok {
  static final ValueNotifier<ThemeMode> temaMod = ValueNotifier(ThemeMode.dark);

  static Future<void> betolt() async {
    final p = await SharedPreferences.getInstance();
    final isSotet = p.getBool('beallitas_sotet_tema') ?? true;
    temaMod.value = isSotet ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> temaValtas(bool sotet) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('beallitas_sotet_tema', sotet);
    temaMod.value = sotet ? ThemeMode.dark : ThemeMode.light;
  }
}