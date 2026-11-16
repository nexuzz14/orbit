package id.my.nabilcf.orbit_app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

object OrbitWidgetStore {
    private const val PREFS_NAME = "orbit_widget_prefs"
    private const val KEY_DATE_WIB = "dateLabelWib"
    private const val KEY_UPDATED_WIB = "updatedAtLabelWib"
    private const val KEY_PRIVACY_MASKED = "privacyMasked"
    private const val KEY_BALANCE_TEXT = "balanceDisplayText"
    private const val KEY_ACTIVE_TASK_COUNT = "activeTaskCount"
    private const val KEY_TODAY_ITEMS_JSON = "todayItemsJson"
    private const val KEY_PRIORITY_TASKS_JSON = "priorityTasksJson"

    private const val MASKED_PLACEHOLDER = "Rp \u2022\u2022\u2022\u2022\u2022\u2022"

    fun saveSnapshot(context: Context, payload: Map<String, Any?>) {
        val masked = (payload["privacyMasked"] as? Boolean) ?: true
        val safeBalance = if (masked) {
            MASKED_PLACEHOLDER
        } else {
            (payload["balanceDisplayText"] as? String)?.takeIf { it.isNotBlank() }
                ?: MASKED_PLACEHOLDER
        }

        val activeCount = when (val raw = payload["activeTaskCount"]) {
            is Int -> raw
            is Number -> raw.toInt()
            else -> 0
        }

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(KEY_DATE_WIB, (payload["dateLabelWib"] as? String) ?: defaultWibDate())
            .putString(KEY_UPDATED_WIB, (payload["updatedAtLabelWib"] as? String) ?: "")
            .putBoolean(KEY_PRIVACY_MASKED, masked)
            .putString(KEY_BALANCE_TEXT, safeBalance)
            .putInt(KEY_ACTIVE_TASK_COUNT, activeCount)
            .putString(KEY_TODAY_ITEMS_JSON, (payload["todayItemsJson"] as? String) ?: "[]")
            .putString(KEY_PRIORITY_TASKS_JSON, (payload["priorityTasksJson"] as? String) ?: "[]")
            .apply()

        updateAllWidgets(context)
    }

    fun updateAllWidgets(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val todayIds = manager.getAppWidgetIds(
            ComponentName(context, OrbitTodayWidgetProvider::class.java)
        )
        if (todayIds.isNotEmpty()) updateTodayWidgets(context, manager, todayIds)

        val taskIds = manager.getAppWidgetIds(
            ComponentName(context, OrbitTasksWidgetProvider::class.java)
        )
        if (taskIds.isNotEmpty()) updateTasksWidgets(context, manager, taskIds)

        val quickIds = manager.getAppWidgetIds(
            ComponentName(context, OrbitQuickAddWidgetProvider::class.java)
        )
        if (quickIds.isNotEmpty()) updateQuickAddWidgets(context, manager, quickIds)

        val balanceIds = manager.getAppWidgetIds(
            ComponentName(context, OrbitBalanceWidgetProvider::class.java)
        )
        if (balanceIds.isNotEmpty()) updateBalanceWidgets(context, manager, balanceIds)
    }

    fun updateTodayWidgets(context: Context, manager: AppWidgetManager, widgetIds: IntArray) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val dateLabel = prefs.getString(KEY_DATE_WIB, defaultWibDate()) ?: defaultWibDate()
        val itemsJson = prefs.getString(KEY_TODAY_ITEMS_JSON, "[]") ?: "[]"
        val array = runCatching { JSONArray(itemsJson) }.getOrNull() ?: JSONArray()

        val rowIds = listOf(
            Triple(R.id.widget_today_row_1, R.id.widget_today_item_1_title, R.id.widget_today_item_1_time),
            Triple(R.id.widget_today_row_2, R.id.widget_today_item_2_title, R.id.widget_today_item_2_time),
            Triple(R.id.widget_today_row_3, R.id.widget_today_item_3_title, R.id.widget_today_item_3_time)
        )

        for (id in widgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_today)
            views.setTextViewText(R.id.widget_today_date, dateLabel)

