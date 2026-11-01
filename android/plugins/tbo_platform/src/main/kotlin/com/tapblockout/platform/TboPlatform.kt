package com.tapblockout.platform

import android.app.Activity
import android.content.Context
import android.util.Log
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot

/**
 * Singleton `TboPlatform` cho Godot. Moi ham an toan khi thieu cau hinh: mo-dun tu tat,
 * ham khong lam gi, khong crash. Ket qua bat dong bo qua signal; du lieu phuc tap la chuoi JSON.
 * Xem android/plugins/tbo_platform/API.md.
 */
class TboPlatform(godot: Godot) : GodotPlugin(godot), Host {
    override val hostActivity: Activity? get() = getActivity()
    override val hostContext: Context get() = getContext()
    override val config: PlatformConfig by lazy { PlatformConfig(getContext()) }

    private val prefs by lazy { getContext().getSharedPreferences(PREFS, Context.MODE_PRIVATE) }
    private var configJson: String? = null
    private var started = false

    private val ads by lazy {
        AdsModule(this, prefs) { network, unit, format, revenue ->
            firebase.logAdImpression(network, unit, format, revenue)
        }
    }
    private val firebase by lazy { FirebaseModule(this) }
    private val adjust by lazy { AdjustModule(this) }
    private val review by lazy { ReviewModule(this) }
    private val cloud by lazy { CloudSaveModule(this) }
    private val notif by lazy { NotifModule(this) }

    init {
        // Doc cac placement quang cao bi mat truoc khi phien nay ghi them.
        guard { ads.captureLost() }
    }

    override fun getPluginName(): String = "TboPlatform"

    override fun getPluginSignals(): Set<SignalInfo> = setOf(
        SignalInfo("sdk_ready", String::class.java),
        SignalInfo("consent_ready"),
        SignalInfo("privacy_done", Boolean::class.java),
        SignalInfo("ad_rewarded_done", String::class.java, Boolean::class.java, String::class.java),
        SignalInfo("ad_interstitial_done", String::class.java, Boolean::class.java),
        SignalInfo("rc_fetched", String::class.java),
        SignalInfo("cloud_loaded", String::class.java, Boolean::class.java),
        SignalInfo("cloud_saved", Boolean::class.java),
        SignalInfo("cloud_conflict", String::class.java),
        SignalInfo("notif_permission", Boolean::class.java),
        SignalInfo("review_done"),
    )

    // Host

    override fun emit(signal: String, vararg args: Any) {
        try {
            emitSignal(signal, *args)
        } catch (t: Throwable) {
            Log.w(TAG, "emit $signal loi: ${t.javaClass.simpleName}")
        }
    }

    override fun ui(block: () -> Unit) {
        runOnUiThread {
            try {
                block()
            } catch (t: Throwable) {
                Log.w(TAG, "Loi tren luong UI: ${t.javaClass.simpleName}")
            }
        }
    }

    private inline fun guard(block: () -> Unit) {
        try {
            block()
        } catch (t: Throwable) {
            Log.w(TAG, "Loi: ${t.javaClass.simpleName}")
        }
    }

    private inline fun <T> guard(default: T, block: () -> T): T = try {
        block()
    } catch (t: Throwable) {
        Log.w(TAG, "Loi: ${t.javaClass.simpleName}")
        default
    }

    // Vong doi

    override fun onMainResume() {
        super.onMainResume()
        if (started) guard { adjust.onResume() }
    }

    override fun onMainPause() {
        super.onMainPause()
        if (started) guard { adjust.onPause() }
    }

    override fun onMainRequestPermissionsResult(requestCode: Int, permissions: Array<String>, grantResults: IntArray) {
        super.onMainRequestPermissionsResult(requestCode, permissions, grantResults)
        guard { notif.onPermissionResult(requestCode, permissions, grantResults) }
    }

    // Khoi tao

    /** Tuy chon: truyen noi dung res://android_config.json. Goi truoc init_sdks(). */
    @UsedByGodot
    fun set_config(json: String) {
        configJson = json
    }

    @UsedByGodot
    fun plugin_version(): String = VERSION

    /** Idempotent. Phat sdk_ready(module_status) va consent_ready khi xong. */
    @UsedByGodot
    fun init_sdks() {
        if (started) return
        started = true
        guard {
            config.load(configJson)
            firebase.init()
            adjust.init()
            cloud.init()
            ads.init {
                emit("consent_ready")
                emit("sdk_ready", module_status())
            }
        }
    }

    @UsedByGodot
    fun module_status(): String = guard("{}") {
        Json.obj(
            "ads" to ads.enabled,
            "ads_ready" to ads.sdkReady,
            "rewarded" to ads.readyRewarded(),
            "inter" to ads.readyInter(),
            "firebase" to firebase.enabled,
            "analytics" to firebase.readyAnalytics(),
            "rc" to firebase.rcEnabled,
            "crashlytics" to firebase.crashEnabled,
            "adjust" to adjust.enabled,
            "cloud" to cloud.enabled,
            "notif" to notif.enabled(),
        )
    }

    // Quang cao

    @UsedByGodot
    fun ready_rewarded(): Boolean = guard(false) { ads.readyRewarded() }

    @UsedByGodot
    fun ready_inter(): Boolean = guard(false) { ads.readyInter() }

    @UsedByGodot
    fun load_ads() = guard { ads.loadAds() }

    @UsedByGodot
    fun show_rewarded(placement: String) {
        guard { ads.showRewarded(placement) }
    }

    @UsedByGodot
    fun show_inter(placement: String) {
        guard { ads.showInter(placement) }
    }

    @UsedByGodot
    fun has_privacy(): Boolean = guard(false) { ads.hasPrivacy() }

    @UsedByGodot
    fun open_privacy() {
        guard { ads.openPrivacy() }
    }

    @UsedByGodot
    fun open_debugger() {
        guard { ads.openDebugger() }
    }

    @UsedByGodot
    fun lost_rewarded(): Array<String> = guard(emptyArray()) { ads.lostRewarded() }

    @UsedByGodot
    fun lost_done() {
        guard { ads.lostDone() }
    }

    // Analytics, Adjust, Crashlytics

    @UsedByGodot
    fun log_event(name: String, json: String) {
        guard {
            firebase.logEvent(name, json)
            adjust.track(name)
        }
    }

    @UsedByGodot
    fun set_user_props(json: String) {
        guard { firebase.setUserProps(json) }
    }

    @UsedByGodot
    fun crash_log(message: String) {
        guard { firebase.crashLog(message) }
    }

    // Remote Config

    @UsedByGodot
    fun rc_fetch() {
        guard { firebase.rcFetch() }
    }

    @UsedByGodot
    fun rc_get_all(): String = guard("{}") { firebase.rcGetAll() }

    // Danh gia

    @UsedByGodot
    fun review() {
        guard { review.review() }
    }

    // Cloud save

    @UsedByGodot
    fun cloud_load() {
        guard { cloud.load() }
    }

    @UsedByGodot
    fun cloud_save(json: String) {
        guard { cloud.save(json) }
    }

    // Thong bao

    @UsedByGodot
    fun notif_ask() {
        guard { notif.ask() }
    }

    @UsedByGodot
    fun notif_enabled(): Boolean = guard(false) { notif.enabled() }

    @UsedByGodot
    fun notif_schedule(jsonItems: String) {
        guard { notif.schedule(jsonItems) }
    }

    @UsedByGodot
    fun notif_cancel_all() {
        guard { notif.cancelAll() }
    }

    companion object {
        const val TAG = PlatformConfig.TAG
        const val PREFS = "tbo_platform"
        const val VERSION = "1.0.0"
    }
}
