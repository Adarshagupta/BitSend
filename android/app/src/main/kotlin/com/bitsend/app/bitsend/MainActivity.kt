package com.bitsend.app.bitsend

import android.graphics.Bitmap
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.contract.ActivityResultContracts
import java.io.ByteArrayOutputStream

class MainActivity : FlutterFragmentActivity() {
    private var pairCaptureResult: MethodChannel.Result? = null
    private lateinit var pairCaptureLauncher: ActivityResultLauncher<Void?>

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        pairCaptureLauncher = registerForActivityResult(
            ActivityResultContracts.TakePicturePreview()
        ) { bitmap: Bitmap? ->
            val pendingResult = pairCaptureResult ?: return@registerForActivityResult
            pairCaptureResult = null

            if (bitmap == null) {
                pendingResult.error(
                    "capture_cancelled",
                    "The pair photo capture was cancelled.",
                    null
                )
                return@registerForActivityResult
            }

            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            pendingResult.success(stream.toByteArray())
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "bitsend/pair_camera"
        ).setMethodCallHandler { call: MethodCall, result: MethodChannel.Result ->
            when (call.method) {
                "capturePreview" -> {
                    if (pairCaptureResult != null) {
                        result.error(
                            "capture_in_progress",
                            "A pair photo capture is already running.",
                            null
                        )
                        return@setMethodCallHandler
                    }
                    pairCaptureResult = result
                    pairCaptureLauncher.launch(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
