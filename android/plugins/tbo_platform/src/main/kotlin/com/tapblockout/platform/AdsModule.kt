package com.tapblockout.platform

import android.app.Activity
import android.content.Context
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.applovin.mediation.MaxAd
import com.applovin.mediation.MaxAdListener
import com.applovin.mediation.MaxError
import com.applovin.mediation.MaxReward
import com.applovin.mediation.MaxRewardedAdListener
import com.applovin.mediation.ads.MaxInterstitialAd
import com.applovin.mediation.ads.MaxRewardedAd
import com.applovin.sdk.AppLovinMediationProvider
import com.applovin.sdk.AppLovinSdk
import com.applovin.sdk.AppLovinSdkConfiguration
import com.applovin.sdk.AppLovinSdkInitializationConfiguration
import kotlin.math.min
import kotlin.math.pow

/** AppLovin MAX: rewarded, interstitial, dong y (UMP qua luong cua MAX), mediation debugger. */
class AdsModule(
    private val host: Host,
    private val prefs: android.content.SharedPreferences,
    private val onRevenue: (network: String, unit: String, format: String, revenue: Double) -> Unit,
) {
    private val handler = Handler(Looper.getMainLooper())

    private var sdkKey: String? = null
    private var rewardedUnit: String? = null
    private var interUnit: String? = null

    @Volatile var enabled = false; private set
    @Volatile var sdkReady = false; private set

    private var rewarded: MaxRewardedAd? = null
    private var inter: MaxInterstitialAd? = null
    private var rewardedRetry = 0
    private var interRetry = 0

    private var rewardedPlacement: String? = null
    private var rewardedEarned = false
    private var interPlacement: String? = null

    /** Placement quang cao bi mat o phien truoc (app bi dong khi dang xem). */
    private var lost: Set<String> = emptySet()

    fun captureLost() {
        lost = prefs.getStringSet(KEY_PENDING, emptySet())?.toSet() ?: emptySet()
        prefs.edit().remove(KEY_PENDING).apply()
    }

    fun lostRewarded(): Array<String> = lost.toTypedArray()

    fun lostDone() {
        lost = emptySet()
    }

    fun init(onDone: () -> Unit) {
        val cfg = host.config
        sdkKey = cfg.str("applovin_sdk_key")
        rewardedUnit = cfg.str("rewarded_unit")
        interUnit = cfg.str("interstitial_unit")
        if (sdkKey == null || (rewardedUnit == null && interUnit == null)) {
            Log.i(TAG, "MAX tat: thieu applovin_sdk_key hoac ad unit")
            onDone()
            return
        }
        host.ui {
            try {
                val activity = host.hostActivity
                if (activity == null) {
                    Log.w(TAG, "MAX tat: chua co Activity")
                    onDone()
                    return@ui
                }
                startSdk(activity, onDone)
            } catch (t: Throwable) {
                Log.w(TAG, "MAX khoi tao that bai: ${t.javaClass.simpleName}")
                onDone()
            }
        }
    }

    private fun startSdk(activity: Activity, onDone: () -> Unit) {
        val sdk = AppLovinSdk.getInstance(activity)
        val cfg = host.config
        val privacy = cfg.str("privacy_policy_url")
        if (privacy != null) {
            val flow = sdk.settings.termsAndPrivacyPolicyFlowSettings
            flow.isEnabled = true
            flow.privacyPolicyUri = Uri.parse(privacy)
            cfg.str("terms_url")?.let { flow.termsOfServiceUri = Uri.parse(it) }
            when (cfg.str("consent_debug_geography")?.lowercase()) {
                "gdpr" -> flow.debugUserGeography = AppLovinSdkConfiguration.ConsentFlowUserGeography.GDPR
                "other" -> flow.debugUserGeography = AppLovinSdkConfiguration.ConsentFlowUserGeography.OTHER
            }
        } else {
            Log.i(TAG, "Thieu privacy_policy_url: luong dong y cua MAX khong bat")
        }
        val units = listOfNotNull(rewardedUnit, interUnit)
        val init = AppLovinSdkInitializationConfiguration.builder(sdkKey!!)
            .setMediationProvider(AppLovinMediationProvider.MAX)
            .setAdUnitIds(units)
            .build()
        enabled = true
        sdk.initialize(init) {
            host.ui {
                try {
                    sdkReady = true
                    createAds(activity)
                } catch (t: Throwable) {
                    Log.w(TAG, "Tao quang cao that bai: ${t.javaClass.simpleName}")
                }
                onDone()
            }
        }
    }

    private fun createAds(activity: Activity) {
        rewardedUnit?.let { unit ->
            val ad = MaxRewardedAd.getInstance(unit, activity)
            ad.setListener(rewardedListener)
            ad.setRevenueListener { onRevenue(it.networkName, it.adUnitId, it.format.label, it.revenue) }
            rewarded = ad
            ad.loadAd()
        }
        interUnit?.let { unit ->
            val ad = MaxInterstitialAd(unit, activity)
            ad.setListener(interListener)
            ad.setRevenueListener { onRevenue(it.networkName, it.adUnitId, it.format.label, it.revenue) }
            inter = ad
            ad.loadAd()
        }
    }

    fun readyRewarded(): Boolean = try { rewarded?.isReady == true } catch (_: Throwable) { false }

    fun readyInter(): Boolean = try { inter?.isReady == true } catch (_: Throwable) { false }

    fun loadAds() {
        if (!sdkReady) return
        host.ui {
            try {
                rewarded?.let { if (!it.isReady && !it.isLoading) it.loadAd() }
                inter?.let { if (!it.isReady && !it.isLoading) it.loadAd() }
            } catch (_: Throwable) {
            }
        }
    }

    fun showRewarded(placement: String) {
        host.ui {
            val ad = rewarded
            val activity = host.hostActivity
            if (!enabled || ad == null || activity == null || !ad.isReady) {
                host.emit("ad_rewarded_done", placement, false, "not_ready")
                loadAds()
                return@ui
            }
            if (rewardedPlacement != null) {
                host.emit("ad_rewarded_done", placement, false, "error")
                return@ui
            }
            rewardedPlacement = placement
            rewardedEarned = false
            markPending(placement)
            try {
                ad.showAd(placement, activity)
            } catch (t: Throwable) {
                finishRewarded("error")
            }
        }
    }

    fun showInter(placement: String) {
        host.ui {
            val ad = inter
            val activity = host.hostActivity
            if (!enabled || ad == null || activity == null || !ad.isReady || interPlacement != null) {
                host.emit("ad_interstitial_done", placement, false)
                loadAds()
                return@ui
            }
            interPlacement = placement
            try {
                ad.showAd(placement, activity)
            } catch (t: Throwable) {
                finishInter(false)
            }
        }
    }

    fun hasPrivacy(): Boolean = try {
        sdkReady && AppLovinSdk.getInstance(host.hostContext).configuration.consentFlowUserGeography ==
            AppLovinSdkConfiguration.ConsentFlowUserGeography.GDPR
    } catch (_: Throwable) {
        false
    }

    fun openPrivacy() {
        host.ui {
            val activity = host.hostActivity
            if (!sdkReady || activity == null) {
                host.emit("privacy_done", false)
                return@ui
            }
            try {
                AppLovinSdk.getInstance(activity).cmpService.showCmpForExistingUser(activity) { error ->
                    host.emit("privacy_done", error == null)
                }
            } catch (t: Throwable) {
                host.emit("privacy_done", false)
            }
        }
    }

    fun openDebugger() {
        if (!sdkReady) return
        host.ui {
            try {
                AppLovinSdk.getInstance(host.hostContext).showMediationDebugger()
            } catch (_: Throwable) {
            }
        }
    }

    private fun finishRewarded(failReason: String) {
        val placement = rewardedPlacement ?: return
        val ok = rewardedEarned
        rewardedPlacement = null
        rewardedEarned = false
        clearPending(placement)
        host.emit("ad_rewarded_done", placement, ok, if (ok) "" else failReason)
        rewarded?.loadAd()
    }

    private fun finishInter(shown: Boolean) {
        val placement = interPlacement ?: return
        interPlacement = null
        host.emit("ad_interstitial_done", placement, shown)
        inter?.loadAd()
    }

    private fun backoff(retry: Int): Long = (2.0.pow(min(6, retry)) * 1000).toLong()

    private val rewardedListener = object : MaxRewardedAdListener {
        override fun onAdLoaded(ad: MaxAd) {
            rewardedRetry = 0
        }

        override fun onAdLoadFailed(adUnitId: String, error: MaxError) {
            rewardedRetry++
            handler.postDelayed({ try { rewarded?.loadAd() } catch (_: Throwable) {} }, backoff(rewardedRetry))
        }

        override fun onAdDisplayed(ad: MaxAd) {}

        override fun onAdClicked(ad: MaxAd) {}

        override fun onAdDisplayFailed(ad: MaxAd, error: MaxError) = finishRewarded("error")

        override fun onUserRewarded(ad: MaxAd, reward: MaxReward) {
            rewardedEarned = true
        }

        override fun onAdHidden(ad: MaxAd) = finishRewarded("closed")
    }

    private val interListener = object : MaxAdListener {
        override fun onAdLoaded(ad: MaxAd) {
            interRetry = 0
        }

        override fun onAdLoadFailed(adUnitId: String, error: MaxError) {
            interRetry++
            handler.postDelayed({ try { inter?.loadAd() } catch (_: Throwable) {} }, backoff(interRetry))
        }

        override fun onAdDisplayed(ad: MaxAd) {}

        override fun onAdClicked(ad: MaxAd) {}

        override fun onAdDisplayFailed(ad: MaxAd, error: MaxError) = finishInter(false)

        override fun onAdHidden(ad: MaxAd) = finishInter(true)
    }

    private fun markPending(placement: String) {
        val set = (prefs.getStringSet(KEY_PENDING, emptySet()) ?: emptySet()).toMutableSet()
        set.add(placement)
        prefs.edit().putStringSet(KEY_PENDING, set).commit()
    }

    private fun clearPending(placement: String) {
        val set = (prefs.getStringSet(KEY_PENDING, emptySet()) ?: emptySet()).toMutableSet()
        set.remove(placement)
        prefs.edit().putStringSet(KEY_PENDING, set).commit()
    }

    companion object {
        private const val TAG = PlatformConfig.TAG
        private const val KEY_PENDING = "rewarded_pending"
    }
}
