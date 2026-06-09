# Contexto del proyecto: irphone

## Descripcion general

App Flutter para Android que controla brazaletes LED PixMob mediante el emisor IR del telefono.
Escucha el audio del microfono en tiempo real, realiza un analisis FFT y puede disparar senales IR
automaticamente cuando detecta un beat musical.

- Nombre del paquete: `com.example.irphone`
- SDK Flutter: ^3.9.2
- Plataforma objetivo: Android (requiere hardware IR)

---

## Estructura de archivos relevantes

```
irphone/
├── lib/
│   ├── main.dart         # Pantalla principal: audio, FFT, visualizacion, Auto IR
│   └── ir_screen.dart    # Pantalla secundaria: paleta PixMob, envio IR manual
├── android/app/src/main/
│   ├── kotlin/com/example/irphone/MainActivity.kt  # Nativo Android: ConsumerIrManager
│   └── AndroidManifest.xml                         # Permisos
└── pubspec.yaml
```

---

## Dependencias (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  audio_streamer: ^4.2.2      # Stream de audio crudo desde el microfono
  permission_handler: ^11.4.0 # Solicitud de permisos en runtime
  # noise_meter: ^5.0.2       # Declarado pero no usado actualmente
```

---

## Permisos Android (AndroidManifest.xml)

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MICROPHONE" />
<uses-permission android:name="android.permission.TRANSMIT_IR" />
<uses-permission android:name="android.permission.VIBRATE" />
```

---

## lib/main.dart — Pantalla principal

### Widget principal: `MicrophoneAnimation` (StatefulWidget)

**Estado:**
- `_audioStreamer` / `_audioSub`: stream de samples PCM via `audio_streamer`
- `_sampleRate`: 44100 Hz
- `_decibels`, `_frequency`, `_noteName`: valores calculados en tiempo real
- `_bands`: lista de 24 valores (0.0–1.0) para el espectro de frecuencias
- `_isListening`: bool, si el microfono esta activo
- `_autoIr`: bool, si el modo automatico IR esta activo
- `_sensitivity`: double (0–1), controla el threshold de deteccion de beats
- `_irChannel`: `MethodChannel('com.example.irphone/ir')`
- `_hueController`, `_pulseController`: `AnimationController` para efectos visuales

**Funciones clave:**

| Funcion | Descripcion |
|---|---|
| `_start()` | Pide permiso de microfono y arranca el stream de audio |
| `_stop()` | Cancela el stream y resetea el estado |
| `_processAudio(samples)` | Procesamiento principal: calcula dB, FFT, bandas espectrales. Rate-limited a ~25 fps |
| `_detectBeatAndSend(db)` | Detecta beats por comparacion con promedio exponencial, dispara IR |
| `_sendIr(pronto)` | Envia senal IR via MethodChannel (ignora si ya esta ocupado) |
| `_noteFromFreq(freq)` | Convierte frecuencia Hz a nombre de nota musical (ej: "A4") |
| `_dbToColorIndex(db)` | Mapea nivel de dB a un indice de color de la lista PixMob |
| `_fft(re, im)` | FFT Cooley-Tukey in-place implementada manualmente en Dart |

**Calculo de dB:**
```dart
// Usa amplitud peak-to-peak, no RMS
final double mean = 0.5 * (minAbs + maxAbs);
final double dB = mean > 0 ? 20 * log(maxAmp * mean) / log(10) : 0;
// maxAmp = 2^15 (asume PCM de 16 bits)
```

**FFT:**
- Tamano N: potencia de 2 mas cercana al buffer, maximo 4096
- Ventana Hann aplicada antes de la FFT
- Magnitud: `sqrt(re^2 + im^2)` para cada bin

**Bandas espectrales (24 bandas log):**
- Rango: 80 Hz – 4000 Hz
- Escala logaritmica: `fLow = 80 * (4000/80)^(b/24)`
- Cada banda = promedio de magnitudes en su rango de bins
- Normalizadas a 0.0–1.0

