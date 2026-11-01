package com.tapblockout.platform

import android.util.Log
import com.adjust.sdk.Adjust
import com.adjust.sdk.AdjustConfig
import com.adjust.sdk.AdjustEvent

/** Adjust: attribution va su kien. Tat khi thieu adjust_app_token. */
class AdjustModule(private val host: Host) {
    @Volatile var enabled = false; private set
    private var events: Map<String, String> = emptyMap()

    fun init() {
        val token = host.config.str("adjust_app_token")
        if (token == null) {
            Log.i(TAG, "Adjust tat: thieu adjust_app_token")
            return
        }
        try {
            val env = if (host.config.str("adjust_environment")?.lowercase() == "production") {
                AdjustConfig.ENVIRONMENT_PRODUCTION
            } else {
                AdjustConfig.ENVIRONMENT_SANDBOX
            }
            Adjust.initSdk(AdjustConfig(host.hostContext.applicationContext, token, env))
            val map = HashMap<String, String>()
            host.config.obj("adjust_events")?.let { o ->
                for (k in o.keys()) o.optString(k).takeIf { it.isNotBlank() }?.let { map[k] = it }
            }
            events = map
            enabled = true
        } catch (t: Throwable) {
            Log.w(TAG, "Adjust khoi tao that bai: ${t.javaClass.simpleName}")
        }
    }

    fun onResume() {
        if (enabled) try { Adjust.onResume() } catch (_: Throwable) {}
    }

    fun onPause() {
        if (enabled) try { Adjust.onPause() } catch (_: Throwable) {}
    }

    /** Chi gui khi ten su kien co token trong adjust_events. */
    fun track(name: String) {
        if (!enabled) return
        val token = events[name] ?: return
        try {
            Adjust.trackEvent(AdjustEvent(token))
        } catch (_: Throwable) {
        }
    }

    companion object {
        private const val TAG = PlatformConfig.TAG
    }
}
