import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'haladas.dart';
import 'offline_ai_felolvaso.dart';
import 'statisztika.dart';
import 'szavak.dart';

/// Egy kvízkérdés: a német szó és a 4 válaszlehetőség (magyar jelentések).
class Kerdes {
  final Szo szo;
  final List<String> valaszok;
  const Kerdes(this.szo, this.valaszok);
}

class KvizOldal extends StatefulWidget {
  final String cim;
  final List<Szo> szavak;

  const KvizOldal({super.key, required this.cim, required this.szavak});

  @override
  State<KvizOldal> createState() => _KvizOldalState();
}

class _KvizOldalState extends State<KvizOldal> {
  static const _kerdesSzam = 10;

  bool _betoltve = false;
  Set<String> _tudott = {};
  List<Kerdes> _kerdesek = [];
  final List<Szo> _hibasak = [];
  int _index = 0;
  int _pont = 0;
  int _xpEzenAKoron = 0;
  String? _valasztott; // null = még nem válaszolt erre a kérdésre

  // Tűzijáték / Konfetti vezérlő
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    // Offline AI Felolvasó inicializálása
    OfflineAiFelolvaso.inictalizal();

    _indit();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _indit() async {
    final tudott = await Haladas.betolt();
    if (!mounted) return;
    setState(() {
      _tudott = tudott;
      _ujKviz();
      _betoltve = true;
    });
  }

  void _ujKviz() {
    _confettiController.stop();
    final nemTudott =
    widget.szavak.where((s) => !_tudott.contains(s.nemet)).toList()
      ..shuffle();
    final tudott =
    widget.szavak.where((s) => _tudott.contains(s.nemet)).toList()
      ..shuffle();
    final valogatott = [...nemTudott, ...tudott].take(_kerdesSzam).toList()
      ..shuffle();

    _kerdesek = [for (final s in valogatott) _kerdesKeszit(s)];
    _hibasak.clear();
    _index = 0;
    _pont = 0;
    _xpEzenAKoron = 0;
    _valasztott = null;

    // Első kérdés felolvasása
    if (_kerdesek.isNotEmpty) {
      OfflineAiFelolvaso.felolvas(_kerdesek[0].szo.nemet);
    }
  }

  Kerdes _kerdesKeszit(Szo szo) {
    final rossz = <String>{};
    final temaSzavak = List.of(widget.szavak)..shuffle();
    final mindenSzo = List.of(osszesSzo)..shuffle();
    for (final s in [...temaSzavak, ...mindenSzo]) {
      if (rossz.length == 3) break;
      if (s.magyar != szo.magyar) rossz.add(s.magyar);
    }
    final valaszok = [szo.magyar, ...rossz]..shuffle();
    return Kerdes(szo, valaszok);
  }

  bool get _vege => _index >= _kerdesek.length;

  void _valaszol(String valasz) {
    if (_valasztott != null) return;
    final szo = _kerdesek[_index].szo;
    final helyes = valasz == szo.magyar;
    setState(() {
      _valasztott = valasz;
      if (helyes) {
        _pont++;
        _tudott.add(szo.nemet);
      } else {
        _hibasak.add(szo);
        _tudott.remove(szo.nemet);
      }
    });

    Haladas.ment(_tudott);
    if (helyes) {
      Haladas.hibasTorol(szo.nemet);
      HapticFeedback.lightImpact();
    } else {
      Haladas.hibasHozzaad(szo.nemet);
      HapticFeedback.mediumImpact();
    }

    _statisztika(helyes);
  }

  Future<void> _statisztika(bool helyes) async {
    final xp = helyes ? 10 : 2;
    final j = await Statisztika.valaszRogzit(xp: xp);
    if (!mounted) return;

    setState(() => _xpEzenAKoron += xp);

    // KIZÁRÓLAG SZINTLÉPÉSKOR INDUL EL A TŰZIJÁTÉK
    if (j != null && j.szintLepes) {
      _confettiController.play();
    }

    jutalomUzenet(context, j);
  }

