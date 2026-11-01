package com.tapblockout.platform

import android.Manifest
import android.app.Activity
import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/** Thong bao local: AlarmManager + BroadcastReceiver, quyen POST_NOTIFICATIONS (Android 13+). */
class NotifModule(private val host: Host) {
    fun ask() {
        host.ui {
            val activity: Activity? = host.hostActivity
            try {
                if (Build.VERSION.SDK_INT < 33 || activity == null) {
                    host.emit("notif_permission", enabled())
                    return@ui
                }
                if (activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
                    PackageManager.PERMISSION_GRANTED
                ) {
                    host.emit("notif_permission", enabled())
                    return@ui
                }
                activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_CODE)
            } catch (t: Throwable) {
                Log.w(TAG, "Xin quyen thong bao loi: ${t.javaClass.simpleName}")
                host.emit("notif_permission", false)
            }
        }
    }

    /** Goi tu onMainRequestPermissionsResult. */
    fun onPermissionResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        if (requestCode != REQUEST_CODE) return
        val i = permissions.indexOf(Manifest.permission.POST_NOTIFICATIONS)
        host.emit("notif_permission", i >= 0 && i < grantResults.size && grantResults[i] == PackageManager.PERMISSION_GRANTED)
    }

    fun enabled(): Boolean = try {
        val nm = host.hostContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.areNotificationsEnabled()
    } catch (_: Throwable) {
        false
    }

    fun schedule(jsonItems: String) {
        try {
            Scheduler.replace(host.hostContext.applicationContext, JSONArray(jsonItems))
        } catch (t: Throwable) {
            Log.w(TAG, "Dat lich thong bao loi: ${t.javaClass.simpleName}")
        }
    }

    fun cancelAll() {
        try {
            Scheduler.cancelAll(host.hostContext.applicationContext)
        } catch (_: Throwable) {
        }
    }

    /** Dat/huy bao thuc va luu ke hoach de dat lai sau khi khoi dong may. */
    object Scheduler {
        private const val KEY_PLAN = "notif_plan"
        private const val MAX_ITEMS = 60
        const val ACTION = "com.tapblockout.platform.NOTIF"

        private fun prefs(ctx: Context) = ctx.getSharedPreferences(TboPlatform.PREFS, Context.MODE_PRIVATE)

        private fun pending(ctx: Context, index: Int, extras: JSONObject?): PendingIntent {
            val intent = Intent(ctx, NotifReceiver::class.java).setAction(ACTION)
            if (extras != null) {
                intent.putExtra("title", extras.optString("title"))
                intent.putExtra("body", extras.optString("body"))
                intent.putExtra("kind", extras.optString("kind"))
            }
            return PendingIntent.getBroadcast(
                ctx, REQUEST_BASE + index, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        fun cancelAll(ctx: Context) {
            val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val old = prefs(ctx).getString(KEY_PLAN, null)
            val n = try { if (old == null) 0 else JSONArray(old).length() } catch (_: Exception) { 0 }
            for (i in 0 until maxOf(n, MAX_ITEMS)) am.cancel(pending(ctx, i, null))
            prefs(ctx).edit().remove(KEY_PLAN).apply()
        }

        /** Thay toan bo ke hoach: huy lich cu, chi giu muc co "at" (giay unix) o tuong lai. */
        fun replace(ctx: Context, items: JSONArray) {
            cancelAll(ctx)
            val nowSec = System.currentTimeMillis() / 1000
            val keep = JSONArray()
            for (i in 0 until items.length()) {
                val o = items.optJSONObject(i) ?: continue
                if (o.optLong("at", 0) > nowSec && keep.length() < MAX_ITEMS) keep.put(o)
            }
            prefs(ctx).edit().putString(KEY_PLAN, keep.toString()).apply()
            arm(ctx, keep)
        }

        fun rescheduleFromPrefs(ctx: Context) {
            val text = prefs(ctx).getString(KEY_PLAN, null) ?: return
            val nowSec = System.currentTimeMillis() / 1000
            val src = JSONArray(text)
            val keep = JSONArray()
            for (i in 0 until src.length()) {
                val o = src.optJSONObject(i) ?: continue
                if (o.optLong("at", 0) > nowSec) keep.put(o)
            }
            arm(ctx, keep)
        }

        private fun arm(ctx: Context, items: JSONArray) {
            val am = ctx.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            for (i in 0 until items.length()) {
                val o = items.getJSONObject(i)
                // Bao thuc khong chinh xac nen khong can quyen SCHEDULE_EXACT_ALARM.
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, o.getLong("at") * 1000, pending(ctx, i, o))
            }
        }
    }

    companion object {
        private const val TAG = PlatformConfig.TAG
        const val REQUEST_CODE = 7731
        const val REQUEST_BASE = 4200
        const val CHANNEL_ID = "tbo_reminders"
    }
}

/** Hien thong bao khi bao thuc no. */
class NotifReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (!nm.areNotificationsEnabled()) return
            if (Build.VERSION.SDK_INT >= 26) {
                nm.createNotificationChannel(
                    NotificationChannel(
                        NotifModule.CHANNEL_ID,
                        context.getString(R.string.tbo_notif_channel_name),
                        NotificationManager.IMPORTANCE_DEFAULT,
                    ),
                )
            }
            val pkg = context.packageName
            val launch = context.packageManager.getLaunchIntentForPackage(pkg) ?: return
            val content = PendingIntent.getActivity(
                context, 0, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            var icon = context.resources.getIdentifier("ic_stat_notify", "drawable", pkg)
            if (icon == 0) icon = context.applicationInfo.icon
            @Suppress("DEPRECATION")
            val builder = if (Build.VERSION.SDK_INT >= 26) {
                android.app.Notification.Builder(context, NotifModule.CHANNEL_ID)
            } else {
                android.app.Notification.Builder(context)
            }
            val n = builder
                .setSmallIcon(icon)
                .setContentTitle(intent.getStringExtra("title") ?: "")
                .setContentText(intent.getStringExtra("body") ?: "")
                .setContentIntent(content)
                .setAutoCancel(true)
                .build()
            nm.notify(NotifModule.REQUEST_BASE + (System.currentTimeMillis() % 1000).toInt(), n)
        } catch (t: Throwable) {
            Log.w(PlatformConfig.TAG, "Hien thong bao loi: ${t.javaClass.simpleName}")
        }
    }
}

/** Dat lai lich sau khi khoi dong may hoac cap nhat app (bao thuc bi xoa khi reboot). */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            NotifModule.Scheduler.rescheduleFromPrefs(context.applicationContext)
        } catch (t: Throwable) {
            Log.w(PlatformConfig.TAG, "Dat lai lich loi: ${t.javaClass.simpleName}")
        }
    }
}
