import 'package:add_2_calendar/add_2_calendar.dart';

/// 向系统日历添加事件（用户确认后写入默认日历）。
class CalendarBridgeService {
  Future<bool> addEvent({
    required String title,
    String? description,
    String? location,
    required int startMs,
    required int endMs,
    bool allDay = false,
  }) async {
    if (title.trim().isEmpty) throw ArgumentError('title 不能为空');
    if (endMs <= startMs) throw ArgumentError('endMs 须大于 startMs');
    final event = Event(
      title: title.trim(),
      description: description?.trim().isEmpty == true ? null : description?.trim(),
      location: location?.trim().isEmpty == true ? null : location?.trim(),
      startDate: DateTime.fromMillisecondsSinceEpoch(startMs),
      endDate: DateTime.fromMillisecondsSinceEpoch(endMs),
      allDay: allDay,
    );
    return Add2Calendar.addEvent2Cal(event);
  }
}
