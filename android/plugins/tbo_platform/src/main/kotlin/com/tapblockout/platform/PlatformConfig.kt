package com.tapblockout.platform

import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import org.json.JSONObject

/**
 * Cau hinh luc chay. Nguon (uu tien giam dan):
 * 1. JSON do GDScript truyen qua set_config() (noi dung res://android_config.json).
 * 2. Tep assets/android_config.json trong APK (neu co).
 * 3. meta-data trong manifest, khoa dang "tbo.<ten_khoa>".
 * Thieu khoa hoac gia tri la cho (rong, "YOUR_...", "REPLACE_...", "<...>") thi mo-dun tuong ung tu tat.
 */
class PlatformConfig(private val context: Context) {
    private var json: JSONObject = JSONObject()
    private var metaData: android.os.Bundle? = null

    fun load(explicitJson: String?) {
        json = JSONObject()
        if (!explicitJson.isNullOrBlank()) {
            json = parse(explicitJson, "set_config")
        } else {
            try {
                context.assets.open(ASSET_NAME).use { json = parse(it.readBytes().toString(Charsets.UTF_8), "assets") }
            } catch (_: Exception) {
                // Khong co tep: binh thuong.
            }
        }
        metaData = try {
            context.packageManager
                .getApplicationInfo(context.packageName, PackageManager.GET_META_DATA).metaData
        } catch (_: Exception) {
            null
        }
    }

    private fun parse(text: String, source: String): JSONObject = try {
        JSONObject(text)
    } catch (e: Exception) {
        Log.w(TAG, "Cau hinh ($source) khong phai JSON hop le, bo qua")
        JSONObject()
    }

    /** Chuoi cau hinh, null neu thieu hoac la cho. */
    fun str(key: String): String? {
        var v: String? = if (json.has(key) && !json.isNull(key)) json.optString(key) else null
        if (v.isNullOrBlank()) v = metaData?.get("tbo.$key")?.toString()
        v = v?.trim()
        if (v.isNullOrEmpty() || isPlaceholder(v)) return null
        return v
    }

    fun int(key: String, default: Int): Int =
        if (json.has(key)) json.optInt(key, default) else (str(key)?.toIntOrNull() ?: default)

    fun obj(key: String): JSONObject? = json.optJSONObject(key)

    private fun isPlaceholder(v: String): Boolean {
        val u = v.uppercase()
        return u.startsWith("YOUR_") || u.startsWith("REPLACE") || u.startsWith("<") || u.startsWith("TODO")
    }

    companion object {
        const val TAG = "TboPlatform"
        const val ASSET_NAME = "android_config.json"
    }
}
