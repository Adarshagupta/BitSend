package com.bitsend.app.bitsend

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context

class BitsendQuickActionsWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        BitsendWidgetBridge.updateQuickActionWidgets(
            context = context,
            manager = appWidgetManager,
            widgetIds = appWidgetIds,
        )
    }
}
