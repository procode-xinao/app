import 'package:flutter/material.dart';

/// 解析 `#RGB` / `#RRGGBB` / `#AARRGGBB`（可省略 `#`）。
Color? parseHexColor(String? value) {
  if (value == null) return null;
  var v = value.trim();
  if (v.isEmpty) return null;
  if (v.startsWith('#')) v = v.substring(1);
  if (v.length == 3) {
    v = '${v[0]}${v[0]}${v[1]}${v[1]}${v[2]}${v[2]}';
  }
  if (v.length == 6) v = 'FF$v';
  if (v.length != 8) return null;
  final n = int.tryParse(v, radix: 16);
  return n == null ? null : Color(n);
}
