package com.pkri.sticko

import android.content.ContentProvider
import android.content.ContentValues
import android.content.UriMatcher
import android.content.res.AssetFileDescriptor
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.io.FileNotFoundException

class StickerContentProvider : ContentProvider() {

    companion object {
        private const val TAG = "StickerProvider"

        private const val METADATA_CODE = 1
        private const val METADATA_CODE_FOR_SINGLE_PACK = 2
        private const val STICKERS_CODE = 3
        private const val STICKERS_ASSET_CODE = 4
        private const val STICKER_PACK_TRAY_ICON_CODE = 5

        // Exact column names required by WhatsApp
        const val STICKER_PACK_IDENTIFIER_IN_QUERY = "sticker_pack_identifier"
        const val STICKER_PACK_NAME_IN_QUERY = "sticker_pack_name"
        const val STICKER_PACK_PUBLISHER_IN_QUERY = "sticker_pack_publisher"
        const val STICKER_PACK_ICON_IN_QUERY = "sticker_pack_icon"
        const val ANDROID_APP_DOWNLOAD_LINK_IN_QUERY = "android_play_store_link"
        const val IOS_APP_DOWNLOAD_LINK_IN_QUERY = "ios_app_download_link"
        const val PUBLISHER_EMAIL = "sticker_pack_publisher_email"
        const val PUBLISHER_WEBSITE = "sticker_pack_publisher_website"
        const val PRIVACY_POLICY_WEBSITE = "sticker_pack_privacy_policy_website"
        const val LICENSE_AGREEMENT_WEBSITE = "sticker_pack_license_agreement_website"
        const val IMAGE_DATA_VERSION = "image_data_version"
        const val AVOID_CACHE = "whatsapp_will_not_cache_stickers"
        const val ANIMATED_STICKER_PACK = "animated_sticker_pack"

        const val STICKER_FILE_NAME_IN_QUERY = "sticker_file_name"
        const val STICKER_FILE_EMOJI_IN_QUERY = "sticker_emoji"
    }

    private val uriMatcher = UriMatcher(UriMatcher.NO_MATCH)

    override fun onCreate(): Boolean {
        val authority = "${context?.packageName}.stickercontentprovider"
        uriMatcher.addURI(authority, "metadata", METADATA_CODE)
        uriMatcher.addURI(authority, "metadata/*", METADATA_CODE_FOR_SINGLE_PACK)
        uriMatcher.addURI(authority, "stickers_metadata", METADATA_CODE)
        uriMatcher.addURI(authority, "stickers_metadata/*", METADATA_CODE_FOR_SINGLE_PACK)
        uriMatcher.addURI(authority, "stickers/*", STICKERS_CODE)
        uriMatcher.addURI(authority, "stickers_asset/*/*", STICKERS_ASSET_CODE)
        uriMatcher.addURI(authority, "stickers_asset/*", STICKER_PACK_TRAY_ICON_CODE)
        return true
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?
    ): Cursor? {
        val match = uriMatcher.match(uri)
        Log.d(TAG, "query called with uri: $uri, match: $match")

        return when (match) {
            METADATA_CODE -> getPackMetadataCursor(null)
            METADATA_CODE_FOR_SINGLE_PACK -> {
                val packIdentifier = uri.lastPathSegment
                getPackMetadataCursor(packIdentifier)
            }
            STICKERS_CODE -> {
                val packIdentifier = uri.lastPathSegment
                getStickersCursor(packIdentifier)
            }
            else -> throw IllegalArgumentException("Unknown URI: $uri")
        }
    }

    private fun getContentsJson(): JSONObject? {
        val ctx = context ?: return null
        val file = File(ctx.filesDir, "stickers/contents.json")
        if (!file.exists()) {
            Log.w(TAG, "contents.json does not exist yet at ${file.absolutePath}")
            return null
        }
        return try {
            JSONObject(file.readText())
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse contents.json", e)
            null
        }
    }

