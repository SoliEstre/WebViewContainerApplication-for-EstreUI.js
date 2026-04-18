// package your.package.name

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.NotificationChannelGroup
import android.content.ActivityNotFoundException
import android.content.Intent
import android.content.res.Configuration
import android.media.AudioAttributes
import android.os.Build
import android.provider.Settings
import android.net.Uri
import androidx.annotation.RequiresApi
import com.android.installreferrer.api.*
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.net.toUri

class MainActivity: FlutterActivity() {
    companion object {
        const val APP_DEFAULT = "app_default"
    }

    var isForeground: Boolean = false

    override fun onStart() {
        super.onStart()
        isForeground = true
    }

    override fun onStop() {
        isForeground = false
        super.onStop()
    }

    override fun onLowMemory() {
        super.onLowMemory()

        if (!isForeground) finish()
    }

    override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean, newConfig: Configuration?) {
        super.onMultiWindowModeChanged(isInMultiWindowMode, newConfig)

        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, APP_DEFAULT).invokeMethod(
                "onMultiWindowModeChanged",
                mapOf("isInMultiWindowMode" to isInMultiWindowMode)
            )
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

//        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) createCustomNotificationChannel()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_DEFAULT).setMethodCallHandler { call, result ->
            when (call.method) {
                // Get install referrer URL
                "getInstallReferrer" -> {
                    getInstallReferrer(result)
                }

                "isInMultiWindowMode" -> {
                    result.success(this.isInMultiWindowMode)
                }

                "callAppByIntentUrl" -> {
                    val url: String = call.argument("url")!!

                    try {
                        val intent = Intent.parseUri(url, Intent.URI_INTENT_SCHEME)
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

                        try {
                            // Launch app if installed
                            startActivity(intent)
                            result.success(true)
                        } catch (e: ActivityNotFoundException) {
                            // If app not found, navigate to fallback URL or market
                            val fallbackUrl = intent.getStringExtra("fallbackUrl")

                            if (fallbackUrl != null) {
                                // Navigate to fallback URL if available
                                val fallbackIntent = Intent(Intent.ACTION_VIEW, fallbackUrl.toUri())
                                startActivity(fallbackIntent)
                                result.success(false)
                            } else {
                                // Navigate to market
                                val packageName = intent.getPackage()
                                if (packageName != null) {
                                    val marketIntent = Intent(Intent.ACTION_VIEW, "market://details?id=$packageName".toUri())
                                    startActivity(marketIntent)
                                    result.success(false)
                                } else {
                                    result.error("NO_PACKAGE", "No package found in intent", null)
                                }
                            }
                        }
                    } catch (e: Exception) {
                        result.error("CALL_APP_ERROR", e.message, null)
                    }
                }

                // Convert Intent scheme URL to be accessible from Android WebView
                "getAppUrl" -> {
                    val url: String = call.argument("url")!!

                    val intent = Intent.parseUri(url, Intent.URI_INTENT_SCHEME)
                    // May return null here

                    result.success(intent.dataString)
                }

                // Convert Intent scheme URL to Play Store market URL
                "getMarketUrl" -> {
                    val url: String = call.argument("url")!!
                    val packageName = Intent.parseUri(url, Intent.URI_INTENT_SCHEME).getPackage()
                    val marketUrl = Intent(
                        Intent.ACTION_VIEW,
                        "market://details?id=$packageName".toUri()
                    )
                    result.success(marketUrl.dataString)
                }

                // Navigate to power saving exception settings
                "openPowerSavingExceptionSettings" -> {
                    try {
                        openPowerSavingExceptionSettings()
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("POWER_SAVING_ERROR", e.message, null)
                    }
                }

//                else -> {
//                    result.notImplemented()
//                }
            }
        }
    }

    @RequiresApi(Build.VERSION_CODES.O)
    private fun createCustomNotificationChannel() {
        val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        // vv Replace with your OneSignal notification group id (from OneSignal dashboard)
        val groupId = "Enter_Your_OneSignal_Group_ID_Here"
        // vv Replace with your adopter app's group name (snake_case)
        val groupName = "your_app"
        notificationManager.createNotificationChannelGroup(NotificationChannelGroup(groupId, groupName))

        // vv Replace with your OneSignal notification channel id (from OneSignal dashboard)
        val channelId = "Enter_Your_OneSignal_Channel_ID_Here"
        // vv Replace with your push channel name (snake_case)
        val channelName = "your_app_push"
        val importance = NotificationManager.IMPORTANCE_HIGH

        // Delete existing channel and recreate (to change sound settings)
        val existing = notificationManager.getNotificationChannel(channelId)
        if (existing != null) {
            notificationManager.deleteNotificationChannel(channelId)
        }

        val channel = NotificationChannel(channelId, channelName, importance).apply {
            // vv Replace with your adopter app's user-facing notification description
            description = "Your App Notifications"

            // Sound settings - prioritize .wav file, use default notification sound if not available
            val soundUri = try {
                // vv Replace with your custom notification sound asset at android/app/src/main/res/raw/<name>.wav
                val wavUri = "android.resource://$packageName/raw/your_notification_sound".toUri()
                contentResolver.openInputStream(wavUri)?.close()
                wavUri
            } catch (e: Exception) {
                android.provider.Settings.System.DEFAULT_NOTIFICATION_URI
            }

            setSound(soundUri, AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                // Set to follow notification volume instead of media volume
                .setLegacyStreamType(android.media.AudioManager.STREAM_NOTIFICATION)
//                .setFlags(AudioAttributes.FLAG_AUDIBILITY_ENFORCED) // Using this plays through media (media volume)
                .build())

            enableVibration(true)
            vibrationPattern = longArrayOf(0, 250, 250, 250)
            setShowBadge(true)
            group = groupId
        }

        notificationManager.createNotificationChannel(channel)
    }

    private fun getInstallReferrer(result: MethodChannel.Result) {
        val referrerClient = InstallReferrerClient.newBuilder(this).build()

        referrerClient.startConnection(object : InstallReferrerStateListener {
            override fun onInstallReferrerSetupFinished(responseCode: Int) {
                when (responseCode) {
                    InstallReferrerClient.InstallReferrerResponse.OK -> {
                        try {
                            val response = referrerClient.installReferrer
                            val referrerUrl = response.installReferrer
                            val clickTime = response.referrerClickTimestampSeconds
                            val installTime = response.installBeginTimestampSeconds
                            val installTimeServer = response.installBeginTimestampServerSeconds

                            val referrerData = mapOf<String, Any>(
                                "referrerUrl" to referrerUrl,
                                "clickTime" to clickTime,
                                "installTime" to installTime,
                                "installTimeServer" to installTimeServer,
                            )

                            result.success(referrerData)
                        } catch (e: Exception) {
                            result.error("REFERRER_ERROR", e.message, null)
                        } finally {
                            referrerClient.endConnection()
                        }
                    }
                    InstallReferrerClient.InstallReferrerResponse.FEATURE_NOT_SUPPORTED -> {
                        result.error("NOT_SUPPORTED", "Install Referrer not supported", null)
                        referrerClient.endConnection()
                    }
                    InstallReferrerClient.InstallReferrerResponse.SERVICE_UNAVAILABLE -> {
                        result.error("SERVICE_UNAVAILABLE", "Install Referrer service unavailable", null)
                        referrerClient.endConnection()
                    }
                }
            }

            override fun onInstallReferrerServiceDisconnected() {
                result.error("DISCONNECTED", "Install Referrer service disconnected", null)
            }
        })
    }

    private fun openPowerSavingExceptionSettings() {
        val packageName = packageName
        val manufacturer = Build.MANUFACTURER.lowercase()

        try {
            when (manufacturer) {
                "xiaomi" -> {
                    // MIUI auto start management
                    val intent = Intent().apply {
                        component = android.content.ComponentName(
                            "com.miui.securitycenter",
                            "com.miui.permcenter.autostart.AutoStartManagementActivity"
                        )
                        putExtra("extra_pkgname", packageName)
                    }
                    startActivity(intent)
                }
                "oppo" -> {
                    // ColorOS auto start management
                    try {
                        val intent = Intent().apply {
                            component = android.content.ComponentName(
                                "com.coloros.safecenter",
                                "com.coloros.safecenter.permission.startup.StartupAppListActivity"
                            )
                        }
                        startActivity(intent)
                    } catch (e: Exception) {
                        // Alternative method
                        val intent = Intent().apply {
                            component = android.content.ComponentName(
                                "com.oppo.safe",
                                "com.oppo.safe.permission.startup.StartupAppListActivity"
                            )
                        }
                        startActivity(intent)
                    }
                }
                "vivo" -> {
                    // Funtouch OS auto start management
                    val intent = Intent().apply {
                        component = android.content.ComponentName(
                            "com.iqoo.secure",
                            "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"
                        )
                        putExtra("packageName", packageName)
                    }
                    startActivity(intent)
                }
                "huawei", "honor" -> {
                    // EMUI protected apps
                    try {
                        val intent = Intent().apply {
                            component = android.content.ComponentName(
                                "com.huawei.systemmanager",
                                "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity"
                            )
                        }
                        startActivity(intent)
                    } catch (e: Exception) {
                        // Alternative method
                        val intent = Intent().apply {
                            component = android.content.ComponentName(
                                "com.huawei.systemmanager",
                                "com.huawei.systemmanager.optimize.process.ProtectActivity"
                            )
                        }
                        startActivity(intent)
                    }
                }
                "oneplus" -> {
                    // OnePlus battery optimization
                    val intent = Intent().apply {
                        component = android.content.ComponentName(
                            "com.oneplus.security",
                            "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity"
                        )
                    }
                    startActivity(intent)
                }
                "samsung" -> {
                    // Samsung battery optimization exception
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                    } else {
                        // Navigate to Samsung Smart Manager
                        try {
                            val intent = Intent().apply {
                                component = android.content.ComponentName(
                                    "com.samsung.android.sm_cn",
                                    "com.samsung.android.sm.ui.ram.AutoRunActivity"
                                )
                            }
                            startActivity(intent)
                        } catch (e: Exception) {
                            openBatteryOptimizationSettings()
                        }
                    }
                }
                else -> {
                    // Default battery optimization settings
                    openBatteryOptimizationSettings()
                }
            }
        } catch (e: Exception) {
            // If all attempts fail, navigate to battery optimization settings
            openBatteryOptimizationSettings()
        }
    }

    private fun openBatteryOptimizationSettings() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            } else {
                // For Android below 6.0, navigate to app info screen
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            }
        } catch (e: Exception) {
            // Last resort: app info screen
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:$packageName")
            }
            startActivity(intent)
        }
    }
}