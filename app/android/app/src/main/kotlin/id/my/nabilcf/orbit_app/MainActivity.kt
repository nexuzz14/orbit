package id.my.nabilcf.orbit_app

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import androidx.activity.result.contract.ActivityResultContracts
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterFragmentActivity() {

    companion object {
        private const val CHANNEL_HOME_WIDGET = "id.my.nabilcf.orbit/home_widget"
        private const val CHANNEL_AUTO_CAPTURE = "id.my.nabilcf.orbit/auto_capture"
        private const val CHANNEL_BIOMETRIC = "id.my.nabilcf.orbit/biometric"
        private const val CHANNEL_MLKIT_OCR = "id.my.nabilcf.orbit/mlkit_ocr"

        private val ALLOWED_IMAGE_MIMES = setOf(
            "image/jpeg",
            "image/jpg",
            "image/png",
            "image/webp"
        )
        private const val MAX_IMAGE_BYTES = 20L * 1024L * 1024L
    }

    private var homeWidgetChannel: MethodChannel? = null
    private var autoCaptureChannel: MethodChannel? = null
    private var pendingImagePickResult: MethodChannel.Result? = null
    private val ioExecutor = Executors.newSingleThreadExecutor()

    private val receiptImagePickerLauncher =
        registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri: Uri? ->
            val callback = pendingImagePickResult
            pendingImagePickResult = null
            if (callback == null) return@registerForActivityResult
            if (uri == null) {
                callback.success(null)
                return@registerForActivityResult
            }
            ioExecutor.execute {
                val resolvedMime = (contentResolver.getType(uri) ?: "").lowercase().trim()
                val tempFile = if (resolvedMime in ALLOWED_IMAGE_MIMES) {
                    copyUriToTempCacheFile(uri, resolvedMime, "orbit_picked_receipt")
                } else {
                    null
                }
                runOnUiThread {
                    callback.success(tempFile?.absolutePath)
                }
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Proteksi FLAG_SECURE pada window aplikasi keuangan (PRD 9.9)
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
        OrbitBackgroundWorker.schedulePeriodic(applicationContext)
        handleIncomingIntent(intent, fromOnNewIntent = false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIncomingIntent(intent, fromOnNewIntent = true)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        homeWidgetChannel = MethodChannel(messenger, CHANNEL_HOME_WIDGET).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "updateWidgetData" -> {
                        @Suppress("UNCHECKED_CAST")
                        val payload = call.arguments as? Map<String, Any?> ?: emptyMap()
                        OrbitWidgetStore.saveSnapshot(applicationContext, payload)
                        result.success(true)
                    }
                    "triggerPeriodicSyncNow" -> {
                        OrbitBackgroundWorker.schedulePeriodic(applicationContext)
                        OrbitBackgroundWorker.enqueueOneTime(applicationContext)
                        result.success(true)
                    }
                    "consumePendingQuickAddAction" -> {
                        val pending = OrbitAutoCaptureStore.pendingQuickAddAction
                        OrbitAutoCaptureStore.pendingQuickAddAction = null
                        result.success(pending)
                    }
                    "consumePendingOpenRoute" -> {
                        val pending = OrbitAutoCaptureStore.pendingOpenRoute
                        OrbitAutoCaptureStore.pendingOpenRoute = null
                        result.success(pending)
                    }
                    "consumePendingCompletedTaskIds" -> {
                        result.success(OrbitWidgetStore.drainPendingCompletedTaskIds(applicationContext))
                    }
                    "openMailto" -> {
                        val subject = call.argument<String>("subject") ?: "Ringkasan Mingguan Orbit"
                        val body = call.argument<String>("body") ?: ""
                        val mailUri = Uri.parse(
                            "mailto:?subject=" + Uri.encode(subject) + "&body=" + Uri.encode(body)
                        )
                        val mailIntent = Intent(Intent.ACTION_SENDTO, mailUri)
                        val opened = runCatching {
                            startActivity(mailIntent)
                            true
                        }.getOrDefault(false)
                        result.success(opened)
                    }
                    else -> result.notImplemented()
                }
            }
        }

        autoCaptureChannel = MethodChannel(messenger, CHANNEL_AUTO_CAPTURE).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "isNotificationListenerEnabled" -> {
                        result.success(
                            OrbitAutoCaptureStore.isNotificationServiceGranted(applicationContext)
                        )
                    }
                    "openNotificationListenerSettings" -> {
                        val opened = runCatching {
                            val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            true
                        }.getOrDefault(false)
                        result.success(opened)
                    }
                    "setBankListenerEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        OrbitAutoCaptureStore.setBankListenerEnabled(applicationContext, enabled)
                        result.success(true)
                    }
                    "setWhitelistedPackages" -> {
                        val packages = call.argument<List<String>>("packages") ?: emptyList()
                        OrbitAutoCaptureStore.setWhitelistedPackages(applicationContext, packages)
                        result.success(true)
                    }
                    "consumePendingBankNotifications" -> {
                        result.success(OrbitAutoCaptureStore.drainBankNotifications())
                    }
                    "consumePendingShares" -> {
                        result.success(OrbitAutoCaptureStore.drainShares())
                    }
                    "pickReceiptImage" -> {
                        if (pendingImagePickResult != null) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        pendingImagePickResult = result
                        val launched = runCatching {
                            receiptImagePickerLauncher.launch(
                                arrayOf("image/jpeg", "image/png", "image/webp")
                            )
                            true
                        }.getOrDefault(false)
                        if (!launched) {
                            val failedCb = pendingImagePickResult
                            pendingImagePickResult = null
                            failedCb?.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }

        OrbitAutoCaptureStore.onBankNotificationQueued = {
            runOnUiThread {
                autoCaptureChannel?.invokeMethod("onBankNotificationQueued", null)
            }
        }
        OrbitAutoCaptureStore.onShareQueued = {
            runOnUiThread {
                autoCaptureChannel?.invokeMethod("onShareReceived", null)
            }
        }

        MethodChannel(messenger, CHANNEL_BIOMETRIC).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> {
                    val manager = BiometricManager.from(applicationContext)
                    val authenticators =
                        BiometricManager.Authenticators.BIOMETRIC_STRONG or
                            BiometricManager.Authenticators.BIOMETRIC_WEAK
                    val status = manager.canAuthenticate(authenticators)
                    result.success(status == BiometricManager.BIOMETRIC_SUCCESS)
                }
                "authenticate" -> {
                    val title = call.argument<String>("title") ?: "Buka Kunci Orbit"
                    val subtitle =
                        call.argument<String>("subtitle") ?: "Verifikasi identitas untuk melanjutkan"
                    showBiometricPrompt(title, subtitle, result)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, CHANNEL_MLKIT_OCR).setMethodCallHandler { call, result ->
            when (call.method) {
                "recognizeText" -> {
                    val path = call.argument<String>("path")?.trim().orEmpty()
                    if (path.isEmpty()) {
                        result.error("INVALID_PATH", "Berkas gambar struk tidak valid.", null)
                        return@setMethodCallHandler
                    }
                    val file = File(path)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "Berkas gambar struk tidak ditemukan.", null)
                        return@setMethodCallHandler
                    }
                    runMlKitOcr(file, result)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        OrbitAutoCaptureStore.onBankNotificationQueued = null
        OrbitAutoCaptureStore.onShareQueued = null
        ioExecutor.shutdown()
        super.onDestroy()
    }

    private fun showBiometricPrompt(
        title: String,
        subtitle: String,
        result: MethodChannel.Result
    ) {
        val replied = AtomicBoolean(false)
        val executor = ContextCompat.getMainExecutor(this)
        val authenticators =
            BiometricManager.Authenticators.BIOMETRIC_STRONG or
                BiometricManager.Authenticators.BIOMETRIC_WEAK

        val prompt = BiometricPrompt(
            this,
            executor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                    if (replied.compareAndSet(false, true)) {
                        result.success(true)
                    }
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    if (replied.compareAndSet(false, true)) {
                        result.success(false)
                    }
                }
            }
        )

        val promptInfo = BiometricPrompt.PromptInfo.Builder()
            .setTitle(title)
            .setSubtitle(subtitle)
            .setNegativeButtonText("Gunakan PIN")
            .setAllowedAuthenticators(authenticators)
            .build()

        runCatching {
            prompt.authenticate(promptInfo)
        }.onFailure {
            if (replied.compareAndSet(false, true)) {
                result.success(false)
            }
        }
    }

    private fun runMlKitOcr(file: File, result: MethodChannel.Result) {
        val image = try {
            InputImage.fromFilePath(applicationContext, Uri.fromFile(file))
        } catch (e: Exception) {
            result.error("OCR_INPUT_ERROR", e.localizedMessage ?: "Gagal memuat gambar struk.", null)
            return
        }

        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
        recognizer.process(image)
            .addOnSuccessListener { visionText ->
                runCatching { recognizer.close() }
                result.success(visionText.text)
            }
            .addOnFailureListener { err ->
                runCatching { recognizer.close() }
                result.error("OCR_ERROR", err.localizedMessage ?: "Gagal membaca teks struk.", null)
            }
    }

    private fun handleIncomingIntent(incoming: Intent?, fromOnNewIntent: Boolean) {
        if (incoming == null) return
        val action = incoming.action ?: return

        if (action == Intent.ACTION_VIEW) {
            val uri = incoming.data ?: return
            if (uri.scheme == "io.supabase.orbit" && uri.host == "quick-add") {
                val quickType = uri.getQueryParameter("type")?.lowercase()?.trim()
                if (quickType == "transaction" || quickType == "task" || quickType == "receipt" || quickType == "event") {
                    if (fromOnNewIntent && homeWidgetChannel != null) {
                        homeWidgetChannel?.invokeMethod("onQuickAddAction", quickType)
                    } else {
                        OrbitAutoCaptureStore.pendingQuickAddAction = quickType
                    }
                }
            } else if (uri.scheme == "io.supabase.orbit" && uri.host == "open") {
                val tab = uri.getQueryParameter("tab")?.lowercase()?.trim().orEmpty().ifEmpty { "today" }
                val id = uri.getQueryParameter("id")?.trim()
                val routePayload = mapOf("tab" to tab, "id" to id)
                if (fromOnNewIntent && homeWidgetChannel != null) {
                    homeWidgetChannel?.invokeMethod("onOpenWidgetRoute", routePayload)
                } else {
                    OrbitAutoCaptureStore.pendingOpenRoute = routePayload
                }
            }
            return
        }

        if (action == Intent.ACTION_SEND) {
            val rawMime = incoming.type?.lowercase()?.trim().orEmpty()
            if (rawMime == "text/plain") {
                val sharedText = incoming.getStringExtra(Intent.EXTRA_TEXT)?.trim().orEmpty()
                if (sharedText.isNotEmpty()) {
                    OrbitAutoCaptureStore.enqueueShare(
                        mapOf(
                            "mimeType" to "text/plain",
                            "text" to sharedText
                        )
                    )
                }
                return
            }

            val streamUri: Uri? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                incoming.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
            } else {
                @Suppress("DEPRECATION")
                incoming.getParcelableExtra(Intent.EXTRA_STREAM)
            }

            if (streamUri != null) {
                val contentMime = (contentResolver.getType(streamUri) ?: rawMime).lowercase().trim()
                if (contentMime !in ALLOWED_IMAGE_MIMES) {
                    OrbitAutoCaptureStore.enqueueShare(mapOf("mimeType" to contentMime))
                    return
                }
                ioExecutor.execute {
                    val tempFile = copyUriToTempCacheFile(
                        streamUri,
                        contentMime,
                        "orbit_share_receipt"
                    )
                    if (tempFile != null) {
                        OrbitAutoCaptureStore.enqueueShare(
                            mapOf(
                                "mimeType" to contentMime,
                                "filePath" to tempFile.absolutePath
                            )
                        )
                    }
                }
            } else if (rawMime.isNotEmpty()) {
                OrbitAutoCaptureStore.enqueueShare(mapOf("mimeType" to rawMime))
            }
        }
    }

    private fun copyUriToTempCacheFile(uri: Uri, mimeType: String, prefix: String): File? {
        val ext = when (mimeType) {
            "image/png" -> "png"
            "image/webp" -> "webp"
            else -> "jpg"
        }
        val outFile = File(cacheDir, "${prefix}_${System.nanoTime()}.$ext")
        return try {
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(outFile).use { output ->
                    val buffer = ByteArray(8192)
                    var total = 0L
                    while (true) {
                        val read = input.read(buffer)
                        if (read <= 0) break
                        total += read
                        if (total > MAX_IMAGE_BYTES) {
                            throw IllegalStateException("Ukuran gambar melebihi batas.")
                        }
                        output.write(buffer, 0, read)
                    }
                    output.flush()
                }
            } ?: run {
                runCatching { outFile.delete() }
                return null
            }
            outFile
        } catch (_: Exception) {
            runCatching { outFile.delete() }
            null
        }
    }
}
