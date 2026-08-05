import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';
import '../approvals/approvals_screen.dart';
import '../notifications/notifications_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final bootstrap = app.bootstrap!;
    final branding = bootstrap.branding;
    final badges = app.dashboardBadges;
    final employeeName = _employeeName(bootstrap.employee, bootstrap.user);
    final jobTitle = _firstText(bootstrap.employee, const [
      'job_title',
      'employee_job_title',
      'title',
      'role_label',
    ]);

    return Scaffold(
      backgroundColor: branding.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: app.refreshAll,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              _Header(
                appName: branding.appName,
                employeeName: employeeName,
                jobTitle: jobTitle,
                notificationCount: _count(badges['notifications']),
                loading: app.refreshingDashboard,
                onNotifications: () => _open(
                  context,
                  const NotificationsScreen(),
                ),
                onLogout: app.logout,
              ),
              const SizedBox(height: 22),
              _SearchBox(onSubmitted: (_) {}),
              const SizedBox(height: 26),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ملخصي',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: branding.text,
                          ),
                    ),
                  ),
                  if (app.refreshingDashboard)
                    const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.18,
                children: [
                  _MetricCard(
                    icon: Icons.star_rounded,
                    label: 'النجوم',
                    value: _count(badges['stars']),
                    accent: branding.warning,
                    onTap: () => _open(
                      context,
                      const NotificationsScreen(scope: 'month'),
                    ),
                  ),
                  _MetricCard(
                    icon: Icons.warning_amber_rounded,
                    label: 'الكروت',
                    value: _count(badges['warning_cards']),
                    accent: branding.danger,
                    onTap: () => _open(
                      context,
                      const NotificationsScreen(scope: 'month'),
                    ),
                  ),
                  _MetricCard(
                    icon: Icons.schedule_rounded,
                    label: 'بانتظار المدير',
                    value: _count(badges['my_approvals']),
                    accent: branding.primary,
                    onTap: () => _open(
                      context,
                      const ApprovalsScreen(scope: 'mine'),
                    ),
                  ),
                  _MetricCard(
                    icon: Icons.fact_check_outlined,
                    label: 'بانتظار موافقتي',
                    value: _count(badges['manager_approvals']),
                    accent: branding.success,
                    onTap: () => _open(
                      context,
                      const ApprovalsScreen(scope: 'awaiting'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Text(
                'وظائف سريعة',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: branding.text,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.download_done_rounded,
                      label: 'استلام سريع',
                      onTap: () => _showSoon(context, 'الاستلام السريع'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.receipt_long_rounded,
                      label: 'إصدار فاتورة',
                      onTap: () => _showSoon(context, 'إصدار فاتورة'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickAction(
                      icon: Icons.camera_alt_rounded,
                      label: 'تصوير جهاز',
                      onTap: () => _showSoon(context, 'تصوير جهاز'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _NotifierAction(
                onTap: () => _showSoon(context, 'إرسال إشعار'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _open(BuildContext context, Widget screen) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  static int _count(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static String _employeeName(
    Map<String, dynamic> employee,
    Map<String, dynamic> user,
  ) {
    final employeeValue = _firstText(employee, const [
      'full_name',
      'employee_name',
      'name',
      'display_name',
      'linked_employee_name',
    ]);
    if (employeeValue.isNotEmpty) return employeeValue;

    return _firstText(user, const [
      'display_name',
      'name',
      'full_name',
      'user_display_name',
    ]);
  }

  static String _firstText(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = '${source[key] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null') return value;
    }
    return '';
  }

  static void _showSoon(BuildContext context, String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('سيتم فتح $title في التحديث التالي.')),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.appName,
    required this.employeeName,
    required this.jobTitle,
    required this.notificationCount,
    required this.loading,
    required this.onNotifications,
    required this.onLogout,
  });

  final String appName;
  final String employeeName;
  final String jobTitle;
  final int notificationCount;
  final bool loading;
  final VoidCallback onNotifications;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final branding = context.read<AppController>().bootstrap!.branding;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 25,
          backgroundColor: branding.secondary,
          child: Icon(Icons.person_rounded, color: branding.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                employeeName.isEmpty ? appName : employeeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: branding.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                jobTitle.isEmpty ? appName : jobTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: branding.muted,
                ),
              ),
            ],
          ),
        ),
        if (loading)
          const Padding(
            padding: EdgeInsetsDirectional.only(end: 4),
            child: SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        Badge(
          isLabelVisible: notificationCount > 0,
          label: Text('$notificationCount'),
          child: IconButton.filledTonal(
            onPressed: onNotifications,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'logout') onLogout();
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout_rounded),
                  SizedBox(width: 8),
                  Text('تسجيل الخروج'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({required this.onSubmitted});

  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      decoration: const InputDecoration(
        hintText: 'ابحث في الاستلامات',
        prefixIcon: Icon(Icons.search_rounded),
        suffixIcon: Icon(Icons.arrow_back_rounded),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final branding = context.read<AppController>().bootstrap!.branding;

    return Material(
      color: branding.surface,
      borderRadius: BorderRadius.circular(branding.radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(branding.radius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(branding.radius),
            border: Border.all(color: branding.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: accent),
              ),
              const Spacer(),
              Text(
                '$value',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: branding.text,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: branding.muted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

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
          height: 112,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(branding.radius),
            border: Border.all(color: branding.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: branding.primary, size: 30),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotifierAction extends StatelessWidget {
  const _NotifierAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final branding = context.read<AppController>().bootstrap!.branding;

    return Material(
      color: branding.secondary,
      borderRadius: BorderRadius.circular(branding.radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(branding.radius),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: branding.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: branding.primary,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'إرسال إشعار',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
