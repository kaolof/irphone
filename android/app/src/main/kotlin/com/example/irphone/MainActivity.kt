package com.example.irphone

import android.content.Context
import android.hardware.ConsumerIrManager
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.example.irphone/ir"
    private val mainHandler = Handler(Looper.getMainLooper())

    // Converts a Pronto Hex string to (carrierHz, raw microsecond timings).
    // Duration in µs = prontoCount * freqWord * 0.241246
    private fun prontoToRaw(pronto: String): Pair<Int, IntArray> {
        val words = pronto.trim().split("\\s+".toRegex()).map { it.toInt(16) }
        val freqWord = words[1]
        val periodUs = freqWord * 0.241246
        val carrierHz = (1_000_000.0 / periodUs).toInt()
        val oncePairs = words[2]
        val raw = IntArray(oncePairs * 2) { i -> (words[4 + i] * periodUs).toInt() }
        return Pair(carrierHz, raw)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                val irManager = getSystemService(Context.CONSUMER_IR_SERVICE) as? ConsumerIrManager

                when (call.method) {
                    "hasIrEmitter" -> {
                        result.success(irManager?.hasIrEmitter() ?: false)
                    }
                    "sendProntoHex" -> {
                        if (irManager == null || !irManager.hasIrEmitter()) {
                            result.error("NO_IR", "Este dispositivo no tiene emisor IR", null)
                            return@setMethodCallHandler
                        }
                        val pronto = call.argument<String>("pronto")
                        if (pronto == null) {
                            result.error("INVALID_ARG", "Falta el argumento pronto", null)
                            return@setMethodCallHandler
                        }
                        // Run transmit on a background thread so audio capture is not interrupted
                        Thread {
                            try {
                                val (carrierHz, raw) = prontoToRaw(pronto)
                                irManager.transmit(carrierHz, raw)
                                mainHandler.post { result.success(true) }
                            } catch (e: Exception) {
                                mainHandler.post { result.error("IR_ERROR", e.message, null) }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            }
    }
}