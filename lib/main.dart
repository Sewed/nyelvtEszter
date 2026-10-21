import 'dart:math';
import 'package:flutter/material.dart';

import 'beallitasok.dart';
import 'felolvaso_oldal.dart';
import 'haladas.dart';
import 'kartya_oldal.dart';
import 'statisztika.dart';
import 'szavak.dart';
import 'szintfelmero_oldal.dart';
import 'szotar_oldal.dart';
import 'tema_valaszto.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Beallitasok.betolt();
  await Statisztika.betolt();
  await szavakBetoltese();
  runApp(const NyelvtanuloApp());
}

class NyelvtanuloApp extends StatelessWidget {
  const NyelvtanuloApp({super.key});

  ThemeData _tema(Brightness fenyero) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1F5F8B),
        brightness: fenyero,
      ),
      useMaterial3: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: Beallitasok.temaMod,
      builder: (context, mod, _) => MaterialApp(
        title: 'Német tanuló',
        debugShowCheckedModeBanner: false,
        theme: _tema(Brightness.light),
        darkTheme: _tema(Brightness.dark),
        themeMode: mod,
        home: const InditoEllenorzo(),
      ),
    );
  }
}

class InditoEllenorzo extends StatelessWidget {
  const InditoEllenorzo({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: Haladas.isElsoInditasKesz(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final kesz = snapshot.data ?? false;
        return kesz ? const FoMenu() : const SzintfelmeroOldal();
      },
    );
  }
}

class FoMenu extends StatefulWidget {
  const FoMenu({super.key});

  @override
  State<FoMenu> createState() => _FoMenuState();
}

class _FoMenuState extends State<FoMenu> {
  int _hibasDb = 0;
  String _sajatSzint = 'A1.1 (Kezdő)';

  @override
  void initState() {
    super.initState();
    _frissit();
  }

  Future<void> _frissit() async {
    await Statisztika.betolt();
    final hibasak = await Haladas.hibasakBetolt();
    final szint = await Haladas.szintBetoltese();

    if (mounted) {
      setState(() {
        _hibasDb = hibasak.length;
        _sajatSzint = szint;
      });
    }
  }

