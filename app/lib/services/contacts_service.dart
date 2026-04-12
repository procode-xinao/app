import 'dart:io';

import 'package:flutter_contacts/flutter_contacts.dart';

/// 通讯录（需系统权限）。读取、写入、系统选择器。
class ContactsService {
  /// 与 [listContacts] 中单条结构一致。
  Map<String, Object?> _contactToMap(Contact c) => {
        'id': c.id,
        'displayName': c.displayName,
        'phones': c.phones.map((e) => e.number).toList(),
        'emails': c.emails.map((e) => e.address).toList(),
      };

  Future<List<Map<String, Object?>>> listContacts({int limit = 50}) async {
    final status = await FlutterContacts.permissions.request(PermissionType.read);
    if (status != PermissionStatus.granted && status != PermissionStatus.limited) {
      throw StateError('通讯录权限被拒绝');
    }
    final take = limit.clamp(1, 500);
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
    final id = await FlutterContacts.native.showPicker();
    if (id == null || id.isEmpty) return null;
    final c = await FlutterContacts.get(
      id,
      properties: {ContactProperty.phone, ContactProperty.email},
    );
    if (c == null) return null;
    return _contactToMap(c);
  }
}
