import 'dart:async';
import 'package:flutter/material.dart';

import 'haladas.dart';
import 'offline_ai_felolvaso.dart';
import 'szavak.dart';

class SzintSzoveg {
  final String szint;
  final String cim;
  final String szoveg;

  const SzintSzoveg({
    required this.szint,
    required this.cim,
    required this.szoveg,
  });
}

const List<SzintSzoveg> olvasmanilista = [
  SzintSzoveg(
    szint: 'A1',
    cim: 'Mein Alltag in Deutschland',
    szoveg: '''
Hallo! Ich heiße Thomas und ich wohne in einer kleinen Stadt in Deutschland. Mein Tag beginnt sehr früh. Um sechs Uhr morgens stehe ich auf. Zuerst gehe ich ins Badezimmer. Ich wasche mein Gesicht, putze meine Zähne und dusche mich. Danach ziehe ich meine Kleidung an. 

Um sieben Uhr gehe ich in die Küche und mache das Frühstück. Ich trinke gerne eine große Tasse Kaffee mit Milch und esse ein Brot mit Butter und Käse. Manchmal esse ich auch ein Ei oder einen Apfel. Meine Familie frühstückt zusammen. Wir sprechen über den Tag und trinken Orangensaft.
''',
  ),
  SzintSzoveg(
    szint: 'A2',
    cim: 'Eine Reise nach Berlin',
    szoveg: '''
Letzte Woche habe ich mit meinen Freunden einen Ausflug nach Berlin gemacht. Wir haben uns schon lange auf diese Reise gefreut, weil Berlin eine sehr faszinierende und historische Stadt ist. Wir sind früh am Morgen mit dem Zug abgefahren. Die Fahrt dauerte etwa drei Stunden.
''',
  ),
  SzintSzoveg(
    szint: 'B1',
    cim: 'Umweltschutz im Alltag',
    szoveg: '''
Der Klimawandel und der Schutz unserer Umwelt gehören zu den bedeutendsten Herausforderungen unserer heutigen Gesellschaft. Täglich hören wir in den Nachrichten von steigenden Temperaturen, schmelzenden Gletschern und zunehmenden Naturkatastrophen.
''',
  ),
];

class FelolvasoOldal extends StatefulWidget {
  const FelolvasoOldal({super.key});

  @override
  State<FelolvasoOldal> createState() => _FelolvasoOldalState();
}

class _FelolvasoOldalState extends State<FelolvasoOldal> {
  int _valasztottIndex = 0;
  bool _olvas = false;
  int? _aktivSzoIndex;
  String? _kijeloltSzo;
  bool _stopRequested = false;
  double _sebesseg = 0.9;
  StreamSubscription<Duration>? _pozicioSub;

  @override
  void initState() {
    super.initState();
    OfflineAiFelolvaso.inictalizal();
    _szintBetoltese();
  }

  @override
  void dispose() {
    _pozicioSub?.cancel();
    super.dispose();
  }

  Future<void> _szintBetoltese() async {
    final tudott = await Haladas.betolt();
    final tudottDb = tudott.length;

    int autoIndex = 0;
    if (tudottDb > 50) {
      autoIndex = 2;
    } else if (tudottDb > 20) {
      autoIndex = 1;
    }

    if (mounted) {
      setState(() {
        _valasztottIndex = autoIndex;
      });
    }
  }

