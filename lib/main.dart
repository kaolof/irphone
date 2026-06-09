import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

import 'ir_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entrada de la app
// ─────────────────────────────────────────────────────────────────────────────
void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ShowPlayerScreen(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modelo de un cue (evento) de la coreografía
// ─────────────────────────────────────────────────────────────────────────────
class ChoreoEvent {
  final int timeMs;
  final String color;
  const ChoreoEvent({required this.timeMs, required this.color});

  factory ChoreoEvent.fromJson(Map<String, dynamic> json) {
    return ChoreoEvent(
      timeMs: (json['time_ms'] as num).toInt(),
      color: json['color'] as String,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mapeo de nombres de color → Pronto Hex
// Si el nombre termina en _FADE se usa la señal fade; si no, la solid.
// ─────────────────────────────────────────────────────────────────────────────
String getProntoHex(String colorName) {
  final key = colorName.toUpperCase().trim();

  // Detectar sufijo _FADE
  if (key.endsWith('_FADE')) {
    final base = key.replaceAll('_FADE', '');
    if (_fadeMap.containsKey(base)) return _fadeMap[base]!;
    // Fallback: si no hay fade, intentar solid
    if (_solidMap.containsKey(base)) return _solidMap[base]!;
  } else {
    if (_solidMap.containsKey(key)) return _solidMap[key]!;
  }
  // Fallback absoluto: rojo solid
  return _solidMap['RED']!;
}

// ── Señales SOLID (27 colores) ───────────────────────────────────────────────
const _solidMap = <String, String>{
  'WARM_WHITE':
      '0000 006D 000F 0000 001B 001B 001B 001B 001B 001B 001B 0035 001B 006A 001B 0035 001B 001B 0035 0035 001B 001B 001B 001B 0035 001B 001B 001B 001B 001B 001B 0050 001B 076C',
  'COOL_WHITE':
      '0000 006D 000E 0000 001B 001B 001B 001B 0035 0035 0035 006A 001B 0035 001B 001B 001B 0035 001B 0050 001B 001B 001B 001B 001B 001B 001B 001B 0035 0035 001B 076C',
  'RED':
      '0000 006D 000C 0000 001B 001B 001B 0035 001B 0035 0035 006A 001B 0050 0035 001B 001B 001B 001B 001B 001B 001B 0035 0050 0035 006A 001B 076C',
  'RED_ORANGE':
      '0000 006D 000B 0000 001B 001B 001B 0035 0035 001B 0035 006A 001B 0050 001B 0050 0035 001B 001B 001B 0035 0050 0035 006A 001B 076C',
  'ORANGE':
      '0000 006D 000D 0000 001B 001B 001B 0050 0035 001B 001B 006A 001B 0050 001B 001B 001B 001B 0035 001B 001B 001B 001B 0035 001B 001B 0035 006A 001B 076C',
  'YELLOW':
      '0000 006D 000D 0000 001B 001B 001B 006A 001B 001B 001B 006A 001B 0035 001B 0035 001B 001B 0035 001B 001B 001B 0035 001B 001B 001B 0035 006A 001B 076C',
  'GOLD':
      '0000 006D 000C 0000 001B 001B 001B 0050 0035 001B 001B 006A 001B 006A 001B 0035 0035 001B 001B 001B 0035 001B 001B 001B 0035 006A 001B 076C',
  'LIME':
      '0000 006D 000D 0000 001B 001B 001B 0050 0035 001B 001B 006A 001B 0035 001B 0035 001B 001B 0035 001B 001B 001B 001B 0035 001B 001B 0035 006A 001B 076C',
  'GREEN':
      '0000 006D 000D 0000 001B 001B 001B 0035 0035 001B 0035 006A 001B 0035 001B 001B 001B 0050 001B 001B 001B 0035 001B 001B 001B 001B 0035 006A 001B 076C',
  'PASTEL_GREEN':
      '0000 006D 000C 0000 001B 001B 001B 006A 001B 001B 001B 006A 001B 0035 001B 001B 0035 0050 001B 001B 0035 006A 001B 0035 001B 0035 001B 076C',
  'MINT':
      '0000 006D 000D 0000 001B 001B 001B 006A 001B 001B 001B 006A 001B 0035 001B 001B 0035 0050 001B 001B 001B 001B 001B 0050 001B 001B 001B 0050 001B 076C',
  'CYAN':
      '0000 006D 000C 0000 001B 001B 001B 006A 001B 001B 001B 006A 001B 0035 001B 001B 0035 0050 001B 0035 001B 006A 001B 001B 0035 0035 001B 076C',
  'SKY_BLUE':
      '0000 006D 000D 0000 001B 001B 001B 0050 0035 001B 001B 006A 001B 006A 001B 0035 0035 001B 001B 0035 001B 001B 001B 001B 0035 001B 001B 0035 001B 076C',
  'BLUE':
      '0000 006D 000D 0000 001B 001B 001B 0050 0035 001B 001B 006A 001B 0035 001B 001B 001B 0035 0035 0035 0035 0035 001B 001B 001B 001B 0035 0035 001B 076C',
  'PASTEL_BLUE':
      '0000 006D 000C 0000 001B 001B 001B 0050 0035 001B 001B 006A 001B 0050 0035 0035 0035 0050 001B 0035 001B 001B 001B 001B 0035 0035 001B 076C',
  'PURPLE':
      '0000 006D 000E 0000 001B 001B 001B 0050 0035 001B 001B 006A 001B 0035 001B 001B 001B 0035 0035 001B 001B 001B 001B 0035 001B 001B 0035 001B 001B 0035 001B 076C',
  'MAGENTA':
      '0000 006D 000C 0000 001B 001B 001B 0035 0035 001B 0035 006A 001B 0035 001B 001B 001B 0035 0035 0035 0035 006A 001B 0035 001B 0035 001B 076C',
  'ROSE':
      '0000 006D 000D 0000 001B 001B 001B 006A 001B 001B 001B 006A 001B 0050 0035 0035 0035 001B 001B 001B 0035 001B 001B 001B 001B 0035 001B 0035 001B 076C',
  'PINK':
      '0000 006D 000D 0000 001B 001B 001B 0035 0035 001B 0035 006A 001B 0035 001B 001B 001B 0035 0035 001B 001B 0035 001B 0050 001B 0035 001B 0035 001B 076C',
  'LIGHT_PINK':
      '0000 006D 000D 0000 001B 001B 001B 006A 001B 001B 001B 006A 001B 006A 0035 001B 0035 0035 001B 001B 001B 001B 001B 001B 001B 001B 001B 0050 001B 076C',
  'PEACH':
      '0000 006D 000C 0000 001B 001B 001B 001B 0035 0035 0035 006A 001B 006A 001B 0050 001B 001B 001B 001B 0035 0050 001B 0035 001B 0035 001B 076C',
  'PALE_PINK':
      '0000 006D 000D 0000 001B 001B 001B 001B 001B 001B 001B 0035 001B 006A 001B 006A 0035 001B 0035 001B 001B 001B 0035 0050 001B 0035 001B 0035 001B 076C',
  'LAVENDER':
      '0000 006D 000D 0000 001B 001B 001B 0050 0035 001B 001B 006A 001B 006A 001B 0035 0035 001B 001B 001B 001B 0035 001B 001B 001B 001B 0035 0035 001B 076C',
  'LIGHT_GREEN':
      '0000 006D 000C 0000 001B 001B 001B 006A 001B 001B 001B 006A 001B 0035 001B 001B 0035 0050 0035 0035 001B 0050 001B 0035 001B 0035 001B 076C',
  'LIGHT_CYAN':
      '0000 006D 000E 0000 001B 001B 001B 0035 0035 001B 0035 006A 001B 0035 001B 001B 001B 0050 001B 001B 001B 001B 001B 0035 001B 001B 001B 001B 0035 0035 001B 076C',
  'LIGHT_PURPLE':
      '0000 006D 000E 0000 001B 001B 001B 0050 0035 001B 001B 006A 001B 0035 001B 001B 001B 0035 0035 001B 001B 001B 001B 0035 001B 001B 001B 001B 0035 0035 001B 076C',
  'LIGHT_MAGENTA':
      '0000 006D 000B 0000 001B 001B 001B 006A 001B 001B 001B 006A 001B 006A 001B 006A 0035 001B 0035 0050 001B 001B 0035 0035 001B 076C',
};

// ── Señales FADE (27 colores) ────────────────────────────────────────────────
const _fadeMap = <String, String>{
  'WARM_WHITE':
      '0000 006D 0015 0000 001B 001B 001B 001B 001B 001B 001B 0035 001B 006A 001B 0035 001B 001B 0035 0035 001B 001B 001B 001B 0035 001B 001B 001B 001B 001B 001B 0050 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'COOL_WHITE':
      '0000 006D 0014 0000 001B 001B 001B 001B 0035 0035 0035 006A 001B 0035 001B 001B 001B 0035 001B 0050 001B 001B 001B 001B 001B 001B 001B 001B 0035 0035 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'RED':
      '0000 006D 0012 0000 001B 001B 001B 0035 001B 0035 0035 006A 001B 0050 0035 001B 001B 001B 001B 001B 001B 001B 0035 0050 0035 006A 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'RED_ORANGE':
      '0000 006D 0011 0000 001B 001B 001B 0035 0035 001B 0035 006A 001B 0050 001B 0050 0035 001B 001B 001B 0035 0050 0035 006A 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'ORANGE':
      '0000 006D 0013 0000 001B 001B 001B 0050 0035 001B 001B 006A 001B 0050 001B 001B 001B 001B 0035 001B 001B 001B 001B 0035 001B 001B 0035 006A 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'YELLOW':
      '0000 006D 0013 0000 001B 001B 001B 006A 001B 001B 001B 006A 001B 0035 001B 0035 001B 001B 0035 001B 001B 001B 0035 001B 001B 001B 0035 006A 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'GOLD':
      '0000 006D 0012 0000 001B 001B 001B 0050 0035 001B 001B 006A 001B 006A 001B 0035 0035 001B 001B 001B 0035 001B 001B 001B 0035 006A 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'LIME':
      '0000 006D 0013 0000 001B 001B 001B 0050 0035 001B 001B 006A 001B 0035 001B 0035 001B 001B 0035 001B 001B 001B 001B 0035 001B 001B 0035 006A 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'GREEN':
      '0000 006D 0013 0000 001B 001B 001B 0035 0035 001B 0035 006A 001B 0035 001B 001B 001B 0050 001B 001B 001B 0035 001B 001B 001B 001B 0035 006A 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'PASTEL_GREEN':
      '0000 006D 0012 0000 001B 001B 001B 006A 001B 001B 001B 006A 001B 0035 001B 001B 0035 0050 001B 001B 0035 006A 001B 0035 001B 0035 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'MINT':
      '0000 006D 0013 0000 001B 001B 001B 006A 001B 001B 001B 006A 001B 0035 001B 001B 0035 0050 001B 001B 001B 001B 001B 0050 001B 001B 001B 0050 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'CYAN':
      '0000 006D 0012 0000 001B 001B 001B 006A 001B 001B 001B 006A 001B 0035 001B 001B 0035 0050 001B 0035 001B 006A 001B 001B 0035 0035 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'SKY_BLUE':
      '0000 006D 0013 0000 001B 001B 001B 0050 0035 001B 001B 006A 001B 006A 001B 0035 0035 001B 001B 0035 001B 001B 001B 001B 0035 001B 001B 0035 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'BLUE':
      '0000 006D 0013 0000 001B 001B 001B 0050 0035 001B 001B 006A 001B 0035 001B 001B 001B 0035 0035 0035 0035 0035 001B 001B 001B 001B 0035 0035 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'PASTEL_BLUE':
      '0000 006D 0012 0000 001B 001B 001B 0050 0035 001B 001B 006A 001B 0050 0035 0035 0035 0050 001B 0035 001B 001B 001B 001B 0035 0035 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'PURPLE':
      '0000 006D 0014 0000 001B 001B 001B 0050 0035 001B 001B 006A 001B 0035 001B 001B 001B 0035 0035 001B 001B 001B 001B 0035 001B 001B 0035 001B 001B 0035 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'MAGENTA':
      '0000 006D 0012 0000 001B 001B 001B 0035 0035 001B 0035 006A 001B 0035 001B 001B 001B 0035 0035 0035 0035 006A 001B 0035 001B 0035 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'ROSE':
      '0000 006D 0013 0000 001B 001B 001B 006A 001B 001B 001B 006A 001B 0050 0035 0035 0035 001B 001B 001B 0035 001B 001B 001B 001B 0035 001B 0035 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'PINK':
      '0000 006D 0013 0000 001B 001B 001B 0035 0035 001B 0035 006A 001B 0035 001B 001B 001B 0035 0035 001B 001B 0035 001B 0050 001B 0035 001B 0035 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'LIGHT_PINK':
      '0000 006D 0013 0000 001B 001B 001B 006A 001B 001B 001B 006A 001B 006A 0035 001B 0035 0035 001B 001B 001B 001B 001B 001B 001B 001B 001B 0050 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'PEACH':
      '0000 006D 0012 0000 001B 001B 001B 001B 0035 0035 0035 006A 001B 006A 001B 0050 001B 001B 001B 001B 0035 0050 001B 0035 001B 0035 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'PALE_PINK':
      '0000 006D 0013 0000 001B 001B 001B 001B 001B 001B 001B 0035 001B 006A 001B 006A 0035 001B 0035 001B 001B 001B 0035 0050 001B 0035 001B 0035 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'LAVENDER':
      '0000 006D 0013 0000 001B 001B 001B 0050 0035 001B 001B 006A 001B 006A 001B 0035 0035 001B 001B 001B 001B 0035 001B 001B 001B 001B 0035 0035 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'LIGHT_GREEN':
      '0000 006D 0012 0000 001B 001B 001B 006A 001B 001B 001B 006A 001B 0035 001B 001B 0035 0050 0035 0035 001B 0050 001B 0035 001B 0035 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'LIGHT_CYAN':
      '0000 006D 0014 0000 001B 001B 001B 0035 0035 001B 0035 006A 001B 0035 001B 001B 001B 0050 001B 001B 001B 001B 001B 0035 001B 001B 001B 001B 0035 0035 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'LIGHT_PURPLE':
      '0000 006D 0014 0000 001B 001B 001B 0050 0035 001B 001B 006A 001B 0035 001B 001B 001B 0035 0035 001B 001B 001B 001B 0035 001B 001B 001B 001B 0035 0035 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
  'LIGHT_MAGENTA':
      '0000 006D 0011 0000 001B 001B 001B 006A 001B 001B 001B 006A 001B 006A 001B 006A 0035 001B 0035 0050 001B 001B 0035 0035 001B 0035 001B 0035 0035 001B 001B 0035 0035 006A 0035 006A 001B 076C',
};

// ─────────────────────────────────────────────────────────────────────────────
// Pantalla principal: Reproductor de Shows Secuenciados
// ─────────────────────────────────────────────────────────────────────────────
class ShowPlayerScreen extends StatefulWidget {
  const ShowPlayerScreen({super.key});

  @override
  State<ShowPlayerScreen> createState() => _ShowPlayerScreenState();
}

class _ShowPlayerScreenState extends State<ShowPlayerScreen> {
  // Canal IR nativo (NO modificar)
  static const _irChannel = MethodChannel('com.example.irphone/ir');

  // Reproductor de audio
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;

  // Archivos seleccionados
  String? _audioFileName;
  String? _audioFilePath;
  String? _jsonFileName;

  // Coreografía parseada
  List<ChoreoEvent> _events = [];
  int _nextEventIndex = 0;

  // Estado del show
  bool _isPlaying = false;
  bool _irBusy = false;
  String _lastColor = '';
  Color _lastColorVisual = Colors.transparent;

  @override
  void dispose() {
    _positionSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // ── Permisos de almacenamiento ──────────────────────────────────────────
  Future<bool> _ensureStoragePermission() async {
    // Android 13+ no necesita READ_EXTERNAL_STORAGE para archivos multimedia
    // seleccionados con file_picker (usa SAF). En versiones anteriores, pedimos.
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      // En Android 13+ esto puede ser denegado permanentemente, pero file_picker
      // funciona igual gracias a SAF. No bloqueamos.
      if (status.isGranted || status.isLimited) return true;
      // Intentar con los permisos granulares de Android 13+
      final audio = await Permission.audio.request();
      return audio.isGranted || status.isGranted || status.isLimited;
    }
    return true;
  }

  // ── Seleccionar archivo de audio ────────────────────────────────────────
  Future<void> _pickAudioFile() async {
    await _ensureStoragePermission();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'ogg'],
    );
    if (result == null || result.files.single.path == null) return;

    final file = result.files.single;
    setState(() {
      _audioFileName = file.name;
      _audioFilePath = file.path;
    });
  }

  // ── Seleccionar archivo JSON de coreografía ─────────────────────────────
  Future<void> _pickJsonFile() async {
    await _ensureStoragePermission();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return;

    final file = result.files.single;
    try {
      final contents = await File(file.path!).readAsString();
      final List<dynamic> decoded = jsonDecode(contents) as List<dynamic>;
      final events =
          decoded
              .map((e) => ChoreoEvent.fromJson(e as Map<String, dynamic>))
              .toList()
            ..sort((a, b) => a.timeMs.compareTo(b.timeMs));

      setState(() {
        _jsonFileName = file.name;
        _events = events;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al parsear JSON: $e')));
      }
    }
  }

  // ── Iniciar el show ─────────────────────────────────────────────────────
  Future<void> _startShow() async {
    if (_audioFilePath == null || _events.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Carga un archivo MP3 y un JSON primero')),
      );
      return;
    }

    // Cargar el audio desde archivo local
    try {
      await _audioPlayer.setAudioSource(AudioSource.file(_audioFilePath!));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al cargar audio: $e')));
      }
      return;
    }

    setState(() {
      _nextEventIndex = 0;
      _isPlaying = true;
      _lastColor = '';
      _lastColorVisual = Colors.transparent;
    });

    // Escuchar posición para sincronizar cues IR
    _positionSub?.cancel();
    _positionSub = _audioPlayer.positionStream.listen(_onPositionUpdate);

    // Detectar cuando el audio termina
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _stopShow();
      }
    });

    await _audioPlayer.play();
  }

  // ── Detener el show ─────────────────────────────────────────────────────
  Future<void> _stopShow() async {
    _positionSub?.cancel();
    _positionSub = null;
    await _audioPlayer.stop();
    await _audioPlayer.seek(Duration.zero);
    if (mounted) {
      setState(() {
        _isPlaying = false;
        _nextEventIndex = 0;
      });
    }
  }

  // ── Motor de sincronización ─────────────────────────────────────────────
  // Se ejecuta con cada tick del positionStream (~200ms).
  // Avanza por los cues pendientes y envía el más reciente por IR.
  void _onPositionUpdate(Duration position) {
    if (!_isPlaying || _events.isEmpty) return;

    final int posMs = position.inMilliseconds;

    // Recopilar el último evento pendiente cuyo tiempo ya pasó.
    // Si hay varios acumulados en un solo tick, solo importa el más
    // reciente (el brazalete solo puede mostrar un color a la vez).
    ChoreoEvent? lastPending;
    while (_nextEventIndex < _events.length &&
        posMs >= _events[_nextEventIndex].timeMs) {
      lastPending = _events[_nextEventIndex];
      _nextEventIndex++;
    }

    if (lastPending == null) return;

    // Actualizar UI con el color actual
    setState(() {
      _lastColor = lastPending!.color;
      _lastColorVisual = _visualColorFromName(lastPending.color);
    });

    // Encolar la señal IR (si está ocupado, reemplaza la pendiente)
    _queueIr(getProntoHex(lastPending.color));
  }

  // ── Cola de envío IR ────────────────────────────────────────────────────
  // Si el emisor está ocupado, guarda el último comando pendiente y lo
  // envía apenas termine el actual. Así nunca se pierde un color.
  String? _pendingIrProto;

  Future<void> _queueIr(String pronto) async {
    _pendingIrProto = pronto;
    if (_irBusy) return; // ya hay un envío activo que procesará la cola
    await _processIrQueue();
  }

  Future<void> _processIrQueue() async {
    while (_pendingIrProto != null) {
      _irBusy = true;
      final toSend = _pendingIrProto!;
      _pendingIrProto = null; // consumir
      try {
        await _irChannel.invokeMethod('sendProntoHex', {'pronto': toSend});
      } catch (_) {}
      _irBusy = false;
    }
  }

  // ── Color visual para la UI ─────────────────────────────────────────────
  Color _visualColorFromName(String name) {
    // Quitar sufijo _FADE para obtener el color base
    String key = name.toUpperCase().trim();
    if (key.endsWith('_FADE')) key = key.replaceAll('_FADE', '');

    switch (key) {
      case 'WARM_WHITE':
        return const Color(0xFFF2F2E6);
      case 'COOL_WHITE':
        return const Color(0xFFE6ECF2);
      case 'RED':
        return const Color(0xFFFF0000);
      case 'RED_ORANGE':
        return const Color(0xFFFA4002);
      case 'ORANGE':
        return const Color(0xFFFA8202);
      case 'YELLOW':
        return const Color(0xFFFCF000);
      case 'GOLD':
        return const Color(0xFFFAC002);
      case 'LIME':
        return const Color(0xFFE3FC00);
      case 'GREEN':
        return const Color(0xFF00FC15);
      case 'PASTEL_GREEN':
        return const Color(0xFFA6F5AD);
      case 'MINT':
        return const Color(0xFF95FCD8);
      case 'CYAN':
        return const Color(0xFF00F2FF);
      case 'SKY_BLUE':
        return const Color(0xFF00DDFF);
      case 'BLUE':
        return const Color(0xFF4298F5);
      case 'PASTEL_BLUE':
        return const Color(0xFF92A8F7);
      case 'PURPLE':
        return const Color(0xFFCF87FF);
      case 'MAGENTA':
        return const Color(0xFFE34DBE);
      case 'ROSE':
        return const Color(0xFFF77CAD);
      case 'PINK':
        return const Color(0xFFFF008C);
      case 'LIGHT_PINK':
        return const Color(0xFFFFD9DE);
      case 'PEACH':
        return const Color(0xFFFCE6DE);
      case 'PALE_PINK':
        return const Color(0xFFFFBABA);
      case 'LAVENDER':
        return const Color(0xFFE0E2FF);
      case 'LIGHT_GREEN':
        return const Color(0xFFE2FFE0);
      case 'LIGHT_CYAN':
        return const Color(0xFFE0FAFF);
      case 'LIGHT_PURPLE':
        return const Color(0xFFECDEFF);
      case 'LIGHT_MAGENTA':
        return const Color(0xFFFDDEFF);
      default:
        return Colors.grey;
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF080810),
      appBar: AppBar(
        backgroundColor: const Color(0xFF080810),
        foregroundColor: Colors.white,
        title: const Text(
          'PixMob Show Player',
          style: TextStyle(letterSpacing: 2),
        ),
        elevation: 0,
        actions: [
          // Botón para acceder a la pantalla de IR manual
          IconButton(
            icon: const Icon(Icons.flashlight_on, color: Color(0xFFFF4444)),
            tooltip: 'IR Manual',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const IrScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 24),

              // ── Indicador visual del último color disparado ──────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                height: 120,
                decoration: BoxDecoration(
                  color: _lastColorVisual.withAlpha(
                    _lastColor.isEmpty ? 20 : 180,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _lastColor.isEmpty
                        ? Colors.white12
                        : _lastColorVisual,
                    width: 2,
                  ),
                  boxShadow: _lastColor.isNotEmpty
                      ? [
                          BoxShadow(
                            color: _lastColorVisual.withAlpha(100),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ]
                      : null,
                ),
                alignment: Alignment.center,
                child: Text(
                  _lastColor.isEmpty ? 'Sin señal' : _lastColor.toUpperCase(),
                  style: TextStyle(
                    color: _lastColor.isEmpty ? Colors.white38 : Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Selector de audio ───────────────────────────────────
              _FileSelector(
                icon: Icons.music_note,
                label: 'Audio (MP3/WAV)',
                fileName: _audioFileName,
                onTap: _isPlaying ? null : _pickAudioFile,
              ),

              const SizedBox(height: 12),

              // ── Selector de JSON ────────────────────────────────────
              _FileSelector(
                icon: Icons.data_object,
                label: 'Coreografía (JSON)',
                fileName: _jsonFileName,
                subtitle: _events.isNotEmpty
                    ? '${_events.length} eventos cargados'
                    : null,
                onTap: _isPlaying ? null : _pickJsonFile,
              ),

              const Spacer(),

              // ── Botón PLAY / STOP ───────────────────────────────────
              GestureDetector(
                onTap: _isPlaying ? _stopShow : _startShow,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isPlaying
                        ? const Color(0xFFCC0000).withAlpha(60)
                        : const Color(0xFF00CC44).withAlpha(40),
                    border: Border.all(
                      color: _isPlaying
                          ? const Color(0xFFFF2222)
                          : const Color(0xFF00FF66),
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_isPlaying
                                    ? const Color(0xFFFF0000)
                                    : const Color(0xFF00FF66))
                                .withAlpha(80),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    _isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
              ),

              const SizedBox(height: 12),
              Text(
                _isPlaying ? 'DETENER SHOW' : 'INICIAR SHOW',
                style: TextStyle(
                  color: Colors.white.withAlpha(120),
                  fontSize: 13,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget reutilizable para los selectores de archivo
// ─────────────────────────────────────────────────────────────────────────────
class _FileSelector extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? fileName;
  final String? subtitle;
  final VoidCallback? onTap;

  const _FileSelector({
    required this.icon,
    required this.label,
    this.fileName,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool loaded = fileName != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: loaded
              ? Colors.white.withAlpha(10)
              : Colors.white.withAlpha(5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: loaded ? Colors.green.withAlpha(120) : Colors.white24,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: loaded ? Colors.green : Colors.white54, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    loaded ? fileName! : label,
                    style: TextStyle(
                      color: loaded ? Colors.white : Colors.white54,
                      fontSize: 14,
                      fontWeight: loaded ? FontWeight.w500 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Colors.white.withAlpha(80),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              loaded ? Icons.check_circle : Icons.folder_open,
              color: loaded ? Colors.green : Colors.white38,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
