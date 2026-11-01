package com.tapblockout.platform

import android.app.Activity
import android.util.Log
import com.google.android.gms.games.PlayGames
import com.google.android.gms.games.PlayGamesSdk
import com.google.android.gms.games.SnapshotsClient
import com.google.android.gms.games.snapshot.Snapshot
import com.google.android.gms.games.snapshot.SnapshotMetadataChange
import com.google.android.gms.tasks.Task

/**
 * Play Games Saved Games (Play Games Services v2).
 * Bat khi manifest co meta-data com.google.android.gms.games.APP_ID khac "0"
 * (do addon tbo_platform ghi tu play_games_app_id luc export). Thieu thi tat.
 * Xung dot: giu ban co (play_ms, runs, level) lon hon; ban thua gui qua signal cloud_conflict
 * de GDScript gop danh sach don da mua roi cloud_save lai.
 */
class CloudSaveModule(private val host: Host) {
    @Volatile var enabled = false; private set

    fun init() {
        val id = try {
            host.hostContext.packageManager
                .getApplicationInfo(host.hostContext.packageName, android.content.pm.PackageManager.GET_META_DATA)
                .metaData?.get(META_APP_ID)?.toString()?.trim()
        } catch (_: Exception) {
            null
        }
        if (id.isNullOrEmpty() || id == "0") {
            Log.i(TAG, "Cloud save tat: chua co play_games_app_id")
            return
        }
        try {
            PlayGamesSdk.initialize(host.hostContext.applicationContext)
            enabled = true
        } catch (t: Throwable) {
            Log.w(TAG, "Play Games khoi tao that bai: ${t.javaClass.simpleName}")
        }
    }

    fun load() {
        withClient({ host.emit("cloud_loaded", "", false) }) { client ->
            openResolved(client, client.open(SNAP_NAME, true, SnapshotsClient.RESOLUTION_POLICY_MANUAL), 0, null) { snap, loser ->
                if (snap == null) {
                    host.emit("cloud_loaded", "", false)
                    return@openResolved
                }
                val json = read(snap)
                try {
                    client.discardAndClose(snap)
                } catch (_: Throwable) {
                }
                if (loser != null && loser.isNotEmpty()) host.emit("cloud_conflict", loser)
                host.emit("cloud_loaded", json, true)
            }
        }
    }

    fun save(json: String) {
        withClient({ host.emit("cloud_saved", false) }) { client ->
            openResolved(client, client.open(SNAP_NAME, true, SnapshotsClient.RESOLUTION_POLICY_MANUAL), 0, null) { snap, _ ->
                if (snap == null) {
                    host.emit("cloud_saved", false)
                    return@openResolved
                }
                try {
                    snap.snapshotContents.writeBytes(json.toByteArray(Charsets.UTF_8))
                    val change = SnapshotMetadataChange.Builder().setDescription("Tap Block Out")
                    val o = Json.objectOrNull(json)
                    if (o != null) {
                        if (o.has("play_ms")) change.setPlayedTimeMillis(o.optLong("play_ms"))
                        if (o.has("level")) change.setProgressValue(o.optLong("level"))
                    }
                    client.commitAndClose(snap, change.build())
                        .addOnCompleteListener { host.emit("cloud_saved", it.isSuccessful) }
                } catch (t: Throwable) {
                    host.emit("cloud_saved", false)
                }
            }
        }
    }

    private fun withClient(onFail: () -> Unit, block: (SnapshotsClient) -> Unit) {
        host.ui {
            val activity: Activity? = host.hostActivity
            if (!enabled || activity == null) {
                onFail()
                return@ui
            }
            try {
                val signIn = PlayGames.getGamesSignInClient(activity)
                signIn.isAuthenticated.addOnCompleteListener { t ->
                    if (t.isSuccessful && t.result.isAuthenticated) {
                        run(activity, onFail, block)
                    } else {
                        signIn.signIn().addOnCompleteListener { t2 ->
                            if (t2.isSuccessful && t2.result.isAuthenticated) run(activity, onFail, block) else onFail()
                        }
                    }
                }
            } catch (t: Throwable) {
                Log.w(TAG, "Play Games loi: ${t.javaClass.simpleName}")
                onFail()
            }
        }
    }

    private fun run(activity: Activity, onFail: () -> Unit, block: (SnapshotsClient) -> Unit) {
        try {
            block(PlayGames.getSnapshotsClient(activity))
        } catch (t: Throwable) {
            Log.w(TAG, "Saved Games loi: ${t.javaClass.simpleName}")
            onFail()
        }
    }

    /** Cho ket qua mo/giai quyet snapshot, giai quyet xung dot toi da vai vong. onResult(null, null) neu that bai. */
    private fun openResolved(
        client: SnapshotsClient,
        task: Task<SnapshotsClient.DataOrConflict<Snapshot>>,
        attempt: Int,
        loser: String?,
        onResult: (Snapshot?, String?) -> Unit,
    ) {
        task.addOnCompleteListener { t ->
            try {
                if (!t.isSuccessful) {
                    onResult(null, null)
                    return@addOnCompleteListener
                }
                val res = t.result
                if (!res.isConflict) {
                    onResult(res.data, loser)
                    return@addOnCompleteListener
                }
                if (attempt >= MAX_CONFLICT_ROUNDS) {
                    onResult(null, null)
                    return@addOnCompleteListener
                }
                val conflict = res.conflict!!
                val a = conflict.snapshot
                val b = conflict.conflictingSnapshot
                val ja = read(a)
                val jb = read(b)
                val aWins = score(ja, a.metadata.lastModifiedTimestamp) >= score(jb, b.metadata.lastModifiedTimestamp)
                val winner = if (aWins) a else b
                val loserJson = if (aWins) jb else ja
                openResolved(client, client.resolveConflict(conflict.conflictId, winner), attempt + 1, loserJson, onResult)
            } catch (e: Throwable) {
                Log.w(TAG, "Xung dot cloud save loi: ${e.javaClass.simpleName}")
                onResult(null, null)
            }
        }
    }

    private fun read(s: Snapshot): String = try {
        String(s.snapshotContents.readFully(), Charsets.UTF_8)
    } catch (_: Throwable) {
        ""
    }

    /** Diem so de chon ban "choi nhieu hon": play_ms, runs, level, roi toi thoi diem sua. */
    private fun score(json: String, modified: Long): List<Long> {
        val o = Json.objectOrNull(json)
        return listOf(
            o?.optLong("play_ms", -1) ?: -1,
            o?.optLong("runs", -1) ?: -1,
            o?.optLong("level", -1) ?: -1,
            modified,
        )
    }

    private operator fun List<Long>.compareTo(other: List<Long>): Int {
        for (i in indices) {
            val c = this[i].compareTo(other[i])
            if (c != 0) return c
        }
        return 0
    }

    companion object {
        private const val TAG = PlatformConfig.TAG
        private const val META_APP_ID = "com.google.android.gms.games.APP_ID"
        private const val SNAP_NAME = "tbo_save"
        private const val MAX_CONFLICT_ROUNDS = 4
    }
}
