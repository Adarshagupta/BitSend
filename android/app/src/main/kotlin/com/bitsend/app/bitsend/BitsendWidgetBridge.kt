package com.bitsend.app.bitsend

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews

internal object BitsendWidgetBridge {
    const val channelName = "bitsend/home_widget"
    const val widgetRouteExtra = "bitsend_widget_route"

    private const val prefsName = "bitsend_home_widget"
    private const val launchAction = "com.bitsend.app.bitsend.OPEN_FROM_WIDGET"

    private const val keyChainLabel = "chainLabel"
    private const val keyNetworkLabel = "networkLabel"
    private const val keyPrimaryValue = "primaryValue"
    private const val keySupportingLabel = "supportingLabel"
    private const val keyPrimaryDetail = "primaryDetail"
    private const val keySecondaryDetail = "secondaryDetail"
    private const val keyStatusLabel = "statusLabel"
    private const val keyStatusTone = "statusTone"
    private const val keyWalletLabel = "walletLabel"

    private const val routeHome = "/home"
    private const val routeAssets = "/assets"
    private const val routeSend = "/send/transport"
    private const val routeReceive = "/receive/listen"
    private const val routeOffline = "/prepare"

    fun syncWidgets(context: Context, payload: Map<*, *>) {
        val preferences = context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
        preferences.edit()
            .putString(keyChainLabel, payload[keyChainLabel].asText("Bitsend"))
            .putString(keyNetworkLabel, payload[keyNetworkLabel].asText("Wallet"))
            .putString(keyPrimaryValue, payload[keyPrimaryValue].asText("$0.00"))
            .putString(
                keySupportingLabel,
                payload[keySupportingLabel].asText("Open Bitsend to load balances"),
            )
            .putString(keyPrimaryDetail, payload[keyPrimaryDetail].asText("Main --"))
            .putString(keySecondaryDetail, payload[keySecondaryDetail].asText("Offline --"))
            .putString(keyStatusLabel, payload[keyStatusLabel].asText("Set up"))
            .putString(keyStatusTone, payload[keyStatusTone].asText("muted"))
            .putString(
                keyWalletLabel,
                payload[keyWalletLabel].asText("Open Bitsend to finish setup"),
            )
            .apply()
        updateAllWidgets(context)
    }

