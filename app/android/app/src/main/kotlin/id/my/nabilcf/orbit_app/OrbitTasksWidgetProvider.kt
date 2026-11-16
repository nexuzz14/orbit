package id.my.nabilcf.orbit_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent

class OrbitTasksWidgetProvider : AppWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == OrbitWidgetStore.ACTION_COMPLETE_TASK) {
            val taskId = intent.getStringExtra(OrbitWidgetStore.EXTRA_TASK_ID).orEmpty()
            if (taskId.isNotBlank()) {
                OrbitWidgetStore.completeTaskFromWidget(context, taskId)
            }
        }
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        OrbitWidgetStore.updateTasksWidgets(context, appWidgetManager, appWidgetIds)
    }
}