  Future<void> _megnyit(Widget oldal) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => oldal));
    _frissit();
  }

  Future<void> _nehezSzavakMegnyitasa() async {
    final hibasNemetek = await Haladas.hibasakBetolt();
    final nehezSzavak =
    osszesSzo.where((s) => hibasNemetek.contains(s.nemet)).toList();

    if (!mounted) return;

    if (nehezSzavak.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jelenleg nincs elmentett hibás szavad! Szép munka! 🎉'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KartyaOldal(
          cim: 'Nehéz szavak (${nehezSzavak.length})',
          szavak: nehezSzavak,
        ),
      ),
    );
    _frissit();
  }

  Future<void> _torles() async {
    final biztos = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Haladás törlése'),
        content: const Text(
            'Biztosan törlöd az összes mentett haladást, szinteket, pontokat és sorozatot?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Törlés'),
          ),
        ],
      ),
    );

    if (biztos == true) {
      await Haladas.torol();
      await Statisztika.torol();
      if (!mounted) return;
      _frissit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSotet = Beallitasok.temaMod.value == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Német tanuló'),
        // A main.dart-ban az AppBar actions részénél ezt írd át:
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: Beallitasok.temaMod,
            builder: (context, mod, _) {
              final isSotet = mod == ThemeMode.dark;
              return IconButton(
                icon: Icon(isSotet ? Icons.light_mode : Icons.dark_mode),
                tooltip: 'Téma váltása',
                onPressed: () {
                  Beallitasok.temaValtas(!isSotet);
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            tooltip: 'Szintfelmérő újraküldése',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SzintfelmeroOldal(
                    onSzintKivalasztva: (szint) => _frissit(),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _FoKartya(
              szintNev: _sajatSzint,
            ),
            const SizedBox(height: 12),
            _MenuElem(
              ikon: Icons.search_rounded,
              cim: 'Szótár és kereső',
              leiras: 'Keresés a szókincsben, kiejtés meghallgatása',
              onTap: () => _megnyit(const SzotarOldal()),
            ),
            _MenuElem(
              ikon: Icons.style,
              cim: 'Szókártyák',
              leiras: 'Témakörök szerint, hibás szavak ismétlése',
              onTap: () => _megnyit(const TemaValaszto()),
            ),
            _MenuElem(
              ikon: Icons.quiz,
              cim: 'Kvíz',
              leiras: '4 válaszlehetőség, 10 kérdés',
              onTap: () => _megnyit(const TemaValaszto(kviz: true)),
            ),
            _MenuElem(
              ikon: Icons.warning_amber_rounded,
              cim: 'Nehéz szavak',
              leiras: _hibasDb == 0
                  ? 'Nincs hibás szavad!'
                  : '$_hibasDb elrontott szó gyakorlása',
              onTap: _nehezSzavakMegnyitasa,
            ),
            _MenuElem(
              ikon: Icons.record_voice_over,
              cim: 'Szövegfelolvasás',
              leiras: 'Német szöveg meghallgatása, szavak kiejtése',
              onTap: () => _megnyit(const FelolvasoOldal()),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _torles,
              child: const Text('Haladás és szint törlése'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuElem extends StatelessWidget {
  final IconData ikon;
  final String cim;
  final String leiras;
  final VoidCallback onTap;

  const _MenuElem({
    required this.ikon,
    required this.cim,
    required this.leiras,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Icon(ikon, size: 32),
        title: Text(cim, style: Theme.of(context).textTheme.titleLarge),
        subtitle: Text(leiras),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _FoKartya extends StatelessWidget {
  final String szintNev;

  const _FoKartya({
    required this.szintNev,
  });

  void _naptarDialogMegjelenitese(BuildContext context, Allapot a) {
    showDialog(
      context: context,
      builder: (context) => _NaptarDialog(allapot: a),
    );
  }

  void _napiCelBeallitasDialog(BuildContext context, int jelenlegiCel) {
    final controller = TextEditingController(text: '$jelenlegiCel');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Napi cél beállítása'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Hány megválaszolt feladat legyen a napi célod?'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Napi feladatszám',
                suffixText: 'db',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mégse'),
          ),
          FilledButton(
            onPressed: () async {
              final ujCel = int.tryParse(controller.text);
              if (ujCel != null && ujCel > 0) {
                await Statisztika.napiCelBeallitas(ujCel);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Mentés'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: ValueListenableBuilder<Allapot>(
          valueListenable: Statisztika.allapot,
          builder: (context, a, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Besorolt szint:', style: tema.textTheme.bodySmall),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: tema.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      szintNev,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: tema.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Adat(
                    ikon: Icons.local_fire_department,
                    szin: Colors.orange,
                    fo: '${a.sorozat}',
                    alcim: 'napos sorozat',
                    onTap: () => _naptarDialogMegjelenitese(context, a),
                  ),
                  _NapiCel(
                    ma: a.ma,
                    cel: a.napiCel,
                    kesz: a.maiCelKesz,
                    onTap: () => _napiCelBeallitasDialog(context, a.napiCel),
                  ),
                  _Adat(
                    ikon: Icons.military_tech,
                    szin: tema.colorScheme.primary,
                    fo: '${a.szint}. szint',
                    alcim: '${a.szintenBelul} / ${Statisztika.szintXp} XP',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Adat extends StatelessWidget {
  final IconData ikon;
  final Color szin;
  final String fo;
  final String alcim;
  final VoidCallback? onTap;

  const _Adat({
    required this.ikon,
    required this.szin,
    required this.fo,
    required this.alcim,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;

    Widget tartalom = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Icon(ikon, size: 36, color: szin),
        const SizedBox(height: 6),
        Text(fo, style: tema.titleMedium),
        Text(alcim, style: tema.bodySmall),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: tartalom,
        ),
      );
    }

    return tartalom;
  }
}

class _NapiCel extends StatelessWidget {
  final int ma;
  final int cel;
  final bool kesz;
  final VoidCallback onTap;

  const _NapiCel({
    required this.ma,
    required this.cel,
    required this.kesz,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final szinek = Theme.of(context).colorScheme;
    final szin = kesz ? Colors.green : szinek.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: (ma / cel).clamp(0.0, 1.0).toDouble(),
                      strokeWidth: 6,
                      strokeCap: StrokeCap.round,
                      backgroundColor: szinek.surfaceContainerHighest,
                      color: szin,
                    ),
                  ),
                  kesz
                      ? Icon(Icons.check, color: szin, size: 28)
                      : Text(
                    '$ma/$cel',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text('mai cél', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

/// Modern, lekerekített felugró naptár ablak az aktív napok összefüggő kapszula megjelenítésével
class _NaptarDialog extends StatefulWidget {
  final Allapot allapot;
  const _NaptarDialog({required this.allapot});

  @override
  State<_NaptarDialog> createState() => _NaptarDialogState();
}

class _NaptarDialogState extends State<_NaptarDialog> {
  late DateTime _fokuszDatum;

  @override
  void initState() {
    super.initState();
    _fokuszDatum = DateTime.now();
  }

  static const _honapNevek = [
    'Január', 'Február', 'Március', 'Április', 'Május', 'Június',
    'Július', 'Augusztus', 'Szeptember', 'Október', 'November', 'December'
  ];

  static const _hetNapjai = ['H', 'K', 'Sze', 'Cs', 'P', 'Szo', 'V'];

  bool _isVanAktiv(int ev, int honap, int napSzam) {
    if (napSzam < 1) return false;
    final datumKulcs =
        '$ev-${honap.toString().padLeft(2, '0')}-${napSzam.toString().padLeft(2, '0')}';
    return widget.allapot.aktivNapok.contains(datumKulcs);
  }

  @override
  Widget build(BuildContext context) {
    final ev = _fokuszDatum.year;
    final honap = _fokuszDatum.month;
    final tema = Theme.of(context);

    final elsoNap = DateTime(ev, honap, 1);
    final utolsoNap = DateTime(ev, honap + 1, 0);
    final napokSzama = utolsoNap.day;
    final eltolas = elsoNap.weekday - 1;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      elevation: 8,
      child: Container(
        width: 320,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: tema.colorScheme.surface,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.filledTonal(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () {
                    setState(() {
                      _fokuszDatum = DateTime(ev, honap - 1, 1);
                    });
                  },
                ),
                Text(
                  '${_honapNevek[honap - 1]} $ev',
                  style: tema.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: tema.colorScheme.onSurface,
                  ),
                ),
                IconButton.filledTonal(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () {
                    setState(() {
                      _fokuszDatum = DateTime(ev, honap + 1, 1);
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: tema.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: Colors.orange, size: 22),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sorozat', style: tema.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                          Text(
                            '${widget.allapot.sorozat} nap',
                            style: tema.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(height: 24, width: 1, color: tema.dividerColor),
                  Row(
                    children: [
                      Icon(Icons.emoji_events_rounded, color: tema.colorScheme.primary, size: 22),
                      const SizedBox(width: 6),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rekord', style: tema.textTheme.labelSmall?.copyWith(color: Colors.grey)),
                          Text(
                            '${widget.allapot.rekordSorozat} nap',
                            style: tema.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: tema.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _hetNapjai
                  .map((nap) => SizedBox(
                width: 36,
                child: Text(
                  nap,
                  textAlign: TextAlign.center,
                  style: tema.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: tema.colorScheme.outline,
                  ),
                ),
              ))
                  .toList(),
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: eltolas + napokSzama,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 0,
              ),
              itemBuilder: (context, index) {
                if (index < eltolas) return const SizedBox();

                final napSzam = index - eltolas + 1;
                final hetNapja = index % 7;
                final vanTanulas = _isVanAktiv(ev, honap, napSzam);

                final tegnapKesz = hetNapja > 0 && _isVanAktiv(ev, honap, napSzam - 1);
                final holnapKesz = hetNapja < 6 && _isVanAktiv(ev, honap, napSzam + 1);

                final ma = DateTime.now();
                final isMa = ma.year == ev && ma.month == honap && ma.day == napSzam;

                BorderRadius borderRadius;
                if (tegnapKesz && holnapKesz) {
                  borderRadius = BorderRadius.zero;
                } else if (!tegnapKesz && holnapKesz) {
                  borderRadius = const BorderRadius.horizontal(left: Radius.circular(20));
                } else if (tegnapKesz && !holnapKesz) {
                  borderRadius = const BorderRadius.horizontal(right: Radius.circular(20));
                } else {
                  borderRadius = BorderRadius.circular(20);
                }

                return Container(
                  margin: EdgeInsets.only(
                    top: 2,
                    bottom: 2,
                    left: (vanTanulas && tegnapKesz) ? 0 : 2,
                    right: (vanTanulas && holnapKesz) ? 0 : 2,
                  ),
                  decoration: BoxDecoration(
                    color: vanTanulas
                        ? Colors.orange.shade400
                        : (isMa ? tema.colorScheme.primaryContainer : Colors.transparent),
                    borderRadius: vanTanulas ? borderRadius : BorderRadius.circular(20),
                    border: isMa && !vanTanulas
                        ? Border.all(color: tema.colorScheme.primary, width: 2)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '$napSzam',
                      style: TextStyle(
                        fontWeight: isMa || vanTanulas ? FontWeight.bold : FontWeight.normal,
                        color: vanTanulas
                            ? Colors.white
                            : (isMa ? tema.colorScheme.onPrimaryContainer : tema.colorScheme.onSurface),
                        fontSize: 13,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Bezárás'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}