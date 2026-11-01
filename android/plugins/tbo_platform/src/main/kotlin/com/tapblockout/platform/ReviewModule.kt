package com.tapblockout.platform

import android.util.Log
import com.google.android.play.core.review.ReviewManagerFactory

/** Google In-App Review. Luon phat review_done khi xong, ke ca loi (Play gioi han hien thi). */
class ReviewModule(private val host: Host) {
    fun review() {
        host.ui {
            val activity = host.hostActivity
            if (activity == null) {
                host.emit("review_done")
                return@ui
            }
            try {
                val manager = ReviewManagerFactory.create(activity)
                manager.requestReviewFlow().addOnCompleteListener { req ->
                    if (!req.isSuccessful) {
                        host.emit("review_done")
                        return@addOnCompleteListener
                    }
                    try {
                        manager.launchReviewFlow(activity, req.result)
                            .addOnCompleteListener { host.emit("review_done") }
                    } catch (t: Throwable) {
                        host.emit("review_done")
                    }
                }
            } catch (t: Throwable) {
                Log.w(TAG, "Review loi: ${t.javaClass.simpleName}")
                host.emit("review_done")
            }
        }
    }

    companion object {
        private const val TAG = PlatformConfig.TAG
    }
}
