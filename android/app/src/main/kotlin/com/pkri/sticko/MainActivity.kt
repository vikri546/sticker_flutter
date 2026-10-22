package com.pkri.sticko

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "MainActivity"
        private const val CHANNEL = "com.pkri.sticko/stickers"
        private const val ADD_PACK_REQUEST_CODE = 200

        private const val EXTRA_STICKER_PACK_ID = "sticker_pack_id"
        private const val EXTRA_STICKER_PACK_AUTHORITY = "sticker_pack_authority"
        private const val EXTRA_STICKER_PACK_NAME = "sticker_pack_name"

        private const val WHATSAPP_PACKAGE = "com.whatsapp"
        private const val WHATSAPP_BUSINESS_PACKAGE = "com.whatsapp.w4b"
        private const val WHITELIST_PROVIDER_SUFFIX = ".provider.sticker_whitelist_check"
    }

    private var pendingAddResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getStickersDirectory" -> {
                    try {
                        val dir = File(context.filesDir, "stickers")
                        if (!dir.exists()) {
                            dir.mkdirs()
                        }
                        result.success(dir.absolutePath)
                    } catch (e: Exception) {
                        result.error("STORAGE_ERROR", e.localizedMessage, null)
                    }
                }

                "checkWhatsAppInstalled" -> {
                    val isWaInstalled = isPackageInstalled(WHATSAPP_PACKAGE)
                    val isW4bInstalled = isPackageInstalled(WHATSAPP_BUSINESS_PACKAGE)
                    result.success(
                        mapOf(
                            "whatsapp" to isWaInstalled,
                            "whatsapp_business" to isW4bInstalled
                        )
                    )
                }

                "checkDetailedWhatsAppStatus" -> {
                    val isWaInstalled = isPackageInstalled(WHATSAPP_PACKAGE)
                    val waVersion = getPackageVersion(WHATSAPP_PACKAGE)
                    val isW4bInstalled = isPackageInstalled(WHATSAPP_BUSINESS_PACKAGE)
                    val w4bVersion = getPackageVersion(WHATSAPP_BUSINESS_PACKAGE)

                    val knownClones = listOf(
                        Pair("com.gbwhatsapp", "GBWhatsApp"),
                        Pair("com.whatsapp.plus", "WhatsApp Plus"),
                        Pair("com.fmwhatsapp", "FMWhatsApp"),
                        Pair("com.yowhatsapp", "YoWhatsApp"),
                        Pair("com.aero", "Aero WhatsApp"),
                        Pair("com.ogwhatsapp", "OGWhatsApp")
                    )

                    val detectedClones = mutableListOf<Map<String, String>>()
                    for ((pkg, name) in knownClones) {
                        if (isPackageInstalled(pkg)) {
                            detectedClones.add(
                                mapOf(
                                    "packageName" to pkg,
                                    "name" to name,
                                    "version" to (getPackageVersion(pkg) ?: "")
                                )
                            )
                        }
                    }

                    result.success(
                        mapOf(
                            "whatsapp" to isWaInstalled,
                            "whatsappVersion" to (waVersion ?: ""),
                            "whatsappBusiness" to isW4bInstalled,
                            "whatsappBusinessVersion" to (w4bVersion ?: ""),
                            "clones" to detectedClones
                        )
                    )
                }

                "openWhatsAppApp" -> {
                    val pkg = call.argument<String>("packageName") ?: WHATSAPP_PACKAGE
                    val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
                    if (launchIntent != null) {
                        launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(launchIntent)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }

                "openPlayStore" -> {
                    val pkg = call.argument<String>("packageName") ?: WHATSAPP_PACKAGE
                    try {
                        val marketIntent = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$pkg")).apply {
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(marketIntent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val webIntent = Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$pkg")).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(webIntent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("PLAYSTORE_ERROR", e2.localizedMessage, null)
                        }
                    }
                }

                "isStickerPackAdded" -> {
                    val identifier = call.argument<String>("identifier")
                    val isBusiness = call.argument<Boolean>("isBusiness") ?: false
                    if (identifier == null) {
                        result.error("INVALID_ARGUMENT", "Identifier cannot be null", null)
                        return@setMethodCallHandler
                    }
                    val targetPkg = if (isBusiness) WHATSAPP_BUSINESS_PACKAGE else WHATSAPP_PACKAGE
                    val isAdded = isWhitelisted(identifier, targetPkg)
                    result.success(isAdded)
                }

                "addStickerPack" -> {
                    val identifier = call.argument<String>("identifier")
                    val name = call.argument<String>("name")
                    val isBusiness = call.argument<Boolean>("isBusiness") ?: false
                    val targetPkg = if (isBusiness) WHATSAPP_BUSINESS_PACKAGE else WHATSAPP_PACKAGE

                    if (identifier == null || name == null) {
                        result.error("INVALID_ARGUMENT", "Identifier and name are required", null)
                        return@setMethodCallHandler
                    }

                    if (!isPackageInstalled(targetPkg)) {
                        result.success(
                            mapOf(
                                "status" to "error",
                                "message" to if (isBusiness) "WhatsApp Business belum terpasang di HP ini" else "WhatsApp belum terpasang di HP ini"
                            )
                        )
                        return@setMethodCallHandler
                    }

                    pendingAddResult = result
                    launchAddPackIntent(identifier, name, targetPkg)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun isPackageInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    private fun getPackageVersion(packageName: String): String? {
        return try {
            val pInfo = packageManager.getPackageInfo(packageName, 0)
            pInfo.versionName
        } catch (e: PackageManager.NameNotFoundException) {
            null
        }
    }

    private fun isWhitelisted(identifier: String, targetPackage: String): Boolean {
        return try {
            val authority = "${context.packageName}.stickercontentprovider"
            val uri = Uri.parse("content://$targetPackage$WHITELIST_PROVIDER_SUFFIX/is_whitelisted")
                .buildUpon()
                .appendQueryParameter("authority", authority)
                .appendQueryParameter("identifier", identifier)
                .build()

            val cursor = contentResolver.query(uri, arrayOf("result"), null, null, null)
            cursor?.use {
                if (it.moveToFirst()) {
                    val resultIndex = it.getColumnIndex("result")
                    if (resultIndex != -1) {
                        return it.getInt(resultIndex) == 1
                    }
                }
            }
            false
        } catch (e: Exception) {
            Log.w(TAG, "Failed to check sticker whitelist status", e)
            false
        }
    }

    private fun launchAddPackIntent(identifier: String, name: String, targetPackage: String) {
        val authority = "${context.packageName}.stickercontentprovider"
        val intent = Intent("com.whatsapp.intent.action.ENABLE_STICKER_PACK").apply {
            setPackage(targetPackage)
            putExtra(EXTRA_STICKER_PACK_ID, identifier)
            putExtra(EXTRA_STICKER_PACK_AUTHORITY, authority)
            putExtra(EXTRA_STICKER_PACK_NAME, name)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        try {
            startActivityForResult(intent, ADD_PACK_REQUEST_CODE)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start WhatsApp sticker intent", e)
            pendingAddResult?.success(
                mapOf(
                    "status" to "error",
                    "message" to "Gagal membuka WhatsApp: ${e.localizedMessage}"
                )
            )
            pendingAddResult = null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == ADD_PACK_REQUEST_CODE) {
            val result = pendingAddResult ?: return
            pendingAddResult = null

            when (resultCode) {
                Activity.RESULT_OK -> {
                    result.success(
                        mapOf(
                            "status" to "success",
                            "message" to "Paket stiker berhasil ditambahkan ke WhatsApp!"
                        )
                    )
                }

                Activity.RESULT_CANCELED -> {
                    val validationError = data?.getStringExtra("validation_error")
                    if (validationError != null) {
                        Log.e(TAG, "WhatsApp validation error: $validationError")
                        result.success(
                            mapOf(
                                "status" to "error",
                                "message" to "Validasi WhatsApp gagal: $validationError"
                            )
                        )
                    } else {
                        result.success(
                            mapOf(
                                "status" to "cancelled",
                                "message" to "Penambahan stiker dibatalkan oleh pengguna."
                            )
                        )
                    }
                }

                else -> {
                    result.success(
                        mapOf(
                            "status" to "error",
                            "message" to "Hasil tidak diketahui dari WhatsApp (kode: $resultCode)"
                        )
                    )
                }
            }
        }
    }
}
