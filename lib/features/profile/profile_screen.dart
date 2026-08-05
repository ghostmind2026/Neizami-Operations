import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final bootstrap = app.bootstrap!;
    final branding = bootstrap.branding;
    final employee = bootstrap.employee;
    final user = bootstrap.user;
    final name = _first(employee, const ['full_name', 'employee_name', 'name', 'display_name'], fallback: _first(user, const ['display_name', 'name']));
    final title = _first(employee, const ['job_title', 'employee_job_title', 'title', 'role_label']);
    final photo = _first(employee, const ['photo_url', 'employee_photo', 'avatar_url']);

    return Scaffold(
      backgroundColor: branding.background,
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: branding.surface,
              borderRadius: BorderRadius.circular(branding.radius),
              border: Border.all(color: branding.border),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: branding.secondary,
                  backgroundImage: photo.isEmpty ? null : CachedNetworkImageProvider(photo),
                  child: photo.isEmpty ? Icon(Icons.person_rounded, size: 48, color: branding.primary) : null,
                ),
                const SizedBox(height: 14),
                Text(name.isEmpty ? branding.appName : name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                if (title.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(title, style: TextStyle(color: branding.muted)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          _InfoTile(icon: Icons.badge_outlined, label: 'رقم الموظف', value: _first(employee, const ['employee_number', 'number', 'employee_id'])),
          _InfoTile(icon: Icons.apartment_outlined, label: 'القسم', value: _first(employee, const ['department', 'department_name'])),
          _InfoTile(icon: Icons.email_outlined, label: 'البريد', value: _first(user, const ['email', 'user_email'])),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            value: false,
            onChanged: (_) => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سيتم تفعيل البصمة بعد تثبيت دورة القفل وفتح الجلسة.'))),
            title: const Text('الدخول بالبصمة'),
            subtitle: const Text('بعد أول تسجيل دخول ناجح.'),
            secondary: const Icon(Icons.fingerprint_rounded),
          ),
          ListTile(
            leading: const Icon(Icons.refresh_rounded),
            title: const Text('تحديث بيانات التطبيق'),
            onTap: app.refreshAll,
          ),
          ListTile(
            leading: Icon(Icons.logout_rounded, color: branding.danger),
            title: Text('تسجيل الخروج', style: TextStyle(color: branding.danger)),
            onTap: app.logout,
          ),
        ],
      ),
    );
  }

  static String _first(Map<String, dynamic> source, List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = '${source[key] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null') return value;
    }
    return fallback;
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(value),
    );
  }
}
