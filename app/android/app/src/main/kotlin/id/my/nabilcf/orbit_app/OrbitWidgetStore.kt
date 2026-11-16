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
    const val ACTION_COMPLETE_TASK = "id.my.nabilcf.orbit_app.ACTION_COMPLETE_TASK"
    const val ACTION_TOGGLE_PRIVACY = "id.my.nabilcf.orbit_app.ACTION_TOGGLE_PRIVACY"
    const val EXTRA_TASK_ID = "extra_task_id"

    private const val PREFS_NAME = "orbit_widget_prefs"
    private const val KEY_DATE_WIB = "dateLabelWib"
    private const val KEY_UPDATED_WIB = "updatedAtLabelWib"
    private const val KEY_PRIVACY_MASKED = "privacyMasked"
    private const val KEY_WIDGET_LOCAL_HIDE = "widgetLocalHide"
    private const val KEY_BALANCE_TEXT = "balanceDisplayText"
    private const val KEY_TODAY_EXPENSE_TEXT = "todayExpenseText"
    private const val KEY_ACCENT_ID = "accentId"
    private const val KEY_ACTIVE_TASK_COUNT = "activeTaskCount"
    private const val KEY_TODAY_EVENT_COUNT = "todayEventCount"
    private const val KEY_ACTIVE_BILL_COUNT = "activeBillCount"
    private const val KEY_TODAY_ITEMS_JSON = "todayItemsJson"
    private const val KEY_PRIORITY_TASKS_JSON = "priorityTasksJson"
    private const val KEY_PENDING_COMPLETED_TASKS = "pendingCompletedTaskIds"

    private const val MASKED_PLACEHOLDER = "Rp \u2022\u2022\u2022\u2022\u2022\u2022"

    fun saveSnapshot(context: Context, payload: Map<String, Any?>) {
        val masked = (payload["privacyMasked"] as? Boolean) ?: true
        val safeBalance = if (masked) {
            MASKED_PLACEHOLDER
        } else {
            (payload["balanceDisplayText"] as? String)?.takeIf { it.isNotBlank() }
                ?: MASKED_PLACEHOLDER
        }
        val safeExpense = if (masked) {
            MASKED_PLACEHOLDER
        } else {
            (payload["todayExpenseText"] as? String)?.takeIf { it.isNotBlank() }
                ?: "Rp 0"
        }

        val activeCount = intFromPayload(payload["activeTaskCount"])
        val eventCount = intFromPayload(payload["todayEventCount"])
        val billCount = intFromPayload(payload["activeBillCount"])
        val accentId = (payload["accentId"] as? String) ?: "ocean"

        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(KEY_DATE_WIB, (payload["dateLabelWib"] as? String) ?: defaultWibDate())
            .putString(KEY_UPDATED_WIB, (payload["updatedAtLabelWib"] as? String) ?: "")
            .putBoolean(KEY_PRIVACY_MASKED, masked)
            .putString(KEY_BALANCE_TEXT, safeBalance)
            .putString(KEY_TODAY_EXPENSE_TEXT, safeExpense)
            .putString(KEY_ACCENT_ID, accentId)
            .putInt(KEY_ACTIVE_TASK_COUNT, activeCount)
            .putInt(KEY_TODAY_EVENT_COUNT, eventCount)
            .putInt(KEY_ACTIVE_BILL_COUNT, billCount)
            .putString(KEY_TODAY_ITEMS_JSON, (payload["todayItemsJson"] as? String) ?: "[]")
            .putString(KEY_PRIORITY_TASKS_JSON, (payload["priorityTasksJson"] as? String) ?: "[]")
            .apply()

        updateAllWidgets(context)
    }

    private fun intFromPayload(raw: Any?): Int = when (raw) {
        is Int -> raw
        is Number -> raw.toInt()
        else -> 0
    }

    fun completeTaskFromWidget(context: Context, taskId: String) {
        if (taskId.isBlank()) return
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        // Tambahkan ke antrean sinkronisasi widget -> Flutter Drift DB
        val pending = prefs.getStringSet(KEY_PENDING_COMPLETED_TASKS, emptySet())?.toMutableSet()
            ?: mutableSetOf()
        pending.add(taskId)

        // Perbarui daftar priorityTasks secara instan agar widget langsung responsif
        val rawArr = runCatching {
            JSONArray(prefs.getString(KEY_PRIORITY_TASKS_JSON, "[]") ?: "[]")
        }.getOrNull() ?: JSONArray()
        val updatedArr = JSONArray()
        var removed = false
        for (i in 0 until rawArr.length()) {
            val obj = rawArr.optJSONObject(i) ?: continue
            if (obj.optString("id") == taskId) {
                removed = true
                continue
            }
            updatedArr.put(obj)
        }
        val currentCount = prefs.getInt(KEY_ACTIVE_TASK_COUNT, 0)
        val nextCount = if (removed && currentCount > 0) currentCount - 1 else currentCount

        prefs.edit()
            .putStringSet(KEY_PENDING_COMPLETED_TASKS, pending)
            .putString(KEY_PRIORITY_TASKS_JSON, updatedArr.toString())
            .putInt(KEY_ACTIVE_TASK_COUNT, nextCount)
            .apply()

        updateAllWidgets(context)
    }

    fun drainPendingCompletedTaskIds(context: Context): List<String> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val pending = prefs.getStringSet(KEY_PENDING_COMPLETED_TASKS, emptySet())?.toList()
            ?: emptyList()
        if (pending.isNotEmpty()) {
            prefs.edit().remove(KEY_PENDING_COMPLETED_TASKS).apply()
        }
        return pending
    }

    fun toggleWidgetBalanceMask(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val appMasked = prefs.getBoolean(KEY_PRIVACY_MASKED, true)
        if (appMasked) {
            // Saldo memang disamarkan dari Mode Privasi aplikasi; buka aplikasi untuk membuka kunci aman
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
            runCatching { context.startActivity(intent) }
            return
        }
        val localHidden = prefs.getBoolean(KEY_WIDGET_LOCAL_HIDE, false)
        prefs.edit().putBoolean(KEY_WIDGET_LOCAL_HIDE, !localHidden).apply()
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

    private fun btnPrimaryDrawable(accentId: String): Int = when (accentId) {
        "emerald" -> R.drawable.orbit_widget_btn_emerald
        "violet" -> R.drawable.orbit_widget_btn_violet
        "amber" -> R.drawable.orbit_widget_btn_amber
        else -> R.drawable.orbit_widget_btn_primary_bg
    }

    private fun chipDrawable(accentId: String): Int = when (accentId) {
        "emerald" -> R.drawable.orbit_widget_chip_emerald
        "violet" -> R.drawable.orbit_widget_chip_violet
        "amber" -> R.drawable.orbit_widget_chip_amber
        else -> R.drawable.orbit_widget_chip_bg
    }

    fun updateTodayWidgets(context: Context, manager: AppWidgetManager, widgetIds: IntArray) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val dateLabel = prefs.getString(KEY_DATE_WIB, defaultWibDate()) ?: defaultWibDate()
        val accentId = prefs.getString(KEY_ACCENT_ID, "ocean") ?: "ocean"
        val taskCount = prefs.getInt(KEY_ACTIVE_TASK_COUNT, 0)
        val eventCount = prefs.getInt(KEY_TODAY_EVENT_COUNT, 0)
        val billCount = prefs.getInt(KEY_ACTIVE_BILL_COUNT, 0)
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
            views.setInt(R.id.widget_today_date, "setBackgroundResource", chipDrawable(accentId))
            views.setInt(R.id.widget_today_add_btn, "setBackgroundResource", btnPrimaryDrawable(accentId))
            views.setTextViewText(
                R.id.widget_today_stats,
                "$taskCount Tugas \u2022 $eventCount Jadwal \u2022 $billCount Tagihan"
            )

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
                        val itemId = obj?.optString("id", "") ?: ""
                        val itemType = obj?.optString("itemType", "event") ?: "event"
                        val title = obj?.optString("title", "") ?: ""
                        val time = obj?.optString("timeLabel", "") ?: ""
                        views.setViewVisibility(triple.first, View.VISIBLE)
                        views.setTextViewText(triple.second, title)
                        views.setTextViewText(triple.third, time)
                        val routeTab = if (itemType == "task" && itemId.isNotBlank()) "task" else "schedule"
                        views.setOnClickPendingIntent(
                            triple.first,
                            openRoutePendingIntent(context, routeTab, itemId, 110 + index)
                        )
                    } else {
                        views.setViewVisibility(triple.first, View.GONE)
                    }
                }
            }

            views.setOnClickPendingIntent(
                R.id.widget_today_add_btn,
                quickAddPendingIntent(context, "task", 150)
            )
            views.setOnClickPendingIntent(R.id.widget_today_root, openAppPendingIntent(context, 100))
            manager.updateAppWidget(id, views)
        }
    }

    fun updateTasksWidgets(context: Context, manager: AppWidgetManager, widgetIds: IntArray) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val count = prefs.getInt(KEY_ACTIVE_TASK_COUNT, 0)
        val accentId = prefs.getString(KEY_ACCENT_ID, "ocean") ?: "ocean"
        val tasksJson = prefs.getString(KEY_PRIORITY_TASKS_JSON, "[]") ?: "[]"
        val array = runCatching { JSONArray(tasksJson) }.getOrNull() ?: JSONArray()

        val rowSpecs = listOf(
            Triple(R.id.widget_tasks_row_1, R.id.widget_tasks_check_1, R.id.widget_tasks_item_1),
            Triple(R.id.widget_tasks_row_2, R.id.widget_tasks_check_2, R.id.widget_tasks_item_2),
            Triple(R.id.widget_tasks_row_3, R.id.widget_tasks_check_3, R.id.widget_tasks_item_3)
        )

        for (id in widgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_tasks)
            views.setTextViewText(R.id.widget_tasks_count, count.toString())
            views.setInt(R.id.widget_tasks_count, "setBackgroundResource", chipDrawable(accentId))
            views.setInt(R.id.widget_tasks_add_btn, "setBackgroundResource", btnPrimaryDrawable(accentId))

            if (array.length() == 0) {
                views.setViewVisibility(R.id.widget_tasks_empty, View.VISIBLE)
                for (row in rowSpecs) {
                    views.setViewVisibility(row.first, View.GONE)
                }
            } else {
                views.setViewVisibility(R.id.widget_tasks_empty, View.GONE)
                for (index in rowSpecs.indices) {
                    val spec = rowSpecs[index]
                    if (index < array.length()) {
                        val obj = array.optJSONObject(index)
                        val taskId = obj?.optString("id", "") ?: ""
                        val title = obj?.optString("title", "") ?: ""
                        val due = obj?.optString("dueLabel", "") ?: ""
                        val text = if (due.isNotBlank()) "$title ($due)" else title
                        views.setViewVisibility(spec.first, View.VISIBLE)
                        views.setTextViewText(spec.third, text)
                        views.setOnClickPendingIntent(
                            spec.second,
                            completeTaskPendingIntent(context, taskId, 220 + index)
                        )
                        views.setOnClickPendingIntent(
                            spec.third,
                            openRoutePendingIntent(context, "task", taskId, 240 + index)
                        )
                    } else {
                        views.setViewVisibility(spec.first, View.GONE)
                    }
                }
            }

            views.setOnClickPendingIntent(
                R.id.widget_tasks_add_btn,
                quickAddPendingIntent(context, "task", 250)
            )
            views.setOnClickPendingIntent(R.id.widget_tasks_root, openRoutePendingIntent(context, "tasks", "", 200))
            manager.updateAppWidget(id, views)
        }
    }

    fun updateQuickAddWidgets(context: Context, manager: AppWidgetManager, widgetIds: IntArray) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val accentId = prefs.getString(KEY_ACCENT_ID, "ocean") ?: "ocean"

        for (id in widgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_quick_add)
            views.setInt(R.id.widget_btn_add_transaction, "setBackgroundResource", btnPrimaryDrawable(accentId))
            views.setOnClickPendingIntent(
                R.id.widget_btn_add_transaction,
                quickAddPendingIntent(context, "transaction", 301)
            )
            views.setOnClickPendingIntent(
                R.id.widget_btn_add_task,
                quickAddPendingIntent(context, "task", 302)
            )
            views.setOnClickPendingIntent(
                R.id.widget_btn_add_event,
                quickAddPendingIntent(context, "event", 304)
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
        val appMasked = prefs.getBoolean(KEY_PRIVACY_MASKED, true)
        val localHidden = prefs.getBoolean(KEY_WIDGET_LOCAL_HIDE, false)
        val effectiveMasked = appMasked || localHidden
        val accentId = prefs.getString(KEY_ACCENT_ID, "ocean") ?: "ocean"
        val billCount = prefs.getInt(KEY_ACTIVE_BILL_COUNT, 0)

        val balanceText = if (effectiveMasked) {
            MASKED_PLACEHOLDER
        } else {
            prefs.getString(KEY_BALANCE_TEXT, MASKED_PLACEHOLDER) ?: MASKED_PLACEHOLDER
        }
        val expenseText = if (effectiveMasked) {
            MASKED_PLACEHOLDER
        } else {
            prefs.getString(KEY_TODAY_EXPENSE_TEXT, "Rp 0") ?: "Rp 0"
        }

        for (id in widgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_balance)
            views.setTextViewText(R.id.widget_balance_amount, balanceText)
            views.setTextViewText(
                R.id.widget_balance_privacy_tag,
                if (effectiveMasked) "Tampilkan" else "Sembunyi"
            )
            views.setTextViewText(
                R.id.widget_balance_meta,
                "Keluar: $expenseText \u2022 $billCount Tagihan"
            )
            views.setInt(R.id.widget_balance_privacy_tag, "setBackgroundResource", chipDrawable(accentId))
            views.setInt(R.id.widget_balance_add_btn, "setBackgroundResource", btnPrimaryDrawable(accentId))

            views.setOnClickPendingIntent(
                R.id.widget_balance_privacy_tag,
                togglePrivacyPendingIntent(context, 410)
            )
            views.setOnClickPendingIntent(
                R.id.widget_balance_add_btn,
                quickAddPendingIntent(context, "transaction", 411)
            )
            views.setOnClickPendingIntent(
                R.id.widget_balance_root,
                openRoutePendingIntent(context, "finance", "", 400)
            )
            manager.updateAppWidget(id, views)
        }
    }

    private fun completeTaskPendingIntent(context: Context, taskId: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, OrbitTasksWidgetProvider::class.java).apply {
            action = ACTION_COMPLETE_TASK
            putExtra(EXTRA_TASK_ID, taskId)
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    private fun togglePrivacyPendingIntent(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, OrbitBalanceWidgetProvider::class.java).apply {
            action = ACTION_TOGGLE_PRIVACY
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
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

    private fun openRoutePendingIntent(
        context: Context,
        tab: String,
        entityId: String,
        requestCode: Int
    ): PendingIntent {
        val uri = Uri.Builder()
            .scheme("io.supabase.orbit")
            .authority("open")
            .appendQueryParameter("tab", tab)
            .apply {
                if (entityId.isNotBlank()) appendQueryParameter("id", entityId)
            }
            .build()
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