    fun updateAllWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        updateBalanceWidgets(
            context = context,
            manager = manager,
            widgetIds = manager.getAppWidgetIds(
                ComponentName(context, BitsendBalanceWidgetProvider::class.java),
            ),
        )
        updateQuickActionWidgets(
            context = context,
            manager = manager,
            widgetIds = manager.getAppWidgetIds(
                ComponentName(context, BitsendQuickActionsWidgetProvider::class.java),
            ),
        )
    }

    fun updateBalanceWidgets(
        context: Context,
        manager: AppWidgetManager,
        widgetIds: IntArray,
    ) {
        if (widgetIds.isEmpty()) {
            return
        }
        for (widgetId in widgetIds) {
            manager.updateAppWidget(
                widgetId,
                buildBalanceViews(context = context, widgetId = widgetId),
            )
        }
    }

    fun updateQuickActionWidgets(
        context: Context,
        manager: AppWidgetManager,
        widgetIds: IntArray,
    ) {
        if (widgetIds.isEmpty()) {
            return
        }
        for (widgetId in widgetIds) {
            manager.updateAppWidget(
                widgetId,
                buildQuickActionViews(context = context, widgetId = widgetId),
            )
        }
    }

    private fun buildBalanceViews(
        context: Context,
        widgetId: Int,
    ): RemoteViews {
        val content = WidgetContent.load(context)
        return RemoteViews(context.packageName, R.layout.bitsend_balance_widget).apply {
            setTextViewText(
                R.id.widget_balance_scope,
                "${content.chainLabel} / ${content.networkLabel}",
            )
            setTextViewText(R.id.widget_balance_value, content.primaryValue)
            setTextViewText(R.id.widget_balance_support, content.supportingLabel)
            setTextViewText(R.id.widget_balance_primary_detail, content.primaryDetail)
            setTextViewText(R.id.widget_balance_secondary_detail, content.secondaryDetail)
            setTextViewText(R.id.widget_balance_wallet, content.walletLabel)
            setTextViewText(R.id.widget_balance_status, content.statusLabel)
            applyStatusStyle(
                views = this,
                viewId = R.id.widget_balance_status,
                tone = content.statusTone,
            )
            setOnClickPendingIntent(
                R.id.widget_balance_root,
                launchPendingIntent(context = context, route = routeHome, requestCode = widgetId),
            )
        }
    }

    private fun buildQuickActionViews(
        context: Context,
        widgetId: Int,
    ): RemoteViews {
        val content = WidgetContent.load(context)
        return RemoteViews(context.packageName, R.layout.bitsend_quick_actions_widget).apply {
            setTextViewText(
                R.id.widget_quick_scope,
                "${content.chainLabel} / ${content.networkLabel}",
            )
            setTextViewText(R.id.widget_quick_value, content.primaryValue)
            setTextViewText(R.id.widget_quick_support, content.supportingLabel)
            setTextViewText(R.id.widget_quick_primary_detail, content.primaryDetail)
            setTextViewText(R.id.widget_quick_secondary_detail, content.secondaryDetail)
            setTextViewText(R.id.widget_quick_wallet, content.walletLabel)
            setTextViewText(R.id.widget_quick_status, content.statusLabel)
            applyStatusStyle(
                views = this,
                viewId = R.id.widget_quick_status,
                tone = content.statusTone,
            )
            setOnClickPendingIntent(
                R.id.widget_quick_root,
                launchPendingIntent(
                    context = context,
                    route = routeHome,
                    requestCode = widgetId * 10,
                ),
            )
            setOnClickPendingIntent(
                R.id.widget_action_send,
                launchPendingIntent(
                    context = context,
                    route = routeSend,
                    requestCode = widgetId * 10 + 1,
                ),
            )
            setOnClickPendingIntent(
                R.id.widget_action_receive,
                launchPendingIntent(
                    context = context,
                    route = routeReceive,
                    requestCode = widgetId * 10 + 2,
                ),
            )
            setOnClickPendingIntent(
                R.id.widget_action_assets,
                launchPendingIntent(
                    context = context,
                    route = routeAssets,
                    requestCode = widgetId * 10 + 3,
                ),
            )
            setOnClickPendingIntent(
                R.id.widget_action_offline,
                launchPendingIntent(
                    context = context,
                    route = routeOffline,
                    requestCode = widgetId * 10 + 4,
                ),
            )
        }
    }

    private fun launchPendingIntent(
        context: Context,
        route: String,
        requestCode: Int,
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = launchAction
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(widgetRouteExtra, route)
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun applyStatusStyle(
        views: RemoteViews,
        viewId: Int,
        tone: String,
    ) {
        val background = when (tone) {
            "ready" -> R.drawable.bitsend_widget_chip_ready
            "info" -> R.drawable.bitsend_widget_chip_info
            "warning" -> R.drawable.bitsend_widget_chip_warning
            else -> R.drawable.bitsend_widget_chip_muted
        }
        val textColor = when (tone) {
            "ready" -> Color.parseColor("#0F6B46")
            "info" -> Color.parseColor("#194C9D")
            "warning" -> Color.parseColor("#8A5B06")
            else -> Color.parseColor("#516074")
        }
        views.setInt(viewId, "setBackgroundResource", background)
        views.setTextColor(viewId, textColor)
    }

    private fun Any?.asText(fallback: String): String {
        return when (this) {
            null -> fallback
            is String -> if (isBlank()) fallback else this
            else -> toString()
        }
    }

    private data class WidgetContent(
        val chainLabel: String,
        val networkLabel: String,
        val primaryValue: String,
        val supportingLabel: String,
        val primaryDetail: String,
        val secondaryDetail: String,
        val statusLabel: String,
        val statusTone: String,
        val walletLabel: String,
    ) {
        companion object {
            fun load(context: Context): WidgetContent {
                val preferences =
                    context.getSharedPreferences(prefsName, Context.MODE_PRIVATE)
                return WidgetContent(
                    chainLabel = preferences.getString(keyChainLabel, "Bitsend") ?: "Bitsend",
                    networkLabel =
                        preferences.getString(keyNetworkLabel, "Wallet") ?: "Wallet",
                    primaryValue =
                        preferences.getString(keyPrimaryValue, "$0.00") ?: "$0.00",
                    supportingLabel =
                        preferences.getString(
                            keySupportingLabel,
                            "Open Bitsend to load balances",
                        ) ?: "Open Bitsend to load balances",
                    primaryDetail =
                        preferences.getString(keyPrimaryDetail, "Main --") ?: "Main --",
                    secondaryDetail =
                        preferences.getString(keySecondaryDetail, "Offline --")
                            ?: "Offline --",
                    statusLabel =
                        preferences.getString(keyStatusLabel, "Set up") ?: "Set up",
                    statusTone =
                        preferences.getString(keyStatusTone, "muted") ?: "muted",
                    walletLabel =
                        preferences.getString(
                            keyWalletLabel,
                            "Open Bitsend to finish setup",
                        ) ?: "Open Bitsend to finish setup",
                )
            }
        }
    }
}
