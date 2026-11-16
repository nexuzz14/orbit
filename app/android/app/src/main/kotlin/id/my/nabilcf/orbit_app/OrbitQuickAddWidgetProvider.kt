package id.my.nabilcf.orbit_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context

class OrbitQuickAddWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        OrbitWidgetStore.updateQuickAddWidgets(context, appWidgetManager, appWidgetIds)
    }
}
