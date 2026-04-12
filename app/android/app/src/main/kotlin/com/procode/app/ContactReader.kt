package com.procode.app

import android.content.ContentResolver
import android.provider.ContactsContract.CommonDataKinds.Email
import android.provider.ContactsContract.CommonDataKinds.Phone
import android.provider.ContactsContract.Contacts
import android.provider.ContactsContract.Data

/**
 * 不使用 [Contacts.IN_VISIBLE_GROUP] 过滤。
 *
 * flutter_contacts 在 Android 上默认只查「可见组」联系人，部分机型上真实存在的联系人
 * 该标志为 0，会导致列表为空、选择器返回 ID 后插件内 [get] 报 not found。
 */
object ContactReader {
    private const val BATCH = 120

    fun list(
        resolver: ContentResolver,
        limit: Int,
    ): List<Map<String, Any?>> {
        val take = limit.coerceIn(1, 500)
        val orderedIds = mutableListOf<String>()
        val namesById = mutableMapOf<String, String>()

        resolver.query(
            Contacts.CONTENT_URI,
            arrayOf(Contacts._ID, Contacts.DISPLAY_NAME_PRIMARY),
            null,
            null,
            "${Contacts.DISPLAY_NAME_PRIMARY} COLLATE LOCALIZED ASC",
        )?.use { c ->
            val idxId = c.getColumnIndex(Contacts._ID)
            val idxName = c.getColumnIndex(Contacts.DISPLAY_NAME_PRIMARY)
            while (c.moveToNext() && orderedIds.size < take) {
                val id = c.getString(idxId) ?: continue
                orderedIds.add(id)
                namesById[id] = c.getString(idxName) ?: ""
            }
        }

        if (orderedIds.isEmpty()) return emptyList()

        val phones = mutableMapOf<String, MutableList<String>>()
        val emails = mutableMapOf<String, MutableList<String>>()
        fillPhonesAndEmails(resolver, orderedIds, phones, emails)

        return orderedIds.map { id ->
            mapOf(
                "id" to id,
                "displayName" to (namesById[id] ?: ""),
                "phones" to (phones[id]?.toList() ?: emptyList<String>()),
                "emails" to (emails[id]?.toList() ?: emptyList<String>()),
            )
        }
    }

    fun getById(
        resolver: ContentResolver,
        id: String,
    ): Map<String, Any?>? {
        if (id.isEmpty()) return null
        var displayName = ""
        resolver.query(
            Contacts.CONTENT_URI,
            arrayOf(Contacts.DISPLAY_NAME_PRIMARY),
            "${Contacts._ID} = ?",
            arrayOf(id),
            null,
        )?.use { c ->
            if (c.moveToFirst()) {
                val idxName = c.getColumnIndex(Contacts.DISPLAY_NAME_PRIMARY)
                displayName = c.getString(idxName) ?: ""
            } else {
                return null
            }
        } ?: return null

        val phones = mutableMapOf<String, MutableList<String>>()
        val emails = mutableMapOf<String, MutableList<String>>()
        fillPhonesAndEmails(resolver, listOf(id), phones, emails)

        return mapOf(
            "id" to id,
            "displayName" to displayName,
            "phones" to (phones[id]?.toList() ?: emptyList<String>()),
            "emails" to (emails[id]?.toList() ?: emptyList<String>()),
        )
    }

    private fun fillPhonesAndEmails(
        resolver: ContentResolver,
        contactIds: List<String>,
        phones: MutableMap<String, MutableList<String>>,
        emails: MutableMap<String, MutableList<String>>,
    ) {
        for (batch in contactIds.chunked(BATCH)) {
            val ph = batch.joinToString(",") { "?" }
            val selection =
                "${Data.CONTACT_ID} IN ($ph) AND ${Data.MIMETYPE} IN (?, ?)"
            val args =
                (batch + listOf(Phone.CONTENT_ITEM_TYPE, Email.CONTENT_ITEM_TYPE)).toTypedArray()
            resolver.query(
                Data.CONTENT_URI,
                arrayOf(Data.CONTACT_ID, Data.MIMETYPE, Data.DATA1),
                selection,
                args,
                null,
            )?.use { c ->
                val idxCid = c.getColumnIndex(Data.CONTACT_ID)
                val idxMime = c.getColumnIndex(Data.MIMETYPE)
                val idxData = c.getColumnIndex(Data.DATA1)
                while (c.moveToNext()) {
                    val cid = c.getString(idxCid) ?: continue
                    val mime = c.getString(idxMime) ?: continue
                    val raw = c.getString(idxData)?.trim() ?: continue
                    if (raw.isEmpty()) continue
                    when (mime) {
                        Phone.CONTENT_ITEM_TYPE ->
                            phones.getOrPut(cid) { mutableListOf() }.add(raw)
                        Email.CONTENT_ITEM_TYPE ->
                            emails.getOrPut(cid) { mutableListOf() }.add(raw)
                    }
                }
            }
        }
    }
}
