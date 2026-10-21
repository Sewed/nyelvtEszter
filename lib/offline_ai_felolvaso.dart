import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;

class OfflineAiFelolvaso {
  static sherpa.OfflineTts? _tts;
  static final AudioPlayer _audioPlayer = AudioPlayer();

  static Stream<Duration> get pozicioStream => _audioPlayer.onPositionChanged;

  static Future<void> inictalizal() async {
    if (_tts != null) return;

    try {
      if (kIsWeb) return;

      sherpa.initBindings();

      final dir = await getApplicationDocumentsDirectory();

      final modelPath = await _assetToFile(
        'assets/tts/model.onnx',
        '${dir.path}/model.onnx',
      );
      final tokensPath = await _assetToFile(
        'assets/tts/tokens.txt',
        '${dir.path}/tokens.txt',
      );

      final dataDir = '${dir.path}/espeak-ng-data';
      final espeakFiles = [
        'phontab',
        'phondata',
        'phonindex',
        'intonations',
        'de_dict',
      ];

      for (final fileName in espeakFiles) {
        await _assetToFile(
          'assets/tts/espeak-ng-data/$fileName',
          '$dataDir/$fileName',
        );
      }

      final langDeFile = File('$dataDir/lang/de');
      await langDeFile.parent.create(recursive: true);
      if (!await langDeFile.exists() || await langDeFile.length() == 0) {
        await langDeFile.writeAsString('name German\nlanguage de\n');
      }

      final config = sherpa.OfflineTtsConfig(
        model: sherpa.OfflineTtsModelConfig(
          vits: sherpa.OfflineTtsVitsModelConfig(
            model: modelPath,
            tokens: tokensPath,
            dataDir: dataDir,
          ),
        ),
      );

      _tts = sherpa.OfflineTts(config);
      print("Sherpa-ONNX AI felolvasó sikeresen inicializálva!");
    } catch (e) {
      print("Hiba az offline felolvasó betöltésekor: $e");
    }
  }

  static Future<void> leallit() async {
    await _audioPlayer.stop();
  }

  /// Külön generálási és lejátszási előkészület (ékezetmentes metódusnév)
  static Future<File?> generalWav(String szoveg, {double speed = 0.9}) async {
    if (szoveg.trim().isEmpty) return null;
    if (_tts == null) await inictalizal();
    if (_tts == null) return null;

    try {
      final generatedAudio = _tts!.generate(text: szoveg, sid: 0, speed: speed);
      final samples = generatedAudio.samples;

      if (samples.isEmpty) return null;

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/output.wav');

      final wavData = sherpa.writeWave(
        filename: tempFile.path,
        samples: samples,
        sampleRate: _tts!.sampleRate,
      );

      if (wavData) {
        return tempFile;
      }
    } catch (e) {
      print("Hiba az audió generálása során: $e");
    }
    return null;
  }

  /// Egy fájl lejátszása és bevárása
  static Future<void> jatszdLe(File audioFile) async {
    await _audioPlayer.stop();
    await _audioPlayer.play(DeviceFileSource(audioFile.path));
    await _audioPlayer.onPlayerComplete.first;
  }

  /// Általános felolvasó hívás
  static Future<double> felolvas(String szoveg, {double speed = 0.9}) async {
    final file = await generalWav(szoveg, speed: speed);
    if (file == null) return 0.0;

    final samples = _tts!.generate(text: szoveg, sid: 0, speed: speed).samples;
    final double mp = samples.length / _tts!.sampleRate;

    await jatszdLe(file);
    return mp;
  }

  static Future<String> _assetToFile(
      String assetPath, String targetPath) async {
    final file = File(targetPath);
    final targetDir = Directory(file.parent.path);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    if (!await file.exists()) {
      try {
        final byteData = await rootBundle.load(assetPath);
        await file.writeAsBytes(byteData.buffer.asUint8List());
      } catch (e) {
        print("Asset nem található: $assetPath");
      }
    }
    return targetPath;
  }
}