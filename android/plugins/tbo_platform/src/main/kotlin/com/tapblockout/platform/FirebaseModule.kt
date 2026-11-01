package com.tapblockout.platform

import android.os.Bundle
import android.util.Log
import com.google.firebase.FirebaseApp
import com.google.firebase.FirebaseOptions
import com.google.firebase.analytics.FirebaseAnalytics
import com.google.firebase.crashlytics.FirebaseCrashlytics
import com.google.firebase.remoteconfig.FirebaseRemoteConfig
import com.google.firebase.remoteconfig.FirebaseRemoteConfigSettings
import org.json.JSONObject

/**
 * Firebase Analytics, Remote Config, Crashlytics.
 * Firebase duoc khoi tao boi google-services.json (plugin google-services) hoac boi cac khoa
 * firebase_app_id / firebase_api_key / firebase_project_id trong cau hinh. Khong co ca hai thi tat.
 */
class FirebaseModule(private val host: Host) {
    @Volatile var enabled = false; private set
    @Volatile var rcEnabled = false; private set
    @Volatile var crashEnabled = false; private set

    private var analytics: FirebaseAnalytics? = null
    private var crashlytics: FirebaseCrashlytics? = null
    private var rc: FirebaseRemoteConfig? = null

    fun init() {
        val ctx = host.hostContext.applicationContext
        try {
            if (FirebaseApp.getApps(ctx).isEmpty()) {
                val cfg = host.config
                val appId = cfg.str("firebase_app_id")
                val apiKey = cfg.str("firebase_api_key")
                val projectId = cfg.str("firebase_project_id")
                if (appId == null || apiKey == null || projectId == null) {
                    Log.i(TAG, "Firebase tat: khong co google-services.json hay khoa firebase_*")
                    return
                }
                FirebaseApp.initializeApp(
                    ctx,
                    FirebaseOptions.Builder()
                        .setApplicationId(appId)
                        .setApiKey(apiKey)
                        .setProjectId(projectId)
                        .build(),
                )
            }
            if (FirebaseApp.getApps(ctx).isEmpty()) return
            enabled = true
        } catch (t: Throwable) {
            Log.w(TAG, "Firebase khoi tao that bai: ${t.javaClass.simpleName}")
            return
        }
        try {
            analytics = FirebaseAnalytics.getInstance(ctx)
        } catch (t: Throwable) {
            Log.w(TAG, "Firebase Analytics tat: ${t.javaClass.simpleName}")
        }
        try {
            crashlytics = FirebaseCrashlytics.getInstance().also { it.setCrashlyticsCollectionEnabled(true) }
            crashEnabled = true
        } catch (t: Throwable) {
            Log.w(TAG, "Crashlytics tat: ${t.javaClass.simpleName}")
        }
        try {
            val remote = FirebaseRemoteConfig.getInstance()
            val interval = host.config.int("rc_min_fetch_interval_s", 3600).toLong()
            remote.setConfigSettingsAsync(
                FirebaseRemoteConfigSettings.Builder().setMinimumFetchIntervalInSeconds(interval).build(),
            )
            host.config.obj("rc_defaults")?.let { d ->
                val map = HashMap<String, Any>()
                for (k in d.keys()) map[k] = d.opt(k)?.toString() ?: ""
                if (map.isNotEmpty()) remote.setDefaultsAsync(map)
            }
            rc = remote
            rcEnabled = true
        } catch (t: Throwable) {
            Log.w(TAG, "Remote Config tat: ${t.javaClass.simpleName}")
        }
    }

    fun readyAnalytics(): Boolean = analytics != null

    fun logEvent(name: String, json: String) {
        val a = analytics ?: return
        try {
            a.logEvent(sanitizeName(name), toBundle(json))
        } catch (t: Throwable) {
            Log.w(TAG, "log_event loi: ${t.javaClass.simpleName}")
        }
    }

    fun setUserProps(json: String) {
        val o = Json.objectOrNull(json) ?: return
        for (k in o.keys()) {
            val v = o.opt(k)?.toString() ?: continue
            try {
                analytics?.setUserProperty(sanitizeName(k), v.take(36))
                if (k == "user_id") crashlytics?.setUserId(v)
                crashlytics?.setCustomKey(sanitizeName(k), v)
            } catch (_: Throwable) {
            }
        }
    }

    fun logAdImpression(network: String, unit: String, format: String, revenue: Double) {
        val a = analytics ?: return
        try {
            val b = Bundle()
            b.putString(FirebaseAnalytics.Param.AD_PLATFORM, "appLovin")
            b.putString(FirebaseAnalytics.Param.AD_SOURCE, network)
            b.putString(FirebaseAnalytics.Param.AD_FORMAT, format)
            b.putString(FirebaseAnalytics.Param.AD_UNIT_NAME, unit)
            b.putDouble(FirebaseAnalytics.Param.VALUE, revenue)
            b.putString(FirebaseAnalytics.Param.CURRENCY, "USD")
            a.logEvent(FirebaseAnalytics.Event.AD_IMPRESSION, b)
        } catch (_: Throwable) {
        }
    }

    fun crashLog(message: String) {
        try {
            crashlytics?.log(message)
        } catch (_: Throwable) {
        }
    }

    fun rcFetch() {
        val r = rc
        if (r == null) {
            host.emit("rc_fetched", Json.obj("ok" to false, "values" to JSONObject()))
            return
        }
        try {
            r.fetchAndActivate().addOnCompleteListener { task ->
                host.emit("rc_fetched", Json.obj("ok" to task.isSuccessful, "values" to values()))
            }
        } catch (t: Throwable) {
            host.emit("rc_fetched", Json.obj("ok" to false, "values" to JSONObject()))
        }
    }

    fun rcGetAll(): String = values().toString()

    private fun values(): JSONObject {
        val out = JSONObject()
        try {
            rc?.all?.forEach { (k, v) -> out.put(k, v.asString()) }
        } catch (_: Throwable) {
        }
        return out
    }

    private fun toBundle(json: String): Bundle {
        val b = Bundle()
        val o = Json.objectOrNull(json) ?: return b
        var n = 0
        for (k in o.keys()) {
            if (n >= 25) break
            val key = sanitizeName(k)
            when (val v = o.opt(k)) {
                is Int -> b.putLong(key, v.toLong())
                is Long -> b.putLong(key, v)
                is Double -> b.putDouble(key, v)
                is Boolean -> b.putLong(key, if (v) 1L else 0L)
                null, JSONObject.NULL -> continue
                else -> b.putString(key, v.toString().take(100))
            }
            n++
        }
        return b
    }

    /** Ten su kien/tham so Firebase: chu cai dau, chi a-z 0-9 _, toi da 40 ky tu. */
    private fun sanitizeName(raw: String): String {
        var s = raw.lowercase().replace(Regex("[^a-z0-9_]"), "_")
        if (s.isEmpty() || !s[0].isLetter()) s = "e_$s"
        return s.take(40)
    }

    companion object {
        private const val TAG = PlatformConfig.TAG
    }
}
