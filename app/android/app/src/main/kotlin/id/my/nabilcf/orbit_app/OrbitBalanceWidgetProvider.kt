package id.my.nabilcf.orbit_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent

class OrbitBalanceWidgetProvider : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == OrbitWidgetStore.ACTION_TOGGLE_PRIVACY) {
            OrbitWidgetStore.toggleWidgetBalanceMask(context)
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        OrbitWidgetStore.updateBalanceWidgets(context, appWidgetManager, appWidgetIds)
    }
}