  Future<void> _felolvasMondatonkent() async {
    final teljesSzoveg = olvasmanilista[_valasztottIndex].szoveg;
    if (teljesSzoveg.trim().isEmpty) return;

    if (mounted) {
      setState(() {
        _olvas = true;
        _stopRequested = false;
        _aktivSzoIndex = 0;
      });
    }

    final mondatok = teljesSzoveg.split(RegExp(r'(?<=[.!?])\s+'));
    int globalisSzoIndex = 0;

    for (final mondat in mondatok) {
      if (_stopRequested || !mounted) break;
      if (mondat.trim().isEmpty) continue;

      final mondatElemek = mondat.split(RegExp(r'(\s+)'));
      final szavakSzama = mondatElemek.where((s) => s.trim().isNotEmpty).length;

      if (szavakSzama == 0) continue;

      final kezdoGlobalisIndex = globalisSzoIndex;

      // 1. Generáljuk a fájlt ékezetmentes metódushívással
      final audioFile = await OfflineAiFelolvaso.generalWav(mondat, speed: _sebesseg);
      if (audioFile == null || _stopRequested || !mounted) break;

      final osszesKarakter = mondatElemek.fold<int>(
        0,
            (sum, elem) => sum + (elem.trim().isEmpty ? 1 : elem.length),
      );

      final bajtok = await audioFile.length();
      final double teljesMs = ((bajtok - 44) / (22050 * 2)) * 1000;

      _pozicioSub?.cancel();
      _pozicioSub = OfflineAiFelolvaso.pozicioStream.listen((pozicio) {
        if (!_olvas || _stopRequested || !mounted) return;

        final elteltMs = pozicio.inMilliseconds;

        if (teljesMs > 0 && osszesKarakter > 0) {
          final haladasArany = (elteltMs / teljesMs).clamp(0.0, 1.0);
          final elertKarakterTarget = haladasArany * osszesKarakter;

          int felhalmozottKarakter = 0;
          int eleresiIndex = 0;

          for (int i = 0; i < mondatElemek.length; i++) {
            final elem = mondatElemek[i];
            felhalmozottKarakter += elem.trim().isEmpty ? 1 : elem.length;
            if (felhalmozottKarakter >= elertKarakterTarget) {
              eleresiIndex = i;
              break;
            }
          }

          setState(() {
            _aktivSzoIndex = kezdoGlobalisIndex + eleresiIndex;
          });
        }
      });

      await OfflineAiFelolvaso.jatszdLe(audioFile);

      _pozicioSub?.cancel();
      globalisSzoIndex += mondatElemek.length;

      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (mounted) {
      setState(() {
        _olvas = false;
        _aktivSzoIndex = null;
      });
    }
  }

  void _megallit() {
    _stopRequested = true;
    _pozicioSub?.cancel();
    OfflineAiFelolvaso.leallit();
    setState(() {
      _olvas = false;
      _aktivSzoIndex = null;
    });
  }

  String _forditasKeresese(String tisztaSzo) {
    final keresett = tisztaSzo.toLowerCase();
    for (final szo in osszesSzo) {
      final nemetAlap = szo.nemet.toLowerCase().replaceAll(RegExp(r'^(der|die|das)\s+'), '');
      if (nemetAlap == keresett || szo.nemet.toLowerCase() == keresett) {
        return szo.magyar;
      }
    }
    return 'Nincs közvetlen szótári találat.';
  }

  void _szoKattintas(String szo) {
    if (_olvas) {
      _megallit();
    }

    final tisztaSzo = szo.replaceAll(RegExp(r'[^\wÄäÖöÜüß]'), '');
    if (tisztaSzo.isEmpty) return;

    setState(() => _kijeloltSzo = tisztaSzo);

    final forditas = _forditasKeresese(tisztaSzo);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final szinek = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tisztaSzo,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: szinek.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                forditas,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.volume_up_rounded),
                    tooltip: 'Szó kiejtése',
                    onPressed: () => OfflineAiFelolvaso.felolvas(tisztaSzo, speed: _sebesseg),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).then((_) {
      if (mounted) {
        setState(() => _kijeloltSzo = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final szinek = Theme.of(context).colorScheme;
    final aktolvasmany = olvasmanilista[_valasztottIndex];
    final szavak = aktolvasmany.szoveg.split(RegExp(r'(\s+)'));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Német Olvasmányok (AI TTS)'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  for (int i = 0; i < olvasmanilista.length; i++) ...[
                    Expanded(
                      child: ChoiceChip(
                        label: Text(
                          '${olvasmanilista[i].szint} Szint',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        selected: _valasztottIndex == i,
                        onSelected: (_) {
                          _megallit();
                          setState(() {
                            _valasztottIndex = i;
                          });
                        },
                      ),
                    ),
                    if (i < olvasmanilista.length - 1) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              Card(
                margin: EdgeInsets.zero,
                elevation: 0,
                color: szinek.surfaceContainerHighest.withValues(alpha: 0.5),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.speed_rounded, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Tempó: ${_sebesseg.toStringAsFixed(1)}x',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Slider(
                          value: _sebesseg,
                          min: 0.6,
                          max: 1.3,
                          divisions: 7,
                          label: '${_sebesseg.toStringAsFixed(1)}x',
                          onChanged: _olvas
                              ? null
                              : (ertek) {
                            setState(() => _sebesseg = ertek);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    aktolvasmany.cim,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: szinek.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Szint: ${aktolvasmany.szint}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: szinek.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: szinek.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: szinek.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 4.0,
                      runSpacing: 4.0,
                      children: List.generate(szavak.length, (index) {
                        final szo = szavak[index];
                        final tiszta = szo.replaceAll(RegExp(r'[^\wÄäÖöÜüß]'), '');

                        final elobenOlvasva = _aktivSzoIndex == index;
                        final keziKijeloles = _kijeloltSzo != null &&
                            tiszta.isNotEmpty &&
                            _kijeloltSzo!.toLowerCase() == tiszta.toLowerCase();

                        Color hatterSzin = Colors.transparent;
                        Color szovegSzin = szinek.onSurface;

                        if (elobenOlvasva) {
                          hatterSzin = Colors.amber;
                          szovegSzin = Colors.black;
                        } else if (keziKijeloles) {
                          hatterSzin = szinek.primary;
                          szovegSzin = szinek.onPrimary;
                        }

                        return GestureDetector(
                          onTap: () => _szoKattintas(szo),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 100),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: hatterSzin,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              szo,
                              style: TextStyle(
                                fontSize: 18,
                                color: szovegSzin,
                                fontWeight: (elobenOlvasva || keziKijeloles)
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: _olvas ? _megallit : _felolvasMondatonkent,
                icon: Icon(_olvas ? Icons.stop_rounded : Icons.volume_up_rounded),
                label: Text(
                  _olvas ? 'Felolvasás megállítása' : 'Olvasmány felolvasása',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}