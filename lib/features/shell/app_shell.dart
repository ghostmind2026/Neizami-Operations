import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';
import '../home/home_screen.dart';
import '../tabs/dynamic_endpoint_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final configuredTabs = app.bootstrap!.tabs
        .where((tab) => tab['enabled'] != false)
        .toList();
    final tabs = configuredTabs.isEmpty
        ? <Map<String, dynamic>>[
            {'key': 'home', 'label': 'الرئيسية', 'icon': 'home', 'type': 'home'}
          ]
        : configuredTabs;

    if (_index >= tabs.length) _index = 0;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [for (final tab in tabs) _screenFor(tab)],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          for (final tab in tabs)
            NavigationDestination(
              icon: Icon(_icon('${tab['icon'] ?? ''}')),
              selectedIcon: Icon(_icon('${tab['icon'] ?? ''}'), fill: 1),
              label: '${tab['label'] ?? tab['key'] ?? ''}',
            ),
        ],
      ),
    );
  }

  Widget _screenFor(Map<String, dynamic> tab) {
    final type = '${tab['type'] ?? ''}';
    final key = '${tab['key'] ?? ''}';
    if (type == 'home' || key == 'home') return const HomeScreen();
    if (type == 'endpoint') return DynamicEndpointScreen(tab: tab);
    if (type == 'custom_screen' && key == 'account') {
      return const _AccountScreen();
    }
    return DynamicEndpointScreen(tab: tab);
  }

  IconData _icon(String key) {
    switch (key) {
      case 'home': return Icons.home_rounded;
      case 'tag': return Icons.sell_rounded;
      case 'warehouse': return Icons.warehouse_rounded;
      case 'users': return Icons.groups_rounded;
      case 'user': return Icons.person_rounded;
      case 'receipt': return Icons.receipt_long_rounded;
      case 'chart': return Icons.bar_chart_rounded;
      default: return Icons.grid_view_rounded;
    }
  }
}

class _AccountScreen extends StatelessWidget {
  const _AccountScreen();

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppController>();
    final employee = app.bootstrap!.employee;
    final user = app.bootstrap!.user;
    final name = '${employee['full_name'] ?? employee['employee_name'] ?? user['display_name'] ?? ''}';
    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(radius: 42, child: Text(name.isEmpty ? 'N' : name.characters.first)),
          const SizedBox(height: 14),
          Text(name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 28),
          FilledButton.tonalIcon(
            onPressed: app.logout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }
}
