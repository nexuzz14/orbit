package id.my.nabilcf.orbit_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context

class OrbitTasksWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        OrbitWidgetStore.updateTasksWidgets(context, appWidgetManager, appWidgetIds)
    }
}
