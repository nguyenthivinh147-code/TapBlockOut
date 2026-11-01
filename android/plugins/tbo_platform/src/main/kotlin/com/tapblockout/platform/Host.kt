package com.tapblockout.platform

import android.app.Activity
import android.content.Context

/** Cau noi giua cac mo-dun va lop plugin Godot. */
interface Host {
    val hostActivity: Activity?
    val hostContext: Context
    val config: PlatformConfig

    /** Phat signal ve Godot (an toan khi goi tu bat ky luong nao). */
    fun emit(signal: String, vararg args: Any)

    /** Chay tren luong UI. */
    fun ui(block: () -> Unit)
}
