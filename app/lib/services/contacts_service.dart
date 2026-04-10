import 'package:flutter_contacts/flutter_contacts.dart';

/// 读取通讯录（需系统通讯录权限）。仅返回展示所需字段，避免过大 JSON。
class ContactsService {
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
    return raw.map((c) {
      return {
        'id': c.id,
        'displayName': c.displayName,
        'phones': c.phones.map((e) => e.number).toList(),
        'emails': c.emails.map((e) => e.address).toList(),
      };
    }).toList();
  }
}
