import 'package:shared_preferences/shared_preferences.dart';

class Haladas {
  static const _kulcs = 'megtanult_szavak';
  static const _hibasKulcs = 'hibas_szavak';
  static const _szintKulcs = 'felhasznalo_szintje';
  static const _elsoInditasKulcs = 'elso_inditas_kesz';

  /// Mentett tudott szavak betöltése
  static Future<Set<String>> betolt() async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList(_kulcs) ?? [];
    return lista.toSet();
  }

  /// Tudott szavak mentése
  static Future<void> ment(Set<String> tudott) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kulcs, tudott.toList());
  }

  /// Hibás szavak betöltése
  static Future<Set<String>> hibasakBetolt() async {
    final prefs = await SharedPreferences.getInstance();
    final lista = prefs.getStringList(_hibasKulcs) ?? [];
    return lista.toSet();
  }

  /// Hibás szó hozzáadása
  static Future<void> hibasHozzaad(String szo) async {
    final hibasak = await hibasakBetolt();
    hibasak.add(szo);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hibasKulcs, hibasak.toList());
  }

  /// Hibás szó törlése (ha már megtanulta)
  static Future<void> hibasTorol(String szo) async {
    final hibasak = await hibasakBetolt();
    hibasak.remove(szo);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_hibasKulcs, hibasak.toList());
  }

  /// Első indítás ellenőrzése
  static Future<bool> isElsoInditasKesz() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_elsoInditasKulcs) ?? false;
  }

  /// Szint felmérés befejezettnek jelölése és szint mentése
  static Future<void> szintMentese(String szint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_elsoInditasKulcs, true);
    await prefs.setString(_szintKulcs, szint);
  }

  /// Aktuális szint betöltése
  static Future<String> szintBetoltese() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_szintKulcs) ?? 'Kezdő (A1.1)';
  }

  /// Összes haladás törlése
  static Future<void> torol() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kulcs);
    await prefs.remove(_hibasKulcs);
    await prefs.remove(_szintKulcs);
    await prefs.remove(_elsoInditasKulcs);
  }
}