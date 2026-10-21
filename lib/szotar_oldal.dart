import 'package:flutter/material.dart';

import 'offline_ai_felolvaso.dart';
import 'szavak.dart';

class SzotarOldal extends StatefulWidget {
  const SzotarOldal({super.key});

  @override
  State<SzotarOldal> createState() => _SzotarOldalState();
}

class _SzotarOldalState extends State<SzotarOldal> {
  final TextEditingController _keresoController = TextEditingController();

  String _kereses = '';
  String? _valasztottTema; // null = összes téma

  @override
  void initState() {
    super.initState();
    // Sherpa-ONNX AI felolvasó előkészítése / betöltése
    OfflineAiFelolvaso.inictalizal();
  }

  @override
  void dispose() {
    _keresoController.dispose();
    super.dispose();
  }

  Future<void> _felolvas(String szoveg) async {
    await OfflineAiFelolvaso.felolvas(szoveg);
  }

  /// Kép felugró ablak megjelenítése animációval
  void _kepMegjelenitese(BuildContext context, Szo szo) {
    _felolvas(szo.nemet); // Megnyitáskor le is játssza a kiejtést

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'KepBezaras',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return const SizedBox();
      },
      transitionBuilder: (context, animacio, masodlagosAnimacio, child) {
        final szinek = Theme.of(context).colorScheme;

        return ScaleTransition(
          scale: CurvedAnimation(
            parent: animacio,
            curve: Curves.easeOutBack,
          ),
          child: FadeTransition(
            opacity: animacio,
            child: Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => Navigator.of(context).pop(),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: Image.network(
                            szo.kepUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: szinek.primaryContainer,
                                  child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 48,
                                  ),
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        szo.nemet,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        szo.magyar,
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Koppints bárhova a bezáráshoz',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: szinek.outline,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Szo> get _szurtSzavak {
    return osszesSzo.where((szo) {
      final egyezikKereses = szo.nemet
          .toLowerCase()
          .contains(_kereses.toLowerCase()) ||
          szo.magyar.toLowerCase().contains(_kereses.toLowerCase());

      if (_valasztottTema == null) {
        return egyezikKereses;
      }

      final tema = temak.firstWhere(
            (t) => t.nev == _valasztottTema,
        orElse: () => temak.first,
      );

      final benneVanATemaban = tema.szavak.any((s) => s.nemet == szo.nemet);
      return egyezikKereses && benneVanATemaban;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final szinek = Theme.of(context).colorScheme;
    final talalatok = _szurtSzavak;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Szótár és kereső'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Keresőmező és Szűrő
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  TextField(
                    controller: _keresoController,
                    decoration: InputDecoration(
                      hintText: 'Keresés németül vagy magyarul...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _kereses.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _keresoController.clear();
                          setState(() => _kereses = '');
                        },
                      )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: szinek.surfaceContainerHighest.withValues(alpha: 0.5),
                    ),
                    onChanged: (ertek) => setState(() => _kereses = ertek),
                  ),
                  const SizedBox(height: 12),
                  // Témakör szűrő chipek
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: FilterChip(
                            label: const Text('Összes téma'),
                            selected: _valasztottTema == null,
                            onSelected: (_) =>
                                setState(() => _valasztottTema = null),
                          ),
                        ),
                        for (final t in temak)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: FilterChip(
                              avatar: Icon(t.ikon, size: 18),
                              label: Text(t.nev),
                              selected: _valasztottTema == t.nev,
                              onSelected: (_) =>
                                  setState(() => _valasztottTema = t.nev),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Találatok száma
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  Text(
                    'Találatok: ${talalatok.length} szó',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Szólista
            Expanded(
              child: talalatok.isEmpty
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      size: 64,
                      color: szinek.outline,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Nincs találat a keresésre',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: talalatok.length,
                itemBuilder: (context, index) {
                  final szo = talalatok[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      onTap: () => _kepMegjelenitese(context, szo),
                      title: Text(
                        szo.nemet,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      subtitle: Text(szo.magyar),
                      trailing: IconButton(
                        icon: const Icon(Icons.volume_up_rounded),
                        color: szinek.primary,
                        tooltip: 'Kiejtés felolvasása',
                        onPressed: () => _felolvas(szo.nemet),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}