  void _kovetkezo() {
    setState(() {
      _index++;
      _valasztott = null;
    });

    // Következő kérdés német szavának felolvasása
    if (!_vege) {
      OfflineAiFelolvaso.felolvas(_kerdesek[_index].szo.nemet);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Kvíz: ${widget.cim}')),
      body: SafeArea(
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: !_betoltve
                  ? const Center(child: CircularProgressIndicator())
                  : _vege
                  ? _eredmeny(context)
                  : _kerdes(context),
            ),
            // Tűzijáték / Konfetti réteg
            ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 40,
              gravity: 0.2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _kerdes(BuildContext context) {
    final k = _kerdesek[_index];
    final szinek = Theme.of(context).colorScheme;
    final utolso = _index == _kerdesek.length - 1;
    final valaszolt = _valasztott != null;

    return Column(
      children: [
        LinearProgressIndicator(value: _index / _kerdesek.length),
        const SizedBox(height: 8),
        Text('${_index + 1} / ${_kerdesek.length}'),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: szinek.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: AnimatedCrossFade(
                    key: ValueKey(_index),
                    duration: const Duration(milliseconds: 300),
                    crossFadeState: valaszolt
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    firstChild: Center(
                      child: Icon(
                        Icons.help_outline_rounded,
                        size: 80,
                        color: szinek.primary.withValues(alpha: 0.5),
                      ),
                    ),
                    secondChild: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          k.szo.kepUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.image_not_supported_outlined,
                              size: 48,
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      k.szo.nemet,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    IconButton(
                      icon: const Icon(Icons.volume_up_rounded),
                      tooltip: 'Kiejtés felolvasása',
                      onPressed: () => OfflineAiFelolvaso.felolvas(k.szo.nemet),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('Mi a magyar jelentése?'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final valasz in k.valaszok) _valaszGomb(valasz, k.szo.magyar),
        SizedBox(
          height: 48,
          width: double.infinity,
          child: _valasztott == null
              ? null
              : FilledButton(
            onPressed: _kovetkezo,
            child: Text(utolso ? 'Eredmény' : 'Következő'),
          ),
        ),
      ],
    );
  }

  Widget _valaszGomb(String valasz, String helyes) {
    final valasztott = _valasztott;
    Color? hatter;
    Color? keret;
    IconData? ikon;

    if (valasztott != null) {
      if (valasz == helyes) {
        hatter = Colors.green.withValues(alpha: 0.25);
        keret = Colors.green;
        ikon = Icons.check_circle;
      } else if (valasz == valasztott) {
        hatter = Colors.red.withValues(alpha: 0.25);
        keret = Colors.red;
        ikon = Icons.cancel;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          backgroundColor: hatter,
          side: keret != null ? BorderSide(color: keret, width: 2) : null,
        ),
        onPressed: () => _valaszol(valasz),
        child: Row(
          children: [
            Expanded(child: Text(valasz)),
            if (ikon != null) Icon(ikon, color: keret),
          ],
        ),
      ),
    );
  }

  Widget _eredmeny(BuildContext context) {
    final osszes = _kerdesek.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(
          '$_pont / $osszes',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 4),
        Text(
          _hibasak.isEmpty ? 'Hibátlan!' : 'Ezeket gyakorold még:',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '+$_xpEzenAKoron XP',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView(
            children: [
              for (final szo in _hibasak)
                ListTile(
                  leading: const Icon(Icons.close, color: Colors.red),
                  title: Text(szo.nemet),
                  subtitle: Text(szo.magyar),
                  trailing: IconButton(
                    icon: const Icon(Icons.volume_up_rounded),
                    onPressed: () => OfflineAiFelolvaso.felolvas(szo.nemet),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: () => setState(_ujKviz),
          child: const Text('Új kvíz'),
        ),
      ],
    );
  }
}