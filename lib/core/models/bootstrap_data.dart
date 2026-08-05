import 'package:flutter/material.dart';

Color parseHex(String? value, Color fallback) {
  if (value == null || value.isEmpty) return fallback;
  final clean = value.replaceAll('#', '');
  final parsed = int.tryParse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

class Branding {
  Branding.fromJson(Map<String, dynamic> json)
      : appName = '${json['app_name'] ?? 'Neizami Operations'}',
        logoUrl = '${json['logo_url'] ?? ''}',
        primary = parseHex(json['primary_color']?.toString(), const Color(0xFF2563EB)),
        secondary = parseHex(json['secondary_color']?.toString(), const Color(0xFFEFF6FF)),
        background = parseHex(json['background_color']?.toString(), const Color(0xFFF7F9FC)),
        surface = parseHex(json['surface_color']?.toString(), Colors.white),
        text = parseHex(json['text_color']?.toString(), const Color(0xFF172033)),
        muted = parseHex(json['muted_text_color']?.toString(), const Color(0xFF64748B)),
        border = parseHex(json['border_color']?.toString(), const Color(0xFFE5E7EB)),
        success = parseHex(json['success_color']?.toString(), const Color(0xFF16A34A)),
        warning = parseHex(json['warning_color']?.toString(), const Color(0xFFF59E0B)),
        danger = parseHex(json['danger_color']?.toString(), const Color(0xFFDC2626)),
        radius = (json['border_radius'] as num?)?.toDouble() ?? 16,
        rtl = json['rtl'] != false;

  final String appName;
  final String logoUrl;
  final Color primary;
  final Color secondary;
  final Color background;
  final Color surface;
  final Color text;
  final Color muted;
  final Color border;
  final Color success;
  final Color warning;
  final Color danger;
  final double radius;
  final bool rtl;
}

class BootstrapData {
  BootstrapData.fromJson(Map<String, dynamic> json)
      : branding = Branding.fromJson(Map<String, dynamic>.from(json['branding'] ?? {})),
        user = Map<String, dynamic>.from(json['user'] ?? {}),
        employee = Map<String, dynamic>.from(json['employee'] ?? {}),
        badges = Map<String, dynamic>.from(json['badges'] ?? {}),
        home = Map<String, dynamic>.from(json['home'] ?? {}),
        tabs = (json['tabs'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();

  final Branding branding;
  final Map<String, dynamic> user;
  final Map<String, dynamic> employee;
  final Map<String, dynamic> badges;
  final Map<String, dynamic> home;
  final List<Map<String, dynamic>> tabs;
}
