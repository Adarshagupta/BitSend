package com.bitsend.app.bitsend

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var pendingLaunchRoute: String? = null
    private var widgetChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        widgetChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BitsendWidgetBridge.channelName,
        ).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "syncWidgets" -> {
                        val payload = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
                        BitsendWidgetBridge.syncWidgets(this@MainActivity, payload)
                        result.success(null)
                    }

                    "consumeLaunchRoute" -> {
                        result.success(pendingLaunchRoute)
                        pendingLaunchRoute = null
                    }

                    else -> result.notImplemented()
                }
            }
        }
        captureLaunchRoute(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureLaunchRoute(intent)
        deliverPendingLaunchRoute()
    }

    private fun captureLaunchRoute(intent: Intent?) {
        val route = intent?.getStringExtra(BitsendWidgetBridge.widgetRouteExtra)
        if (route.isNullOrBlank()) {
            return
        }
        pendingLaunchRoute = route
    }

    private fun deliverPendingLaunchRoute() {
        val route = pendingLaunchRoute ?: return
        val channel = widgetChannel ?: return
        channel.invokeMethod("widgetLaunchRoute", route)
        pendingLaunchRoute = null
    }
}
