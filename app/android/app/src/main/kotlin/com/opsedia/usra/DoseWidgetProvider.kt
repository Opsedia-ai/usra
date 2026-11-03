package com.opsedia.usra

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.io.File
import java.util.Calendar
import org.json.JSONObject

/**
 * Home-screen widget: the next three doses today across the family.
 *
 * The database is encrypted, so the widget never reads it: the app hands
 * it a small snapshot (first names, medicine names, times; see
 * `dose_widget.dart`) of the doses due today and tomorrow. The widget
 * picks the next three as time passes, re-drawing itself when a dose
 * comes due or drops off, at midnight, after a reboot and when the clock
 * changes. Taken writes to the same inbox as the notification's Taken
 * button; the app saves it to the database when it next runs.
 */
class DoseWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        render(context, appWidgetManager, appWidgetIds, widgetData)
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_TAKEN -> {
                val medicineId = intent.getStringExtra(EXTRA_MEDICINE) ?: return
                val at = intent.getLongExtra(EXTRA_AT, -1)
                if (at < 0) return
                markTaken(context, medicineId, at)
                refresh(context)
            }
            ACTION_REFRESH,
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            Intent.ACTION_LOCALE_CHANGED -> refresh(context)
            else -> super.onReceive(context, intent)
        }
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        alarms(context).cancel(refreshIntent(context))
    }

    companion object {
        private const val ACTION_TAKEN = "com.opsedia.usra.widget.TAKEN"
        private const val ACTION_REFRESH = "com.opsedia.usra.widget.REFRESH"
        private const val EXTRA_MEDICINE = "m"
        private const val EXTRA_AT = "at"

        /** Written by the app; see `HomeWidgetSnapshotPublisher.dataKey`. */
        private const val DATA_KEY = "dose_widget_snapshot"

        /** Read by `DoseActionInbox` in the app. */
        private const val INBOX_FILE = "dose_actions.jsonl"

        /** Doses marked Taken here that the app hasn't saved yet. */
        private const val TAKEN_PREFS = "DoseWidgetTaken"

        private const val SHOWN = 3
        private const val DAY_MS = 24 * 60 * 60 * 1000L

        private val rows = intArrayOf(R.id.dose_row_1, R.id.dose_row_2, R.id.dose_row_3)
        private val texts = intArrayOf(R.id.dose_text_1, R.id.dose_text_2, R.id.dose_text_3)
        private val buttons =
            intArrayOf(R.id.dose_taken_1, R.id.dose_taken_2, R.id.dose_taken_3)

        private class Dose(
            val at: Long,
            val until: Long,
            val time: String,
            val person: String,
            val medicine: String,
            val medicineId: String,
        )

        private class Snapshot(
            val generatedAt: Long,
            val validUntil: Long,
            val rtl: Boolean,
            val title: String?,
            val empty: String?,
            val stale: String?,
            val taken: String?,
            val doses: List<Dose>,
        )

        /** Re-draws every instance of the widget. */
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, DoseWidgetProvider::class.java))
            render(context, manager, ids, HomeWidgetPlugin.getData(context))
        }

        private fun render(
            context: Context,
            manager: AppWidgetManager,
            ids: IntArray,
            widgetData: SharedPreferences,
        ) {
            if (ids.isEmpty()) return
            val now = System.currentTimeMillis()
            val snapshot = read(widgetData.getString(DATA_KEY, null))
            val taken = pendingTaken(context, snapshot)
            val views = RemoteViews(context.packageName, R.layout.dose_widget)

            views.setInt(
                R.id.dose_widget_root,
                "setLayoutDirection",
                // Before the first snapshot, the phone's own direction.
                when (snapshot?.rtl) {
                    true -> View.LAYOUT_DIRECTION_RTL
                    false -> View.LAYOUT_DIRECTION_LTR
                    null -> context.resources.configuration.layoutDirection
                },
            )
            views.setTextViewText(
                R.id.dose_widget_title,
                snapshot?.title ?: context.getString(R.string.dose_widget_name),
            )
            // The whole widget opens the Medicines tab.
            views.setOnClickPendingIntent(
                R.id.dose_widget_root,
                HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("usra://widget/medicines?homeWidget"),
                ),
            )

            val todayEnd = startOfDay(now) + DAY_MS
            val stale = snapshot == null || now >= snapshot.validUntil
            val due = if (stale) emptyList() else snapshot!!.doses.filter {
                it.until >= now && it.at < todayEnd &&
                    !taken.contains(key(it.medicineId, it.at))
            }.take(SHOWN)

            for (i in 0 until SHOWN) {
                val dose = due.getOrNull(i)
                if (dose == null) {
                    views.setViewVisibility(rows[i], View.GONE)
                    continue
                }
                views.setViewVisibility(rows[i], View.VISIBLE)
                views.setTextViewText(texts[i], "${dose.time} · ${dose.person} · ${dose.medicine}")
                // Only doses already due: a later one still has its
                // reminder coming, which Taken here can't cancel.
                if (dose.at <= now) {
                    views.setViewVisibility(buttons[i], View.VISIBLE)
                    views.setTextViewText(
                        buttons[i],
                        snapshot!!.taken ?: context.getString(R.string.dose_widget_taken),
                    )
                    views.setOnClickPendingIntent(buttons[i], takenIntent(context, dose, i))
                } else {
                    views.setViewVisibility(buttons[i], View.GONE)
                }
            }
            val message = when {
                due.isNotEmpty() -> null
                stale -> snapshot?.stale ?: context.getString(R.string.dose_widget_stale)
                else -> snapshot!!.empty ?: context.getString(R.string.dose_widget_empty)
            }
            views.setViewVisibility(R.id.dose_widget_empty, if (message == null) View.GONE else View.VISIBLE)
            views.setTextViewText(R.id.dose_widget_empty, message ?: "")

            manager.updateAppWidget(ids, views)
            scheduleNext(context, now, todayEnd, snapshot)
        }

        /** Re-draws when the next dose comes due or drops off, or at midnight. */
        private fun scheduleNext(context: Context, now: Long, todayEnd: Long, snapshot: Snapshot?) {
            var next = todayEnd
            if (snapshot != null) {
                if (snapshot.validUntil in (now + 1) until next) next = snapshot.validUntil
                for (dose in snapshot.doses) {
                    for (t in longArrayOf(dose.at, dose.until + 1)) {
                        if (t in (now + 1) until next) next = t
                    }
                }
            }
            // Inexact, so no exact-alarm permission, but allowed while
            // idle: Doze would otherwise hold yesterday's doses past midnight.
            alarms(context).setAndAllowWhileIdle(AlarmManager.RTC, next, refreshIntent(context))
        }

        private fun alarms(context: Context) =
            context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        private fun refreshIntent(context: Context): PendingIntent = PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, DoseWidgetProvider::class.java).setAction(ACTION_REFRESH),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        private fun takenIntent(context: Context, dose: Dose, row: Int): PendingIntent =
            PendingIntent.getBroadcast(
                context,
                1 + row,
                Intent(context, DoseWidgetProvider::class.java)
                    .setAction(ACTION_TAKEN)
                    .putExtra(EXTRA_MEDICINE, dose.medicineId)
                    .putExtra(EXTRA_AT, dose.at),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        /** Leaves the dose for the app, as the notification's Taken does. */
        private fun markTaken(context: Context, medicineId: String, at: Long) {
            val now = System.currentTimeMillis()
            val line = JSONObject()
                .put("m", medicineId)
                .put("s", at)
                .put("st", "taken")
                .put("at", now)
                .toString()
            try {
                File(context.filesDir, INBOX_FILE).appendText(line + "\n")
            } catch (e: Exception) {
                // Nothing saved: leave the dose showing.
                return
            }
            context.getSharedPreferences(TAKEN_PREFS, Context.MODE_PRIVATE)
                .edit()
                .putLong(key(medicineId, at), now)
                .apply()
        }

        /**
         * Doses marked Taken here and not yet in a snapshot. Forgets the ones
         * the app has since saved (a snapshot read after the tap) and old ones.
         */
        private fun pendingTaken(context: Context, snapshot: Snapshot?): Set<String> {
            val prefs = context.getSharedPreferences(TAKEN_PREFS, Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            val keep = mutableSetOf<String>()
            val edit = prefs.edit()
            for ((k, v) in prefs.all) {
                val tappedAt = v as? Long
                if (tappedAt == null || tappedAt < now - 2 * DAY_MS ||
                    (snapshot != null && snapshot.generatedAt > tappedAt)
                ) {
                    edit.remove(k)
                } else {
                    keep.add(k)
                }
            }
            edit.apply()
            return keep
        }

        private fun key(medicineId: String, at: Long) = "$medicineId@$at"

        private fun startOfDay(now: Long): Long = Calendar.getInstance().apply {
            timeInMillis = now
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis

        private fun read(raw: String?): Snapshot? {
            if (raw == null) return null
            return try {
                val j = JSONObject(raw)
                if (j.optInt("v") != 1) return null
                val list = j.getJSONArray("doses")
                Snapshot(
                    generatedAt = j.getLong("generatedAt"),
                    validUntil = j.getLong("validUntil"),
                    rtl = j.optBoolean("rtl", true),
                    title = j.optString("title").ifEmpty { null },
                    empty = j.optString("empty").ifEmpty { null },
                    stale = j.optString("stale").ifEmpty { null },
                    taken = j.optString("taken").ifEmpty { null },
                    doses = (0 until list.length()).map {
                        val d = list.getJSONObject(it)
                        Dose(
                            at = d.getLong("at"),
                            until = d.getLong("until"),
                            time = d.getString("time"),
                            person = d.getString("person"),
                            medicine = d.getString("medicine"),
                            medicineId = d.getString("m"),
                        )
                    },
                )
            } catch (e: Exception) {
                null
            }
        }
    }
}
