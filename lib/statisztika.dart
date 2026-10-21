import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';

/// A tanulás pillanatnyi állapota: pont (XP), szint, napos sorozat, rekord sorozat, napi cél, aktív napok.
class Allapot {
  final int xp;
  final int sorozat; // egymást követő napok, amikor a napi cél teljesült
  final int rekordSorozat; // az eddigi leghosszabb elért sorozat
  final int ma; // a mai megválaszolt kérdések száma
  final int napiCel; // a beállított napi cél
  final bool maiCelKesz;
  final Set<String> aktivNapok; // "YYYY-MM-DD" formátumú dátumok halmaza

  const Allapot({
    this.xp = 0,
    this.sorozat = 0,
    this.rekordSorozat = 0,
    this.ma = 0,
    this.napiCel = 10,
    this.maiCelKesz = false,
    this.aktivNapok = const {},
  });

  int get szint => xp ~/ Statisztika.szintXp + 1;
  int get szintenBelul => xp % Statisztika.szintXp;
}

/// Egy válasz utáni jutalom (pont, napi cél, szintlépés).
class Jutalom {
  final int xp;
  final bool celMost; // épp most teljesült a napi cél
  final bool szintLepes;
  final int szint;
  final int sorozat;

  const Jutalom({
    required this.xp,
    required this.celMost,
    required this.szintLepes,
    required this.szint,
    required this.sorozat,
  });
}

/// Pont, szint, sorozat és napi cél mentése a készülékre (offline).
class Statisztika {
  /// Ennyi XP kell egy szintlépéshez.
  static const szintXp = 100;

  static final ValueNotifier<Allapot> allapot = ValueNotifier(const Allapot());

  static String _nap(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

  static String get _ma => _nap(DateTime.now());

  static String get _tegnap {
    final n = DateTime.now();
    return _nap(DateTime(n.year, n.month, n.day - 1));
  }

  static Allapot _olvas(SharedPreferences p) {
    final ma =
    p.getString('stat_ma_nap') == _ma ? (p.getInt('stat_ma_db') ?? 0) : 0;
    final celNap = p.getString('stat_cel_nap');
    final beallitottNapiCel = p.getInt('stat_napi_cel') ?? 10;

    final sorozat =
    (celNap == _ma || celNap == _tegnap) ? (p.getInt('stat_sorozat') ?? 0) : 0;
    final rekordSorozat = p.getInt('stat_rekord_sorozat') ?? sorozat;

    final aktivNapokLista = p.getStringList('stat_aktiv_napok') ?? [];

    return Allapot(
      xp: p.getInt('stat_xp') ?? 0,
      sorozat: sorozat,
      rekordSorozat: rekordSorozat < sorozat ? sorozat : rekordSorozat,
      ma: ma,
      napiCel: beallitottNapiCel,
      maiCelKesz: celNap == _ma,
      aktivNapok: aktivNapokLista.toSet(),
    );
  }

  static Future<void> betolt() async {
    final p = await SharedPreferences.getInstance();
    allapot.value = _olvas(p);
  }

  /// Napi cél módosítása és mentése (Ékezetmentes metódusnév)
  static Future<void> napiCelBeallitas(int ujCel) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('stat_napi_cel', ujCel);
    allapot.value = _olvas(p);
  }

  /// Egy megválaszolt kérdés rögzítése.
  static Future<Jutalom> valaszRogzit({int xp = 1}) async {
    final p = await SharedPreferences.getInstance();
    final elozo = _olvas(p);

    final ujXp = elozo.xp + xp;
    final ujMa = elozo.ma + 1;
    final celMost = !elozo.maiCelKesz && ujMa >= elozo.napiCel;
    final ujSorozat = celMost ? elozo.sorozat + 1 : elozo.sorozat;

    final ujRekord = ujSorozat > elozo.rekordSorozat ? ujSorozat : elozo.rekordSorozat;

    // Aktív nap elmentése a listába
    final aktivNapok = Set<String>.from(elozo.aktivNapok)..add(_ma);
    await p.setStringList('stat_aktiv_napok', aktivNapok.toList());

    await p.setInt('stat_xp', ujXp);
    await p.setString('stat_ma_nap', _ma);
    await p.setInt('stat_ma_db', ujMa);
    if (celMost) {
      await p.setInt('stat_sorozat', ujSorozat);
      await p.setString('stat_cel_nap', _ma);
    }
    await p.setInt('stat_rekord_sorozat', ujRekord);

    allapot.value = _olvas(p);
    return Jutalom(
      xp: xp,
      celMost: celMost,
      szintLepes: ujXp ~/ szintXp > elozo.xp ~/ szintXp,
      szint: ujXp ~/ szintXp + 1,
      sorozat: ujSorozat,
    );
  }

  /// Törli a pontokat, a sorozatot és a napi számlálót.
  static Future<void> torol() async {
    final p = await SharedPreferences.getInstance();
    for (final k in [
      'stat_xp',
      'stat_ma_nap',
      'stat_ma_db',
      'stat_sorozat',
      'stat_rekord_sorozat',
      'stat_cel_nap',
      'stat_napi_cel',
      'stat_aktiv_napok',
    ]) {
      await p.remove(k);
    }
    allapot.value = const Allapot();
  }
}

/// Üzenet és animáció megjelenítése válasz után.
void jutalomUzenet(BuildContext context, Jutalom j) {
  if (j.szintLepes) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('🎉 Szintlépes! Új szint: ${j.szint}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  if (j.celMost) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('🎯 Napi cél teljesítve! Sorozat: ${j.sorozat} nap 🔥'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }
}