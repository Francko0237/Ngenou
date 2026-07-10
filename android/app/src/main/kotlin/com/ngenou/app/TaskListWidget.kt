package com.ngenou.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class TaskListWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            try {
                updateTaskListWidget(context, appWidgetManager, appWidgetId)
            } catch (e: Exception) {
                // Ne jamais laisser une exception remonter depuis onUpdate —
                // Android afficherait "Impossible de charger le widget"
                android.util.Log.e("TaskListWidget", "Error updating widget $appWidgetId", e)
            }
        }
    }

    override fun onEnabled(context: Context) {
        // Premier widget posé sur le bureau
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val ids = appWidgetManager.getAppWidgetIds(
            android.content.ComponentName(context, TaskListWidget::class.java)
        )
        onUpdate(context, appWidgetManager, ids)
    }
}

internal fun updateTaskListWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int
) {
    // Lecture des SharedPreferences écrites par Flutter via home_widget
    val prefs = HomeWidgetPlugin.getData(context)

    val views = RemoteViews(context.packageName, R.layout.widget_task_list)

    // --- PendingIntent : tap ouvre l'app sur /taches ---
    val openIntent = Intent(context, MainActivity::class.java).apply {
        action = "OPEN_TASKS"
        this.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }
    val flags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    val openPending = PendingIntent.getActivity(context, 10, openIntent, flags)
    views.setOnClickPendingIntent(R.id.widget_root, openPending)

    // --- PendingIntent : tap sur bouton plus ouvre le sheet d'ajout ---
    val addIntent = Intent(context, MainActivity::class.java).apply {
        action = "ADD_TASK"
        this.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }
    val addPending = PendingIntent.getActivity(context, 11, addIntent, flags)
    views.setOnClickPendingIntent(R.id.widget_add_button, addPending)

    // --- Données ---
    val date      = prefs.getString("widget_date", "Aujourd'hui") ?: "Aujourd'hui"
    val taskCount = prefs.getInt("widget_task_count", 0)
    val doneCount = prefs.getInt("widget_done_count", 0)

    views.setTextViewText(R.id.widget_date, date)
    views.setTextViewText(R.id.widget_count, "$doneCount/$taskCount")

    // --- Lignes de taches ---
    data class TaskRow(val rowId: Int, val titleId: Int, val timeId: Int)
    val rows = listOf(
        TaskRow(R.id.task_row_1, R.id.task_title_1, R.id.task_time_1),
        TaskRow(R.id.task_row_2, R.id.task_title_2, R.id.task_time_2),
        TaskRow(R.id.task_row_3, R.id.task_title_3, R.id.task_time_3),
    )

    var visibleCount = 0
    for (i in rows.indices) {
        val title = prefs.getString("widget_task_title_$i", null)
        if (!title.isNullOrBlank()) {
            val time = prefs.getString("widget_task_time_$i", "") ?: ""
            views.setViewVisibility(rows[i].rowId, View.VISIBLE)
            views.setTextViewText(rows[i].titleId, title)
            views.setTextViewText(rows[i].timeId, time)
            visibleCount++
        } else {
            views.setViewVisibility(rows[i].rowId, View.GONE)
        }
    }

    // --- Etat vide / indicateur "plus" ---
    if (visibleCount == 0) {
        views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
        views.setViewVisibility(R.id.widget_more, View.GONE)
    } else {
        views.setViewVisibility(R.id.widget_empty, View.GONE)
        val remaining = taskCount - visibleCount
        if (remaining > 0) {
            views.setViewVisibility(R.id.widget_more, View.VISIBLE)
            val plural = if (remaining > 1) "s" else ""
            views.setTextViewText(R.id.widget_more, "+ $remaining autre$plural...")
        } else {
            views.setViewVisibility(R.id.widget_more, View.GONE)
        }
    }

    appWidgetManager.updateAppWidget(appWidgetId, views)
}
