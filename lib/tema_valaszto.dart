import 'package:flutter/material.dart';

import 'haladas.dart';
import 'kartya_oldal.dart';
import 'kviz_oldal.dart';
import 'szavak.dart';

class TemaValaszto extends StatefulWidget {
  /// true: kvíz indul a kiválasztott témával, false: szókártyák.
  final bool kviz;

  const TemaValaszto({super.key, this.kviz = false});

  @override
  State<TemaValaszto> createState() => _TemaValasztoState();
}

class _TemaValasztoState extends State<TemaValaszto> {
  Set<String> _tudott = {};

  @override
  void initState() {
    super.initState();
    _frissit();
  }

  Future<void> _frissit() async {
    final tudott = await Haladas.betolt();
    if (mounted) setState(() => _tudott = tudott);
  }

  int _tudottDb(List<Szo> lista) =>
      lista.where((s) => _tudott.contains(s.nemet)).length;

  Future<void> _megnyit(String cim, List<Szo> lista) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => widget.kviz
            ? KvizOldal(cim: cim, szavak: lista)
            : KartyaOldal(cim: cim, szavak: lista),
      ),
    );
    _frissit(); // visszatéréskor frissül a haladás
  }

  Widget _csempe({
    required IconData ikon,
    required String cim,
    required List<Szo> lista,
  }) {
    final szinek = Theme.of(context).colorScheme;
    final tudott = _tudottDb(lista);
    final arany = tudott / lista.length;
    final kesz = tudott == lista.length;
    final szin = kesz ? Colors.green : szinek.primary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _megnyit(cim, lista),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: arany,
                        strokeWidth: 6,
                        strokeCap: StrokeCap.round,
                        backgroundColor: szinek.surfaceContainerHighest,
                        color: szin,
                      ),
                    ),
                    Icon(ikon, size: 36, color: szin),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                cim,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 2),
              Text(
                '$tudott / ${lista.length}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kviz ? 'Kvíz: válassz témát' : 'Témakörök'),
      ),
      body: SafeArea(
        child: GridView(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            mainAxisExtent: 185,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          children: [
            _csempe(ikon: Icons.apps, cim: 'Minden téma', lista: osszesSzo),
            for (final t in temak)
              _csempe(ikon: t.ikon, cim: t.nev, lista: t.szavak),
          ],
        ),
      ),
    );
  }
}