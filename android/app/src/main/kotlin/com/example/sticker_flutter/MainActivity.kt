package com.example.sticker_flutter

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
        private const val CHANNEL = "com.example.sticker_flutter/stickers"
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
        val intent = Intent("com.whatsapp.intent.action.ENABLE_ADD_PACK").apply {
            setPackage(targetPackage)
            putExtra(EXTRA_STICKER_PACK_ID, identifier)
            putExtra(EXTRA_STICKER_PACK_AUTHORITY, authority)
            putExtra(EXTRA_STICKER_PACK_NAME, name)
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
