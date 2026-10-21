import 'package:flutter/material.dart';

import 'haladas.dart';
import 'main.dart'; // A FoMenu a main.dart-ban van deklarálva

class SzintfelmeroOldal extends StatefulWidget {
  final Function(String)? onSzintKivalasztva;

  const SzintfelmeroOldal({
    super.key,
    this.onSzintKivalasztva,
  });

  @override
  State<SzintfelmeroOldal> createState() => _SzintfelmeroOldalState();
}

class _SzintfelmeroOldalState extends State<SzintfelmeroOldal> {
  int _aktualisKerdesIndex = 0;
  int _helyesValaszokSzama = 0;
  String? _valasztottValasz;
  bool _tesztVege = false;

  final List<Map<String, dynamic>> _kerdesek = [
    {
      'kerdes': 'Ich ___ aus Ungarn.',
      'opciok': ['komme', 'kommst', 'kommt', 'kommen'],
      'helyes': 'komme',
    },
    {
      'kerdes': 'Er ___ jeden Tag Deutsch.',
      'opciok': ['lernt', 'lernen', 'lerne', 'lernst'],
      'helyes': 'lernt',
    },
    {
      'kerdes': 'Gestern ___ ich ins Kino gegangen.',
      'opciok': ['bin', 'habe', 'sein', 'war'],
      'helyes': 'bin',
    },
    {
      'kerdes': 'Wenn es regnet, ___ ich zu Hause.',
      'opciok': ['bleibe', 'bleibst', 'bleiben', 'gehe'],
      'helyes': 'bleibe',
    },
    {
      'kerdes': 'Obwohl er müde war, ___ er weitergearbeitet.',
      'opciok': ['hat', 'ist', 'wurde', 'hatte'],
      'helyes': 'hat',
    },
    {
      'kerdes': 'Je mehr du lernst, ___ besser wirst du.',
      'opciok': ['desto', 'um', 'wie', 'als'],
      'helyes': 'desto',
    },
  ];

  String _szintMeghatarozasa(int helyesValaszok) {
    switch (helyesValaszok) {
      case 0:
      case 1:
        return 'A1.1 (Kezdő)';
      case 2:
        return 'A1.2 (Újrakezdő)';
      case 3:
        return 'A2.1 (Alapfok)';
      case 4:
        return 'A2.2 (Középhaladó)';
      case 5:
        return 'B1.1 (Haladó)';
      case 6:
      default:
        return 'B1.2 (Mesterfok)';
    }
  }

  void _valaszEllenorzese(String valasz) {
    setState(() {
      _valasztottValasz = valasz;
      if (valasz == _kerdesek[_aktualisKerdesIndex]['helyes']) {
        _helyesValaszokSzama++;
      }

      if (_aktualisKerdesIndex < _kerdesek.length - 1) {
        _aktualisKerdesIndex++;
        _valasztottValasz = null;
      } else {
        _tesztVege = true;
      }
    });
  }

  Future<void> _tesztBefejezese(String elertSzint) async {
    // 1. Elmentjük a megszerzett szintet és befejezetté tesszük az első indítást
    await Haladas.szintMentese(elertSzint);

    // 2. Meghívjuk a callback-et, ha létezik
    if (widget.onSzintKivalasztva != null) {
      widget.onSzintKivalasztva!(elertSzint);
    }

    if (!mounted) return;

    // 3. Megnyitjuk a FoMenu-t a main.dart-ból, letörölve a korábbi navigációs előzményeket
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const FoMenu()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_tesztVege) {
      final elertSzint = _szintMeghatarozasa(_helyesValaszokSzama);
      return Scaffold(
        appBar: AppBar(title: const Text('Szintfelmérő Eredmény')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stars, size: 80, color: Colors.amber),
                const SizedBox(height: 20),
                const Text(
                  'Gratulálunk! A szintfelmérő elkészült.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Text(
                  'Eredményed: $_helyesValaszokSzama / ${_kerdesek.length} helyes válasz',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Meghatározott szint: $elertSzint',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => _tesztBefejezese(elertSzint),
                  child: const Text('Tovább a tanuláshoz'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final aktualisKerdes = _kerdesek[_aktualisKerdesIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text('Kérdés ${_aktualisKerdesIndex + 1} / ${_kerdesek.length}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(
              value: (_aktualisKerdesIndex + 1) / _kerdesek.length,
            ),
            const SizedBox(height: 32),
            Text(
              aktualisKerdes['kerdes'],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ...(aktualisKerdes['opciok'] as List<String>).map((opcio) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.all(16),
                  ),
                  onPressed: () => _valaszEllenorzese(opcio),
                  child: Text(
                    opcio,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}