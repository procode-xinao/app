package com.procode.app

import android.app.Activity
import android.content.ContentUris
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterFragmentActivity() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val ioExecutor = Executors.newSingleThreadExecutor()
    private var pendingPickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "list" -> handleList(call, result)
                "get" -> handleGet(call, result)
                "pickContact" -> handlePickContact(result)
                else -> result.notImplemented()
            }
        }
    }

    private fun handleList(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val limitArg = (call.arguments as? Map<*, *>)?.get("limit")
        val limit =
            when (limitArg) {
                is Int -> limitArg
                is Long -> limitArg.toInt()
                is Number -> limitArg.toInt()
                else -> 50
            }
        ioExecutor.execute {
            try {
                val list = ContactReader.list(contentResolver, limit)
                mainHandler.post { result.success(list) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("contacts_list", e.message, null)
                }
            }
        }
    }

    private fun handleGet(
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val idRaw = (call.arguments as? Map<*, *>)?.get("id")
        val id = idRaw?.toString()?.trim()
        if (id.isNullOrEmpty()) {
            result.success(null)
            return
        }
        ioExecutor.execute {
            try {
                val map = ContactReader.getById(contentResolver, id)
                mainHandler.post { result.success(map) }
            } catch (e: Exception) {
                mainHandler.post {
                    result.error("contacts_get", e.message, null)
                }
            }
        }
    }

    private fun handlePickContact(result: MethodChannel.Result) {
        if (pendingPickResult != null) {
            result.error("busy", "Another pick in progress", null)
            return
        }
        pendingPickResult = result
        val intent =
            Intent(Intent.ACTION_PICK).apply {
                type = ContactsContract.Contacts.CONTENT_TYPE
            }
        startActivityForResult(intent, REQUEST_PICK_CONTACT)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode == REQUEST_PICK_CONTACT && pendingPickResult != null) {
            val pr = pendingPickResult!!
            pendingPickResult = null
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val uri = data.data!!
                val resolved = ContactsContract.Contacts.lookupContact(contentResolver, uri)
                if (resolved != null) {
                    pr.success(ContentUris.parseId(resolved).toString())
                } else {
                    pr.success(null)
                }
            } else {
                pr.success(null)
            }
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }

    companion object {
        private const val CHANNEL = "com.procode.app/contacts"
        private const val REQUEST_PICK_CONTACT = 0x7101
    }
}
