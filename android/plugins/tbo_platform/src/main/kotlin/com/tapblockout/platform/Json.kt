package com.tapblockout.platform

import org.json.JSONObject

/** Tien ich JSON nho, chi dung org.json cua Android. */
internal object Json {
    fun obj(vararg pairs: Pair<String, Any?>): String {
        val o = JSONObject()
        for ((k, v) in pairs) o.put(k, v ?: JSONObject.NULL)
        return o.toString()
    }

    fun objectOrNull(text: String): JSONObject? = try {
        JSONObject(text)
    } catch (_: Exception) {
        null
    }
}
