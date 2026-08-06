import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';
import '../approvals/approvals_screen.dart';
import '../camera/device_camera_screen.dart';
import '../formidable/formidable_web_screen.dart';
import '../notifications/notifications_screen.dart';
import '../notifier/compose_notification_screen.dart';
import '../search/receipts_search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final b = app.bootstrap!;
    final theme = b.branding;
    final badges = app.dashboardBadges;
    final actions = (b.home['actions'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    final name = _first(
      b.employee,
      const ['full_name', 'employee_name', 'name', 'display_name'],
      fallback: _first(b.user, const ['display_name', 'name']),
    );
    final title = _first(
      b.employee,
      const ['job_title', 'employee_job_title', 'title', 'role_label'],
    );

    return Scaffold(
      backgroundColor: theme.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: app.refreshAll,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 25,
                    backgroundColor: theme.secondary,
                    child: Icon(Icons.person_rounded, color: theme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? theme.appName : name,
                          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: theme.text),
                        ),
                        Text(title.isEmpty ? theme.appName : title, style: TextStyle(color: theme.muted)),
                      ],
                    ),
                  ),
                  Badge(
                    isLabelVisible: _count(badges['notifications']) > 0,
                    label: Text('${_count(badges['notifications'])}'),
                    child: IconButton.filledTonal(
                      onPressed: () => _open(context, const NotificationsScreen()),
                      icon: const Icon(Icons.notifications_none_rounded),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              TextField(
                readOnly: true,
                onTap: () => _open(context, const ReceiptsSearchScreen()),
                decoration: InputDecoration(
                  hintText: '${(b.home['search'] as Map?)?['label'] ?? 'ابحث في الاستلامات'}',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              const SizedBox(height: 26),
              _Title('ملخصي', loading: app.refreshingDashboard),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.18,
                children: [
                  _Metric(Icons.star_rounded, 'النجوم', _count(badges['stars']), theme.warning,
                      () => _open(context, const NotificationsScreen(scope: 'month'))),
                  _Metric(Icons.warning_amber_rounded, 'الكروت', _count(badges['warning_cards']), theme.danger,
                      () => _open(context, const NotificationsScreen(scope: 'month'))),
                  _Metric(Icons.schedule_rounded, 'بانتظار المدير', _count(badges['my_approvals']), theme.primary,
                      () => _open(context, const ApprovalsScreen(scope: 'mine'))),
                  _Metric(Icons.fact_check_outlined, 'بانتظار موافقتي', _count(badges['manager_approvals']), theme.success,
                      () => _open(context, const ApprovalsScreen(scope: 'awaiting'))),
                ],
              ),
              const SizedBox(height: 26),
              const _Title('وظائف سريعة'),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: actions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: .92,
                ),
                itemBuilder: (context, index) {
                  final action = actions[index];
                  return _Quick(
                    _actionIcon('${action['icon'] ?? ''}'),
                    '${action['label'] ?? action['key'] ?? ''}',
                    () => _runAction(context, action),
                  );
                },
              ),
              const SizedBox(height: 14),
              Material(
                color: theme.secondary,
                borderRadius: BorderRadius.circular(theme.radius),
                child: ListTile(
                  onTap: () => _open(context, const ComposeNotificationScreen()),
                  leading: Icon(Icons.notifications_active_rounded, color: theme.primary),
                  title: Text(
                    '${(b.home['notifier_banner'] as Map?)?['label'] ?? 'إرسال إشعار'}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  trailing: const Icon(Icons.arrow_back_ios_new_rounded, size: 17),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _runAction(BuildContext context, Map<String, dynamic> action) {
    final type = '${action['type'] ?? ''}';
    if (type == 'form') {
      final formKey = '${action['form_key'] ?? ''}'.trim();
      if (formKey.isEmpty) {
        _message(context, 'لم يتم تعريف Form Key لهذا الإجراء.');
        return;
      }
      _open(
        context,
        FormidableWebScreen(
          formKey: formKey,
          title: '${action['label'] ?? formKey}',
        ),
      );
      return;
    }
    if (type == 'camera') {
      _open(context, const DeviceCameraScreen());
      return;
    }
    _message(context, 'هذا الإجراء غير مدعوم بعد: $type');
  }

  static IconData _actionIcon(String key) {
    switch (key) {
      case 'camera': return Icons.camera_alt_rounded;
      case 'bolt': return Icons.bolt_rounded;
      case 'receipt': return Icons.receipt_long_rounded;
      case 'cart': return Icons.shopping_cart_rounded;
      case 'user_plus': return Icons.person_add_alt_1_rounded;
      case 'file_money': return Icons.request_quote_rounded;
      default: return Icons.apps_rounded;
    }
  }

  static void _open(BuildContext context, Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  static void _message(BuildContext context, String message) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  static int _count(dynamic value) => value is num ? value.toInt() : int.tryParse('$value') ?? 0;
  static String _first(Map<String, dynamic> map, List<String> keys, {String fallback = ''}) {
    for (final key in keys) {
      final value = '${map[key] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null') return value;
    }
    return fallback;
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text, {this.loading = false});
  final String text;
  final bool loading;
  @override
  Widget build(BuildContext context) {
    final branding = context.read<AppController>().bootstrap!.branding;
    return Row(
      children: [
        Expanded(child: Text(text, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: branding.text))),
        if (loading) const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.icon, this.label, this.value, this.color, this.onTap);
  final IconData icon;
  final String label;
  final int value;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final branding = context.read<AppController>().bootstrap!.branding;
    return Material(
      color: branding.surface,
      borderRadius: BorderRadius.circular(branding.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(branding.radius),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: branding.border),
            borderRadius: BorderRadius.circular(branding.radius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: color.withValues(alpha: .11), borderRadius: BorderRadius.circular(13)),
                child: Icon(icon, color: color),
              ),
              const Spacer(),
              Text('$value', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: branding.text)),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: branding.muted, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Quick extends StatelessWidget {
  const _Quick(this.icon, this.label, this.onTap);
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final branding = context.read<AppController>().bootstrap!.branding;
    return Material(
      color: branding.surface,
      borderRadius: BorderRadius.circular(branding.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(branding.radius),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            border: Border.all(color: branding.border),
            borderRadius: BorderRadius.circular(branding.radius),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: branding.primary, size: 30),
              const SizedBox(height: 10),
              Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}
