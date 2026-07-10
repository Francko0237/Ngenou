package com.ngenou.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class DailyChallengeWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            try {
                updateDailyChallengeWidget(context, appWidgetManager, appWidgetId)
            } catch (e: Exception) {
                android.util.Log.e("DailyChallengeWidget", "Error updating widget $appWidgetId", e)
            }
        }
    }

    override fun onEnabled(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)
        val ids = appWidgetManager.getAppWidgetIds(
            android.content.ComponentName(context, DailyChallengeWidget::class.java)
        )
        onUpdate(context, appWidgetManager, ids)
    }
}

internal fun updateDailyChallengeWidget(
    context: Context,
    appWidgetManager: AppWidgetManager,
    appWidgetId: Int
) {
    val prefs = HomeWidgetPlugin.getData(context)
    val views = RemoteViews(context.packageName, R.layout.widget_daily_challenge)

    // PendingIntent partagé : tap n'importe où → ouvre la page des défis
    val openIntent = Intent(context, MainActivity::class.java).apply {
        action = "OPEN_DEFIS"
        this.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }
    val piFlags = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
    val openPending = PendingIntent.getActivity(context, 30, openIntent, piFlags)

    views.setOnClickPendingIntent(R.id.widget_challenge_root, openPending)

    // Données
    val count = prefs.getInt("challenge_count", 0)
    val score = prefs.getInt("challenge_score", 0)
    val total = prefs.getInt("challenge_total", 0)

    // Score dans le header (seulement si des défis existent)
    if (total > 0) {
        views.setTextViewText(R.id.widget_challenge_score, "$score/$total")
    } else {
        views.setTextViewText(R.id.widget_challenge_score, "")
    }

    // IDs des lignes et textes
    val rowIds = intArrayOf(
        R.id.widget_challenge_row_0,
        R.id.widget_challenge_row_1,
        R.id.widget_challenge_row_2
    )
    val textIds = intArrayOf(
        R.id.widget_challenge_text_0,
        R.id.widget_challenge_text_1,
        R.id.widget_challenge_text_2
    )
    val dotIds = intArrayOf(
        R.id.widget_challenge_dot_0,
        R.id.widget_challenge_dot_1,
        R.id.widget_challenge_dot_2
    )

    if (count == 0) {
        // Aucun défi : afficher l'état vide, cacher toutes les lignes
        views.setViewVisibility(R.id.widget_empty_state, View.VISIBLE)
        for (rowId in rowIds) {
            views.setViewVisibility(rowId, View.GONE)
        }
    } else {
        views.setViewVisibility(R.id.widget_empty_state, View.GONE)

        for (i in 0..2) {
            val q = prefs.getString("challenge_q_$i", null)
            val answered = prefs.getBoolean("challenge_answered_$i", false)

            if (q != null) {
                views.setViewVisibility(rowIds[i], View.VISIBLE)
                views.setTextViewText(textIds[i], q)
                // Dot vert si répondu, bleu sinon
                views.setInt(
                    dotIds[i], "setBackgroundColor",
                    if (answered) 0xFF22C55E.toInt() else 0xFF3B82F6.toInt()
                )
                // Chaque ligne est cliquable vers les défis
                views.setOnClickPendingIntent(rowIds[i], openPending)
            } else {
                views.setViewVisibility(rowIds[i], View.GONE)
            }
        }
    }

    appWidgetManager.updateAppWidget(appWidgetId, views)
}
