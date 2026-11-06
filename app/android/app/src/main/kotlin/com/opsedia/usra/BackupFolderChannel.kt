package com.opsedia.usra

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.DocumentsContract.Document
import android.system.ErrnoException
import android.system.OsConstants
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileNotFoundException
import java.io.IOException
import java.util.concurrent.Executors

/// The folder automatic backups go to (lib/core/backup/backup_folder.dart):
/// the system picker (Storage Access Framework), access kept across restarts,
/// and small file steps inside it. No storage permission is needed, and the
/// app can only touch the folder the person chose.
///
/// Errors carry a fixed code and no message: file and folder names stay out
/// of anything that could be logged.
class BackupFolderChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private val resolver: ContentResolver = activity.applicationContext.contentResolver
    private val background = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null

    init {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(::handle)
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "pick" -> pick(result)
            "inspect" -> run(result) {
                val tree = treeOf(call)
                requireAccess(tree)
                emptyMap<String, Any?>()
            }
            "write" -> run(result) {
                write(treeOf(call), call.argument<String>("source")!!, nameOf(call, "name"))
            }
            "rename" -> run(result) {
                rename(treeOf(call), nameOf(call, "from"), nameOf(call, "to"))
                null
            }
            "delete" -> run(result) {
                val tree = treeOf(call)
                find(tree, nameOf(call, "name"))?.let { DocumentsContract.deleteDocument(resolver, it) }
                null
            }
            "list" -> run(result) {
                val tree = treeOf(call)
                requireAccess(tree)
                children(tree).map { mapOf("name" to it.name, "size" to it.size) }
            }
            "release" -> run(result) {
                release(treeOf(call))
                null
            }
            else -> result.notImplemented()
        }
    }

    private fun run(result: MethodChannel.Result, work: () -> Any?) {
        background.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Exception) {
                val code = codeOf(e)
                main.post { result.error(code, null, null) }
            }
        }
    }

    private fun pick(result: MethodChannel.Result) {
        if (pending != null) {
            result.error("busy", null, null)
            return
        }
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
            // Shows the phone's own storage on versions that hide it.
            putExtra("android.content.extra.SHOW_ADVANCED", true)
        }
        try {
            pending = result
            activity.startActivityForResult(intent, REQUEST_PICK)
        } catch (e: ActivityNotFoundException) {
            pending = null
            result.error("cant_use", null, null)
        }
    }

    /// From MainActivity. True when the result was this channel's.
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_PICK) return false
        val result = pending ?: return true
        pending = null
        val tree = data?.data
        if (resultCode != Activity.RESULT_OK || tree == null) {
            result.success(null)
            return true
        }
        run(result) {
            try {
                resolver.takePersistableUriPermission(
                    tree,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                )
                probe(tree)
            } catch (e: Exception) {
                release(tree)
                throw UnusableFolder()
            }
            mapOf(
                "id" to tree.toString(),
                "name" to folderName(tree),
                // Unknown rather than false: phone makers ship their own
                // providers for local storage, and only a copy known to be
                // off the phone may quiet the reminder on Home.
                "onThisPhone" to if (ON_PHONE_AUTHORITIES.contains(tree.authority ?: "")) true else null,
            )
        }
        return true
    }

    /// Everything a backup will do, tried once with a small empty file: some
    /// places can't rename or delete, and an atomic write needs both.
    private fun probe(tree: Uri) {
        val name = "usra-check-${System.nanoTime()}.partial"
        val renamed = "usra-check-${System.nanoTime()}.tmp"
        val created = DocumentsContract.createDocument(resolver, parentOf(tree), MIME, name)
            ?: throw IOException()
        var left: Uri? = created
        try {
            resolver.openOutputStream(created, "w")?.use { it.write(0) } ?: throw IOException()
            val moved = DocumentsContract.renameDocument(resolver, created, renamed)
                ?: find(tree, renamed)
                ?: throw IOException()
            left = moved
        } finally {
            left?.let { DocumentsContract.deleteDocument(resolver, it) }
        }
    }

    /// Fails with "missing" unless access is still held and the folder is
    /// there: moved, deleted, SD card out, or access taken away in Settings.
    private fun requireAccess(tree: Uri) {
        val held = resolver.persistedUriPermissions.any {
            it.uri == tree && it.isWritePermission
        }
        if (!held) throw FileNotFoundException()
        resolver.query(parentOf(tree), arrayOf(Document.COLUMN_DOCUMENT_ID), null, null, null)
            .use { cursor ->
                if (cursor == null || !cursor.moveToFirst()) throw FileNotFoundException()
            }
    }

    private fun write(tree: Uri, source: String, name: String): Long {
        requireAccess(tree)
        // A leftover under the same name would make the provider pick another.
        find(tree, name)?.let { DocumentsContract.deleteDocument(resolver, it) }
        val target = DocumentsContract.createDocument(resolver, parentOf(tree), MIME, name)
            ?: throw IOException()
        var written = 0L
        File(source).inputStream().use { input ->
            // "w" is a new, empty file here; close() is when providers report
            // a write that failed, so it's inside the try of the caller.
            (resolver.openOutputStream(target, "w") ?: throw IOException()).use { output ->
                written = input.copyTo(output, BUFFER)
            }
        }
        return written
    }

    private fun rename(tree: Uri, from: String, to: String) {
        val document = find(tree, from) ?: throw FileNotFoundException()
        DocumentsContract.renameDocument(resolver, document, to)
        // Some providers return null yet rename; only the result counts.
        if (find(tree, to) == null) throw IOException()
    }

    private fun release(tree: Uri) {
        try {
            resolver.releasePersistableUriPermission(
                tree,
                Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
            )
        } catch (e: SecurityException) {
            // Not held any more.
        }
    }

    private class Child(val id: String, val name: String, val size: Long?)

    private fun children(tree: Uri): List<Child> {
        val uri = DocumentsContract.buildChildDocumentsUriUsingTree(
            tree,
            DocumentsContract.getTreeDocumentId(tree),
        )
        val columns = arrayOf(
            Document.COLUMN_DOCUMENT_ID,
            Document.COLUMN_DISPLAY_NAME,
            Document.COLUMN_SIZE,
        )
        val found = mutableListOf<Child>()
        resolver.query(uri, columns, null, null, null)?.use { cursor ->
            while (cursor.moveToNext()) {
                val name = cursor.getString(1) ?: continue
                found.add(
                    Child(cursor.getString(0), name, if (cursor.isNull(2)) null else cursor.getLong(2)),
                )
            }
        }
        return found
    }

    private fun find(tree: Uri, name: String): Uri? =
        children(tree).firstOrNull { it.name == name }?.let {
            DocumentsContract.buildDocumentUriUsingTree(tree, it.id)
        }

    private fun parentOf(tree: Uri): Uri = DocumentsContract.buildDocumentUriUsingTree(
        tree,
        DocumentsContract.getTreeDocumentId(tree),
    )

    private fun folderName(tree: Uri): String {
        resolver.query(parentOf(tree), arrayOf(Document.COLUMN_DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0)?.let { return it }
            }
        return ""
    }

    private fun treeOf(call: MethodCall): Uri = Uri.parse(call.argument<String>("id")!!)

    /// Only ever a plain file name: nothing outside the folder.
    private fun nameOf(call: MethodCall, key: String): String {
        val name = call.argument<String>(key)!!
        require(!name.contains('/') && name != "." && name != "..")
        return name
    }

    private class UnusableFolder : Exception()

    private fun codeOf(e: Throwable): String {
        var cause: Throwable? = e
        while (cause != null) {
            if (cause is UnusableFolder) return "cant_use"
            if (cause is ErrnoException && cause.errno == OsConstants.ENOSPC) return "no_space"
            if (cause.message?.contains("ENOSPC") == true ||
                cause.message?.contains("No space left") == true
            ) {
                return "no_space"
            }
            cause = cause.cause
        }
        return when (e) {
            is FileNotFoundException, is SecurityException, is IllegalArgumentException -> "missing"
            else -> "failed"
        }
    }

    private companion object {
        const val CHANNEL = "usra/backup_folder"
        const val REQUEST_PICK = 0x5542
        const val MIME = "application/octet-stream"
        const val BUFFER = 256 * 1024

        /// Providers whose files are on the phone itself (an SD card goes
        /// with the phone too).
        val ON_PHONE_AUTHORITIES = setOf(
            "com.android.externalstorage.documents",
            "com.android.providers.downloads.documents",
            "com.android.providers.media.documents",
        )
    }
}