            if (array.length() == 0) {
                views.setViewVisibility(R.id.widget_today_empty, View.VISIBLE)
                for (row in rowIds) {
                    views.setViewVisibility(row.first, View.GONE)
                }
            } else {
                views.setViewVisibility(R.id.widget_today_empty, View.GONE)
                for (index in rowIds.indices) {
                    val triple = rowIds[index]
                    if (index < array.length()) {
                        val obj = array.optJSONObject(index)
                        val title = obj?.optString("title", "") ?: ""
                        val time = obj?.optString("timeLabel", "") ?: ""
                        views.setViewVisibility(triple.first, View.VISIBLE)
                        views.setTextViewText(triple.second, title)
                        views.setTextViewText(triple.third, time)
                    } else {
                        views.setViewVisibility(triple.first, View.GONE)
                    }
                }
            }

            views.setOnClickPendingIntent(R.id.widget_today_root, openAppPendingIntent(context, 100))
            manager.updateAppWidget(id, views)
        }
    }

    fun updateTasksWidgets(context: Context, manager: AppWidgetManager, widgetIds: IntArray) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val count = prefs.getInt(KEY_ACTIVE_TASK_COUNT, 0)
        val tasksJson = prefs.getString(KEY_PRIORITY_TASKS_JSON, "[]") ?: "[]"
        val array = runCatching { JSONArray(tasksJson) }.getOrNull() ?: JSONArray()
        val lineIds = listOf(R.id.widget_tasks_item_1, R.id.widget_tasks_item_2, R.id.widget_tasks_item_3)

        for (id in widgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_tasks)
            views.setTextViewText(R.id.widget_tasks_count, count.toString())

            if (array.length() == 0) {
                views.setViewVisibility(R.id.widget_tasks_empty, View.VISIBLE)
                for (lineId in lineIds) {
                    views.setViewVisibility(lineId, View.GONE)
                }
            } else {
                views.setViewVisibility(R.id.widget_tasks_empty, View.GONE)
                for (index in lineIds.indices) {
                    val lineId = lineIds[index]
                    if (index < array.length()) {
                        val obj = array.optJSONObject(index)
                        val title = obj?.optString("title", "") ?: ""
                        val due = obj?.optString("dueLabel", "") ?: ""
                        val text = if (due.isNotBlank()) "$title ($due)" else title
                        views.setViewVisibility(lineId, View.VISIBLE)
                        views.setTextViewText(lineId, text)
                    } else {
                        views.setViewVisibility(lineId, View.GONE)
                    }
                }
            }

            views.setOnClickPendingIntent(R.id.widget_tasks_root, openAppPendingIntent(context, 200))
            manager.updateAppWidget(id, views)
        }
    }

    fun updateQuickAddWidgets(context: Context, manager: AppWidgetManager, widgetIds: IntArray) {
        for (id in widgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_quick_add)
            views.setOnClickPendingIntent(
                R.id.widget_btn_add_transaction,
                quickAddPendingIntent(context, "transaction", 301)
            )
            views.setOnClickPendingIntent(
                R.id.widget_btn_add_task,
                quickAddPendingIntent(context, "task", 302)
            )
            views.setOnClickPendingIntent(
                R.id.widget_btn_add_receipt,
                quickAddPendingIntent(context, "receipt", 303)
            )
            manager.updateAppWidget(id, views)
        }
    }

    fun updateBalanceWidgets(context: Context, manager: AppWidgetManager, widgetIds: IntArray) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val masked = prefs.getBoolean(KEY_PRIVACY_MASKED, true)
        val balanceText = if (masked) {
            MASKED_PLACEHOLDER
        } else {
            prefs.getString(KEY_BALANCE_TEXT, MASKED_PLACEHOLDER) ?: MASKED_PLACEHOLDER
        }

        for (id in widgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_balance)
            views.setTextViewText(R.id.widget_balance_amount, balanceText)
            views.setViewVisibility(
                R.id.widget_balance_privacy_tag,
                if (masked) View.VISIBLE else View.GONE
            )
            views.setOnClickPendingIntent(R.id.widget_balance_root, openAppPendingIntent(context, 400))
            manager.updateAppWidget(id, views)
        }
    }

    private fun openAppPendingIntent(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun quickAddPendingIntent(context: Context, type: String, requestCode: Int): PendingIntent {
        val uri = Uri.parse("io.supabase.orbit://quick-add?type=$type")
        val intent = Intent(Intent.ACTION_VIEW, uri, context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun defaultWibDate(): String {
        val sdf = SimpleDateFormat("EEE, dd MMM", Locale("id", "ID"))
        sdf.timeZone = TimeZone.getTimeZone("Asia/Jakarta")
        return sdf.format(Date())
    }
}
