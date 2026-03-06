import 'dart:async';

import 'package:flutter/material.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MicrophoneAnimation(),
    );
  }
}

class MicrophoneAnimation extends StatefulWidget {
  const MicrophoneAnimation({super.key});

  @override
  State<MicrophoneAnimation> createState() => _MicrophoneAnimationState();
}

class _MicrophoneAnimationState extends State<MicrophoneAnimation>
    with SingleTickerProviderStateMixin {
  StreamSubscription<NoiseReading>? _subscription;
  final NoiseMeter _noiseMeter = NoiseMeter();

  double _decibels = 0;
  bool _isListening = false;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted) return;

    _subscription = _noiseMeter.noise.listen(
      (NoiseReading reading) {
        setState(() {
          _decibels = reading.meanDecibel.clamp(0, 100);
        });
      },
      onError: (_) => _stop(),
    );

    setState(() => _isListening = true);
  }

  void _stop() {
    _subscription?.cancel();
    _subscription = null;
    setState(() {
      _isListening = false;
      _decibels = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 30 dB = silencio, 90 dB = sonido fuerte
    final double intensity = ((_decibels - 30) / 60).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Anillos exteriores que pulsan con el sonido
                    for (int i = 3; i >= 1; i--)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 80),
                        width: 90 + (i * 55.0) * intensity * (1 + _pulseController.value * 0.08),
                        height: 90 + (i * 55.0) * intensity * (1 + _pulseController.value * 0.08),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.deepPurple.withAlpha((38 * intensity / i).round()),
                          border: Border.all(
                            color: Colors.deepPurpleAccent.withAlpha((128 ~/ i)),
                            width: 1.5,
                          ),
                        ),
                      ),

                    // Boton central del microfono
                    GestureDetector(
                      onTap: _isListening ? _stop : _start,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 80),
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isListening
                              ? Color.lerp(
                                  Colors.deepPurple,
                                  Colors.purpleAccent,
                                  intensity,
                                )
                              : Colors.grey.shade800,
                          boxShadow: _isListening
                              ? [
                                  BoxShadow(
                                    color: Colors.deepPurpleAccent
                                        .withAlpha((153 + (intensity * 102).round())),
                                    blurRadius: 20 + intensity * 40,
                                    spreadRadius: intensity * 15,
                                  ),
                                ]
                              : [],
                        ),
                        child: Icon(
                          _isListening ? Icons.mic : Icons.mic_off,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 56),

            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _isListening
                  ? Column(
                      key: const ValueKey('listening'),
                      children: [
                        Text(
                          '${_decibels.toStringAsFixed(1)} dB',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Escuchando... toca para parar',
                          style: TextStyle(
                            color: Colors.white.withAlpha(153),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    )
                  : Text(
                      key: const ValueKey('idle'),
                      'Toca el microfono para empezar',
                      style: TextStyle(
                        color: Colors.white.withAlpha(153),
                        fontSize: 16,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
