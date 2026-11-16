package id.my.nabilcf.orbit_app

import android.content.ComponentName
import android.content.Context
import android.provider.Settings
import java.util.concurrent.ConcurrentLinkedQueue

/**
 * Penyimpanan konfigurasi whitelist dan antrean memori sementara (ephemeral).
 * Data notifikasi bank dan konten share tidak pernah dicetak ke log atau disimpan permanen ke disk.
 */
object OrbitAutoCaptureStore {
    private const val PREFS_NAME = "orbit_auto_capture_prefs"
    private const val KEY_LISTENER_ENABLED = "bank_listener_enabled"
    private const val KEY_WHITELIST_PACKAGES = "whitelisted_packages"
    private const val MAX_QUEUE_SIZE = 20

    private val defaultPackages = setOf(
        "com.bca",
        "com.bca.mybca.omni.android",
        "id.bmri.livin",
        "src.com.bni",
        "id.co.bni.wondr",
        "id.co.bri.brimo",
        "com.gojek.app",
        "com.gopay.app",
        "ovo.id",
        "id.dana",
        "com.shopee.id",
        "com.shopeepay.id"
    )

    private val pendingBankNotifications = ConcurrentLinkedQueue<Map<String, Any>>()
    private val pendingShares = ConcurrentLinkedQueue<Map<String, Any>>()

    @Volatile
    var onBankNotificationQueued: (() -> Unit)? = null

    @Volatile
    var onShareQueued: (() -> Unit)? = null

    @Volatile
    var pendingQuickAddAction: String? = null

    @Volatile
    var pendingOpenRoute: Map<String, String?>? = null

    fun setBankListenerEnabled(context: Context, enabled: Boolean) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_LISTENER_ENABLED, enabled)
            .apply()
    }

    fun isBankListenerEnabled(context: Context): Boolean {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getBoolean(KEY_LISTENER_ENABLED, false)
    }

    fun setWhitelistedPackages(context: Context, packages: List<String>) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putStringSet(KEY_WHITELIST_PACKAGES, packages.toSet())
            .apply()
    }

    fun getWhitelistedPackages(context: Context): Set<String> {
        val saved = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getStringSet(KEY_WHITELIST_PACKAGES, null)
        return saved ?: defaultPackages
    }

    fun isPackageWhitelisted(context: Context, packageName: String?): Boolean {
        if (packageName.isNullOrBlank()) return false
        return getWhitelistedPackages(context).contains(packageName)
    }

    fun isNotificationServiceGranted(context: Context): Boolean {
        val enabledListeners = Settings.Secure.getString(
            context.contentResolver,
            "enabled_notification_listeners"
        ) ?: return false
        val target = ComponentName(context, OrbitBankNotificationListener::class.java)
            .flattenToString()
        val shortTarget = "${context.packageName}/${OrbitBankNotificationListener::class.java.name}"
        return enabledListeners.contains(target) || enabledListeners.contains(shortTarget)
    }

    fun enqueueBankNotification(packageName: String, title: String, body: String, timestampMs: Long) {
        while (pendingBankNotifications.size >= MAX_QUEUE_SIZE) {
            pendingBankNotifications.poll()
        }
        pendingBankNotifications.add(
            mapOf(
                "packageName" to packageName,
                "title" to title.take(120),
                "body" to body.take(360),
                "timestampMs" to timestampMs
            )
        )
        onBankNotificationQueued?.invoke()
    }

    fun drainBankNotifications(): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        while (true) {
            val item = pendingBankNotifications.poll() ?: break
            list.add(item)
        }
        return list
    }

    fun enqueueShare(payload: Map<String, Any>) {
        while (pendingShares.size >= MAX_QUEUE_SIZE) {
            pendingShares.poll()
        }
        pendingShares.add(payload)
        onShareQueued?.invoke()
    }

    fun drainShares(): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        while (true) {
            val item = pendingShares.poll() ?: break
            list.add(item)
        }
        return list
    }
}
