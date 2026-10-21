import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Szo {
  final String nemet;
  final String magyar;
  final String kepUrl;
  final String szint;
  final String tema;

  const Szo({
    required this.nemet,
    required this.magyar,
    required this.kepUrl,
    required this.szint,
    required this.tema,
  });

  factory Szo.fromJson(Map<String, dynamic> json) {
    return Szo(
      nemet: json['nemet'] as String? ?? '',
      magyar: json['magyar'] as String? ?? '',
      kepUrl: json['kepUrl'] as String? ?? '',
      szint: json['szint'] as String? ?? 'A1',
      tema: json['tema'] as String? ?? 'Egyéb',
    );
  }
}

class Tema {
  final String nev;
  final IconData ikon;
  final List<Szo> szavak;

  const Tema({required this.nev, required this.ikon, required this.szavak});
}

List<Szo> osszesSzo = [];
List<Tema> temak = [];

/// A JSON fájl betöltése és feldolgozása az app indításakor
Future<void> szavakBetoltese() async {
  try {
    final String response = await rootBundle.loadString('assets/szavak.json');
    final List<dynamic> data = json.decode(response);

    osszesSzo = data.map((json) => Szo.fromJson(json)).toList();

    // Témakörök automatikus összeállítása a betöltött szavakból
    final Map<String, List<Szo>> temaMap = {};
    for (var szo in osszesSzo) {
      temaMap.putIfAbsent(szo.tema, () => []).add(szo);
    }

    temak = temaMap.entries.map((entry) {
      return Tema(
        nev: entry.key,
        ikon: _ikonValaszto(entry.key),
        szavak: entry.value,
      );
    }).toList();
  } catch (e) {
    debugPrint('Hiba a szavak betöltésekor: $e');
  }
}

IconData _ikonValaszto(String temaNev) {
  switch (temaNev) {
    case 'Alapok & Üdvözlés':
      return Icons.waving_hand;
    case 'Család és emberek':
      return Icons.family_restroom;
    case 'Étel és ital':
      return Icons.restaurant;
    case 'Otthon':
      return Icons.home;
    case 'Munka és hivatal':
      return Icons.work;
    default:
      return Icons.category;
  }
}

List<Szo> szavakSzintSzerint(String szintNev) {
  if (osszesSzo.isEmpty) return [];

  if (szintNev.contains('A1.1') || szintNev.contains('Kezdő')) {
    return osszesSzo.where((s) => s.szint == 'A1').toList();
  } else if (szintNev.contains('A1.2') || szintNev.contains('Újrakezdő')) {
    return osszesSzo.where((s) => s.szint == 'A1' || s.szint == 'A2').toList();
  } else if (szintNev.contains('A2') || szintNev.contains('Alapfok') || szintNev.contains('Középhaladó')) {
    return osszesSzo.where((s) => s.szint == 'A1' || s.szint == 'A2' || s.szint == 'B1').toList();
  } else {
    return osszesSzo;
  }
}