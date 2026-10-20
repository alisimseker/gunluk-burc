package com.alisimseker.gunluk_burc

import android.content.Context
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Seçilen burç + indirilen yorumların telefonda saklanması ve indirilmesi. */
object Store {
    private const val PREFS = "gunlukburc_native"

    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun save(ctx: Context, sign: String, baseUrl: String) {
        prefs(ctx).edit().putString("sign", sign).putString("baseUrl", baseUrl.trimEnd('/')).apply()
    }

    fun sign(ctx: Context): String? = prefs(ctx).getString("sign", null)
    private fun baseUrl(ctx: Context): String? = prefs(ctx).getString("baseUrl", null)

    /** İnternetten indirir; başarılıysa önbelleğe yazar. İnternet yoksa sessizce false döner. */
    fun refresh(ctx: Context): Boolean {
        val sign = sign(ctx) ?: return false
        val base = baseUrl(ctx) ?: return false
        return try {
            val conn = URL("$base/v1/$sign.json?t=${System.currentTimeMillis() / 600000}")
                .openConnection() as HttpURLConnection
            conn.connectTimeout = 15000
            conn.readTimeout = 15000
            conn.useCaches = false
            try {
                if (conn.responseCode != 200) return false
                val body = conn.inputStream.bufferedReader(Charsets.UTF_8).use { it.readText() }
                JSONObject(body) // geçerli mi kontrol
                prefs(ctx).edit().putString("cache_$sign", body).apply()
                true
            } finally {
                conn.disconnect()
            }
        } catch (_: Exception) {
            false
        }
    }

    data class Reading(val signName: String, val date: String, val short: String,
                       val text: String, val motivation: String)

    fun today(ctx: Context): Reading? = forDate(ctx, isoToday())

    fun forDate(ctx: Context, iso: String): Reading? {
        val sign = sign(ctx) ?: return null
        val body = prefs(ctx).getString("cache_$sign", null) ?: return null
        return try {
            val j = JSONObject(body)
            val days = j.getJSONArray("days")
            for (i in 0 until days.length()) {
                val d = days.getJSONObject(i)
                if (d.optString("date") == iso) {
                    return Reading(j.optString("name"), iso, d.optString("short"),
                        d.optString("text"), d.optString("motivation"))
                }
            }
            null
        } catch (_: Exception) {
            null
        }
    }

    fun isoToday(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
}