**Deteccion de beat (Auto IR):**
```dart
_dbAverage = _dbAverage * 0.88 + db * 0.12;  // EMA
final double threshold = 8.0 + _sensitivity * 14.0; // 8 dB (sensible) a 22 dB (poco sensible)
final bool isBeat = db > _dbAverage + threshold && db > _prevDb;
// Rate-limit: minimo 300 ms entre senales IR
```

**UI:**
- Fondo negro (`0xFF080810`)
- Orbe superior animado: hue ciclico, tamano y brillo proporcionales al volumen
- `_SpotlightPainter`: CustomPainter que dibuja un haz de luz desde arriba
- 24 barras de espectro animadas con `AnimatedContainer`
- Frecuencia dominante y nota musical mostradas en texto
- 3 botones circulares: Mic, IR Manual (navega a `IrScreen`), Auto IR
- Slider de sensibilidad (visible solo cuando Auto IR esta activo)

---

## lib/ir_screen.dart — Pantalla IR Manual

### Clases de datos

```dart
class PixmobBtn {
  final Color color;
  final String pronto; // Pronto Hex string
}
```

**`pixmobSolid`**: lista de 27 `PixmobBtn` con senales de color solido
**`pixmobFade`**: lista de 27 `PixmobBtn` con senales de color con fade

Las senales estan en formato Pronto Hex a 38028 Hz, extraidas de archivos IRplus para dispositivo PixMob.

### Widget: `IrScreen` (StatefulWidget)

- `_irChannel`: `MethodChannel('com.example.irphone/ir')` (mismo canal que main.dart)
- `_sending`: String? con el pronto que se esta enviando actualmente (para feedback visual)
- `_tabController`: tabs "Solido" / "Fade"

**UI:**
- `AppBar` con `TabBar` (Solido / Fade)
- `TabBarView` con dos grids de 5 columnas
- Cada celda muestra el color del boton; al presionar envia la senal IR
- El boton activo muestra un `CircularProgressIndicator` y un borde blanco con glow

---

## android/app/src/main/kotlin/com/example/irphone/MainActivity.kt

Implementa el `MethodChannel` del lado Android.

**Canal:** `com.example.irphone/ir`

**Metodos expuestos:**

| Metodo | Descripcion |
|---|---|
| `hasIrEmitter` | Retorna bool: si el dispositivo tiene emisor IR |
| `sendProntoHex` | Convierte Pronto Hex a raw timings y transmite via `ConsumerIrManager` |

**Conversion Pronto Hex → raw:**
```kotlin
// Pronto Hex format: [0000] [freqWord] [oncePairs] [0000] [pair1...pairN] [gap]
val periodUs = freqWord * 0.241246
val carrierHz = (1_000_000.0 / periodUs).toInt()
val raw = IntArray(oncePairs * 2) { i -> (words[4 + i] * periodUs).toInt() }
irManager.transmit(carrierHz, raw)
```

- La transmision ocurre en un hilo de fondo para no interrumpir la captura de audio
- Los resultados se postean al main thread via `Handler(Looper.getMainLooper())`

---

## Flujo completo de Auto IR

```
Microfono (44100 Hz PCM)
  → _processAudio() cada ~40ms
      → Calcula dB
      → FFT con ventana Hann (N <= 4096)
      → 24 bandas espectrales normalizadas
      → _detectBeatAndSend(dB)
            → EMA del nivel de fondo
            → Compara con threshold dinamico
            → Si es beat y han pasado >300ms:
                  → _dbToColorIndex(dB) → indice 2–18
                  → pixmobSolid[indice].pronto
                  → _sendIr(pronto)
                        → MethodChannel.invokeMethod('sendProntoHex', ...)
                              → MainActivity.kt
                                    → ConsumerIrManager.transmit(carrierHz, raw)
```

---

## Notas importantes

- La app solo funciona en Android con hardware IR (ej: Xiaomi, algunos Samsung)
- `ConsumerIrManager` requiere Android API 19+
- El MethodChannel es compartido entre `main.dart` e `ir_screen.dart`
- La FFT es una implementacion pura en Dart (sin librerias externas)
- `noise_meter` esta en pubspec.yaml pero no se usa en el codigo; puede eliminarse