import 'dart:math';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';

import 'haladas.dart';
import 'offline_ai_felolvaso.dart';
import 'statisztika.dart';
import 'szavak.dart';

class KartyaOldal extends StatefulWidget {
  final String cim;
  final List<Szo> szavak;

  const KartyaOldal({super.key, required this.cim, required this.szavak});

  @override
  State<KartyaOldal> createState() => _KartyaOldalState();
}

class _KartyaOldalState extends State<KartyaOldal>
    with SingleTickerProviderStateMixin {
  bool _betoltve = false;
  Set<String> _tudott = {};
  List<Szo> _pakli = [];
  final List<Szo> _hibasak = [];
  int _index = 0;
  bool _felforditva = false;
  int _tudtamEzenAKoron = 0;
  int _xpEzenAKoron = 0;

  late AnimationController _animacioKavezor;
  late Animation<double> _animacio;

  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _animacioKavezor = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animacio = Tween<double>(begin: 0, end: 1).animate(_animacioKavezor);

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    // Sherpa-ONNX AI felolvasó előkészítése
    OfflineAiFelolvaso.inictalizal();

    _indit();
  }

  @override
  void dispose() {
    _animacioKavezor.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Future<void> _indit() async {
    final tudott = await Haladas.betolt();
    final meg =
    widget.szavak.where((s) => !tudott.contains(s.nemet)).toList();
    if (!mounted) return;
    setState(() {
      _tudott = tudott;
      _pakli = _keveres(meg.isEmpty ? widget.szavak : meg);
      _betoltve = true;
    });

    // Az első kártya felolvasása
    if (_pakli.isNotEmpty) {
      OfflineAiFelolvaso.felolvas(_pakli[0].nemet);
    }
  }

  List<Szo> _keveres(List<Szo> lista) => List.of(lista)..shuffle();

  bool get _vege => _index >= _pakli.length;

  List<Szo> get _megNemTudott =>
      widget.szavak.where((s) => !_tudott.contains(s.nemet)).toList();

  int get _temaTudott =>
      widget.szavak.where((s) => _tudott.contains(s.nemet)).length;

  void _megfordit() {
    if (_felforditva) {
      _animacioKavezor.reverse();
    } else {
      _animacioKavezor.forward();
      if (!_vege) {
        OfflineAiFelolvaso.felolvas(_pakli[_index].nemet);
      }
    }
    setState(() => _felforditva = !_felforditva);
  }

  void _valasz({required bool tudta}) {
    final szo = _pakli[_index];
    _animacioKavezor.reset();
    setState(() {
      if (tudta) {
        _tudtamEzenAKoron++;
        _tudott.add(szo.nemet);
      } else {
        _hibasak.add(szo);
        _tudott.remove(szo.nemet);
      }
      _index++;
      _felforditva = false;
    });

    Haladas.ment(_tudott);
    if (tudta) {
      Haladas.hibasTorol(szo.nemet);
    } else {
      Haladas.hibasHozzaad(szo.nemet);
    }

    _statisztika(tudta);

    // Következő kártyára lépéskor az új német szó felolvasása
    if (!_vege) {
      OfflineAiFelolvaso.felolvas(_pakli[_index].nemet);
    }
  }

  void _ujKor(List<Szo> lista) {
    _confettiController.stop();
    _animacioKavezor.reset();
    setState(() {
      _pakli = _keveres(lista);
      _hibasak.clear();
      _index = 0;
      _tudtamEzenAKoron = 0;
      _xpEzenAKoron = 0;
      _felforditva = false;
    });

    if (_pakli.isNotEmpty) {
      OfflineAiFelolvaso.felolvas(_pakli[0].nemet);
    }
  }

  Future<void> _statisztika(bool tudta) async {
    final xp = tudta ? 5 : 1;
    final j = await Statisztika.valaszRogzit(xp: xp);
    if (!mounted) return;

    setState(() => _xpEzenAKoron += xp);

    if (j != null && j.szintLepes) {
      _confettiController.play();
    }

    jutalomUzenet(context, j);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.cim)),
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
                  : _kartya(context),
            ),
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

  Widget _kartya(BuildContext context) {
    final szo = _pakli[_index];
    final szinek = Theme.of(context).colorScheme;

    return Column(
      children: [
        LinearProgressIndicator(value: _index / _pakli.length),
        const SizedBox(height: 8),
        Text('${_index + 1} / ${_pakli.length}'),
        const SizedBox(height: 16),
        Expanded(
          child: GestureDetector(
            onTap: _megfordit,
            child: AnimatedBuilder(
              animation: _animacio,
              builder: (context, child) {
                final ertek = _animacio.value;
                final szog = ertek * pi;
                final hatoldal = ertek >= 0.5;

                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(szog),
                  alignment: Alignment.center,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: hatoldal
                          ? szinek.secondaryContainer
                          : szinek.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: hatoldal
                        ? Transform(
                      transform: Matrix4.identity()..rotateY(pi),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                szo.kepUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                loadingBuilder:
                                    (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                                errorBuilder:
                                    (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 48,
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                szo.magyar,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                              IconButton(
                                icon: const Icon(Icons.volume_up_rounded),
                                tooltip: 'Kiejtés felolvasása',
                                onPressed: () =>
                                    OfflineAiFelolvaso.felolvas(szo.nemet),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text('magyarul'),
                        ],
                      ),
                    )
                        : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          iconSize: 64,
                          icon: Icon(
                            Icons.volume_up_rounded,
                            color: szinek.primary,
                          ),
                          tooltip: 'Kiejtés felolvasása',
                          onPressed: () =>
                              OfflineAiFelolvaso.felolvas(szo.nemet),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          szo.nemet,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium,
                        ),
                        const SizedBox(height: 16),
                        const Text('Koppints a fordításhoz'),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _felforditva ? () => _valasz(tudta: false) : null,
                child: const Text('Nem tudtam'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _felforditva ? () => _valasz(tudta: true) : null,
                child: const Text('Tudtam'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _eredmeny(BuildContext context) {
    final meg = _megNemTudott;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Kész!', style: Theme.of(context).textTheme.displaySmall),
            const SizedBox(height: 16),
            Text('Ebben a körben tudtam: $_tudtamEzenAKoron'),
            Text('Nem tudtam: ${_hibasak.length}'),
            Text('+$_xpEzenAKoron XP'),
            const SizedBox(height: 8),
            Text(
              'Megtanult szavak: $_temaTudott / ${widget.szavak.length}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            if (_hibasak.isNotEmpty) ...[
              FilledButton(
                onPressed: () => _ujKor(List.of(_hibasak)),
                child: Text('Hibás szavak ismétlése (${_hibasak.length})'),
              ),
              const SizedBox(height: 12),
            ],
            if (meg.isNotEmpty) ...[
              OutlinedButton(
                onPressed: () => _ujKor(meg),
                child: Text('Még nem tudott szavak (${meg.length})'),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton(
              onPressed: () => _ujKor(widget.szavak),
              child: const Text('Újrakezdés az összes szóval'),
            ),
          ],
        ),
      ),
    );
  }
}