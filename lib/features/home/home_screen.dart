import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final bootstrap = app.bootstrap!;
    final badges = bootstrap.badges;
    final userName = '${bootstrap.user['name'] ?? bootstrap.employee['name'] ?? ''}';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bootstrap.branding.appName,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            if (userName.isNotEmpty)
              Text(userName, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          Badge(
            isLabelVisible: (badges['notifications'] as num? ?? 0) > 0,
            label: Text('${badges['notifications'] ?? 0}'),
            child: IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') app.logout();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'logout', child: Text('تسجيل الخروج')),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: app.loadBootstrap,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: 'ابحث في الاستلامات',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'ملخصي',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.45,
              children: [
                _MetricCard(
                  icon: Icons.star_rounded,
                  label: 'النجوم',
                  value: badges['stars'],
                ),
                _MetricCard(
                  icon: Icons.warning_amber_rounded,
                  label: 'الكروت',
                  value: badges['warning_cards'],
                ),
                _MetricCard(
                  icon: Icons.schedule_rounded,
                  label: 'بانتظار المدير',
                  value: badges['my_approvals'],
                ),
                _MetricCard(
                  icon: Icons.fact_check_outlined,
                  label: 'بانتظار موافقتي',
                  value: badges['manager_approvals'],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'الإصدار الأولي متصل بالـBridge',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${value ?? 0}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(label),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