    private fun getPackMetadataCursor(targetIdentifier: String?): Cursor {
        val columns = arrayOf(
            STICKER_PACK_IDENTIFIER_IN_QUERY,
            STICKER_PACK_NAME_IN_QUERY,
            STICKER_PACK_PUBLISHER_IN_QUERY,
            STICKER_PACK_ICON_IN_QUERY,
            ANDROID_APP_DOWNLOAD_LINK_IN_QUERY,
            IOS_APP_DOWNLOAD_LINK_IN_QUERY,
            PUBLISHER_EMAIL,
            PUBLISHER_WEBSITE,
            PRIVACY_POLICY_WEBSITE,
            LICENSE_AGREEMENT_WEBSITE,
            IMAGE_DATA_VERSION,
            AVOID_CACHE,
            ANIMATED_STICKER_PACK
        )
        val cursor = MatrixCursor(columns)
        val json = getContentsJson() ?: return cursor

        val androidPlayStoreLink = json.optString("android_play_store_link", "")
        val iosAppStoreLink = json.optString("ios_app_store_link", "")
        val stickerPacks = json.optJSONArray("sticker_packs") ?: JSONArray()

        for (i in 0 until stickerPacks.length()) {
            val pack = stickerPacks.getJSONObject(i)
            val identifier = pack.optString("identifier")
            if (targetIdentifier != null && identifier != targetIdentifier) {
                continue
            }
            cursor.addRow(
                arrayOf(
                    identifier,
                    pack.optString("name", "Stickers"),
                    pack.optString("publisher", "User"),
                    pack.optString("tray_image_file", "tray.png"),
                    androidPlayStoreLink,
                    iosAppStoreLink,
                    pack.optString("publisher_email", ""),
                    pack.optString("publisher_website", ""),
                    pack.optString("privacy_policy_website", ""),
                    pack.optString("license_agreement_website", ""),
                    pack.optString("image_data_version", "1"),
                    if (pack.optBoolean("avoid_cache", false)) 1 else 0,
                    if (pack.optBoolean("animated_sticker_pack", false)) 1 else 0
                )
            )
        }
        return cursor
    }

    private fun getStickersCursor(packIdentifier: String?): Cursor {
        val columns = arrayOf(
            STICKER_FILE_NAME_IN_QUERY,
            STICKER_FILE_EMOJI_IN_QUERY
        )
        val cursor = MatrixCursor(columns)
        if (packIdentifier == null) return cursor

        val json = getContentsJson() ?: return cursor
        val stickerPacks = json.optJSONArray("sticker_packs") ?: JSONArray()

        for (i in 0 until stickerPacks.length()) {
            val pack = stickerPacks.getJSONObject(i)
            if (pack.optString("identifier") == packIdentifier) {
                val stickers = pack.optJSONArray("stickers") ?: JSONArray()
                for (j in 0 until stickers.length()) {
                    val sticker = stickers.getJSONObject(j)
                    val fileName = sticker.optString("image_file")
                    val emojisArray = sticker.optJSONArray("emojis") ?: JSONArray()
                    val emojisList = mutableListOf<String>()
                    for (k in 0 until emojisArray.length()) {
                        emojisList.add(emojisArray.getString(k))
                    }
                    val emojisString = emojisList.joinToString(",")
                    cursor.addRow(arrayOf(fileName, emojisString))
                }
                break
            }
        }
        return cursor
    }

    override fun openAssetFile(uri: Uri, mode: String): AssetFileDescriptor? {
        val match = uriMatcher.match(uri)
        if (match == STICKERS_ASSET_CODE || match == STICKER_PACK_TRAY_ICON_CODE) {
            val segments = uri.pathSegments
            val file: File? = when {
                segments.size >= 3 -> {
                    // e.g. content://<authority>/stickers_asset/<packIdentifier>/<fileName>
                    val packIdentifier = segments[1]
                    val fileName = segments[2]
                    File(context?.filesDir, "stickers/$packIdentifier/$fileName")
                }
                segments.size == 2 -> {
                    // Fallback: content://<authority>/stickers_asset/<fileName> or content://<authority>/<packIdentifier>/<fileName>
                    val candidate1 = File(context?.filesDir, "stickers/${segments[0]}/${segments[1]}")
                    val candidate2 = File(context?.filesDir, "stickers/${segments[1]}")
                    if (candidate1.exists()) candidate1 else candidate2
                }
                else -> null
            }

            if (file != null && file.exists()) {
                val pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
                return AssetFileDescriptor(pfd, 0, AssetFileDescriptor.UNKNOWN_LENGTH)
            }
            Log.e(TAG, "File not found for URI: $uri, resolved: ${file?.absolutePath}")
            throw FileNotFoundException("File not found at ${file?.absolutePath ?: uri.toString()}")
        }
        throw FileNotFoundException("Invalid URI or asset not found: $uri")
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor? {
        val assetFd = openAssetFile(uri, mode)
        return assetFd?.parcelFileDescriptor ?: super.openFile(uri, mode)
    }

    override fun getType(uri: Uri): String? {
        val authority = "${context?.packageName}.stickercontentprovider"
        return when (uriMatcher.match(uri)) {
            METADATA_CODE -> "vnd.android.cursor.dir/vnd.$authority.metadata"
            METADATA_CODE_FOR_SINGLE_PACK -> "vnd.android.cursor.item/vnd.$authority.metadata"
            STICKERS_CODE -> "vnd.android.cursor.dir/vnd.$authority.stickers"
            STICKERS_ASSET_CODE, STICKER_PACK_TRAY_ICON_CODE -> {
                val last = uri.lastPathSegment ?: ""
                if (last.endsWith(".png", ignoreCase = true)) "image/png" else "image/webp"
            }
            else -> throw IllegalArgumentException("Unknown URI: $uri")
        }
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int = 0
}
