import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.scope = 'month'});

  final String scope;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final app = context.read<AppController>();
      final response = await app.api.get(
        '/notifications',
        query: {'scope': widget.scope},
      );
      final payload = _map(response['payload']).isNotEmpty
          ? _map(response['payload'])
          : response;
      final raw = payload['notifications'] as List? ?? const [];
      _items = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branding = context.read<AppController>().bootstrap!.branding;
    return Scaffold(
      backgroundColor: branding.background,
      appBar: AppBar(
        title: const Text('الإشعارات'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const ListView(children: [SizedBox(height: 260), Center(child: CircularProgressIndicator())])
            : _error != null
                ? ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const SizedBox(height: 120),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                    ],
                  )
                : _items.isEmpty
                    ? const ListView(
                        children: [
                          SizedBox(height: 170),
                          Icon(Icons.notifications_off_outlined, size: 54),
                          SizedBox(height: 12),
                          Center(child: Text('لا توجد إشعارات ضمن هذه الفترة.')),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) => _NotificationCard(item: _items[index]),
                      ),
      ),
    );
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final branding = context.read<AppController>().bootstrap!.branding;
    final type = '${item['visual_type'] ?? ''}';
    final accent = type == 'warning_card'
        ? branding.warning
        : type == 'red_card'
            ? branding.danger
            : type == 'star'
                ? branding.warning
                : branding.primary;
    final title = '${item['title'] ?? item['subject'] ?? 'إشعار'}';
    final message = '${item['message'] ?? item['body'] ?? item['content'] ?? ''}';
    final date = '${item['created_at'] ?? item['date'] ?? ''}';

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: branding.surface,
        borderRadius: BorderRadius.circular(branding.radius),
        border: Border.all(color: branding.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(Icons.notifications_rounded, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                if (message.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(message, maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
                if (date.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(date, style: TextStyle(color: branding.muted, fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
