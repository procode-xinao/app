import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

/// 通讯录（需系统权限）。读取、写入、系统选择器。
class ContactsService {
  /// Android：列表与按 ID 读取走原生 [ContactReader]，避免 flutter_contacts 强制
  /// `IN_VISIBLE_GROUP = 1` 在部分机型上导致列表为空 / 选人后 get 失败。
  static const MethodChannel _androidContactsChannel =
      MethodChannel('com.procode.app/contacts');

  /// 与 [listContacts] 中单条结构一致。
  Map<String, Object?> _contactToMap(Contact c) => {
        'id': c.id,
        'displayName': c.displayName,
        'phones': c.phones.map((e) => e.number).toList(),
        'emails': c.emails.map((e) => e.address).toList(),
      };

  static Map<String, Object?> _androidRowToMap(Map<dynamic, dynamic> row) {
    List<String> asStringList(dynamic v) {
      if (v is! List) return [];
      return v.map((e) => e?.toString() ?? '').where((s) => s.isNotEmpty).toList();
    }

    return {
      'id': row['id']?.toString() ?? '',
      'displayName': row['displayName']?.toString() ?? '',
      'phones': asStringList(row['phones']),
      'emails': asStringList(row['emails']),
    };
  }

  Future<List<Map<String, Object?>>> listContacts({int limit = 50}) async {
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
      throw StateError('通讯录权限被拒绝');
    }
    final take = limit.clamp(1, 500);
    if (Platform.isAndroid) {
      final raw = await _androidContactsChannel.invokeMethod<List<dynamic>>(
        'list',
        <String, int>{'limit': take},
      );
      if (raw == null) return [];
      return raw
          .map((e) => _androidRowToMap(Map<dynamic, dynamic>.from(e as Map)))
          .toList();
    }
    final raw = await FlutterContacts.getAll(
      properties: {ContactProperty.phone, ContactProperty.email},
      limit: take,
    );
    return raw.map(_contactToMap).toList();
  }

  /// 写入新联系人；返回系统生成的联系人 [id]。
  ///
  /// [data]：`displayName`（可选）、`phones`（字符串数组）、`emails`（字符串数组）。
  /// `phones` 与 `emails` 至少一项含非空字符串。
  Future<String> saveContact(Map<String, dynamic> data) async {
    final status = await FlutterContacts.permissions.request(PermissionType.readWrite);
    if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
      throw StateError('通讯录读写权限被拒绝');
    }
    final displayName = data['displayName']?.toString().trim() ?? '';
    final phones = <Phone>[];
    final pr = data['phones'];
    if (pr is List) {
      for (final p in pr) {
        final s = p?.toString().trim() ?? '';
        if (s.isNotEmpty) phones.add(Phone(number: s));
      }
    }
    final emails = <Email>[];
    final er = data['emails'];
    if (er is List) {
      for (final e in er) {
        final s = e?.toString().trim() ?? '';
        if (s.isNotEmpty) emails.add(Email(address: s));
      }
    }
    if (phones.isEmpty && emails.isEmpty) {
      throw ArgumentError('phones 与 emails 至少需一项非空');
    }
    Name? name;
    if (displayName.isNotEmpty) {
      name = Name(first: displayName);
    }
    final contact = Contact(name: name, phones: phones, emails: emails);
    return FlutterContacts.create(contact);
  }

  /// 弹出系统通讯录选择器（仅 Android / iOS）。取消时返回 `null`。
  Future<Map<String, Object?>?> pickContact() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('通讯录选择器仅支持 Android 与 iOS');
    }
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
      throw StateError('通讯录权限被拒绝');
    }
    if (Platform.isAndroid) {
      final id = (await _androidContactsChannel.invokeMethod('pickContact')) as String?;
      if (id == null || id.isEmpty) return null;
      final row = await _androidContactsChannel.invokeMethod<Map<dynamic, dynamic>>(
        'get',
        <String, String>{'id': id},
      );
      if (row == null) return null;
      return _androidRowToMap(row);
    }

    final c = await FlutterContacts.native.showPicker();
    if (c == null) return null;
    return _contactToMap(c);
  }
}
