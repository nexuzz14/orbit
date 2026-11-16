package id.my.nabilcf.orbit_app

import android.app.Notification
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * Membaca notifikasi HANYA dari aplikasi bank/e-wallet yang diaktifkan pengguna.
 * Tidak menulis log apa pun dan tidak menyimpan teks mentah secara permanen.
 */
class OrbitBankNotificationListener : NotificationListenerService() {

    private val amountHintRegex = Regex(
        "(rp\\.?|idr)\\s*\\d+",
        RegexOption.IGNORE_CASE
    )

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null) return
        if (!OrbitAutoCaptureStore.isBankListenerEnabled(applicationContext)) return
        val pkg = sbn.packageName ?: return
        if (!OrbitAutoCaptureStore.isPackageWhitelisted(applicationContext, pkg)) return

        val notification = sbn.notification ?: return
        if ((notification.flags and Notification.FLAG_GROUP_SUMMARY) != 0) return

        val extras = notification.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString()?.trim().orEmpty()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString()?.trim().orEmpty()
        val normalText = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString()?.trim().orEmpty()
        val body = if (bigText.isNotEmpty()) bigText else normalText

        if (title.isEmpty() && body.isEmpty()) return
        val combined = "$title $body".lowercase()

        // Abaikan OTP / login alert / promo sebelum masuk antrean sementara.
        if ((combined.contains("otp") ||
                combined.contains("kode verifikasi") ||
                combined.contains("kode rahasia") ||
                combined.contains("jangan berikan kode")) &&
            !combined.contains("berhasil") &&
            !combined.contains("sukses")
        ) {
            return
        }

        if (!amountHintRegex.containsMatchIn("$title $body")) return

        OrbitAutoCaptureStore.enqueueBankNotification(
            packageName = pkg,
            title = title,
            body = body,
            timestampMs = sbn.postTime
        )
    }
}
