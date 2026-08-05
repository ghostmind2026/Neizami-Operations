import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key, this.scope = 'awaiting'});

  final String scope;

  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> {
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
        '/approvals',
        query: {'scope': widget.scope},
      );
      final payload = _map(response['payload']).isNotEmpty
          ? _map(response['payload'])
          : response;
      final raw = payload['items'] as List? ?? const [];
      _items = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(Map<String, dynamic> item, String action) async {
    String note = '';
    if (action == 'reject') {
      final controller = TextEditingController();
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('سبب الرفض'),
          content: TextField(
            controller: controller,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(hintText: 'اكتب سبب الرفض'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إرسال الرفض')),
          ],
        ),
      );
      note = controller.text.trim();
      controller.dispose();
      if (approved != true) return;
      if (note.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سبب الرفض مطلوب.')));
        return;
      }
    }

    try {
      await context.read<AppController>().api.post('/approvals', body: {
        'request_id': item['id'],
        'action': action,
        'note': note,
      });
      if (!mounted) return;
      setState(() => _items.removeWhere((e) => '${e['id']}' == '${item['id']}'));
      await context.read<AppController>().refreshDashboard();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(action == 'approve' ? 'تمت الموافقة.' : 'تم رفض الطلب.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final branding = context.read<AppController>().bootstrap!.branding;
    final title = widget.scope == 'mine' ? 'طلباتي' : 'بانتظار موافقتي';
    return Scaffold(
      backgroundColor: branding.background,
      appBar: AppBar(title: Text(title)),
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
                          Icon(Icons.fact_check_outlined, size: 54),
                          SizedBox(height: 12),
                          Center(child: Text('لا توجد طلبات ضمن هذا القسم.')),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, index) {
                          final item = _items[index];
                          return _ApprovalCard(
                            item: item,
                            showActions: widget.scope != 'mine' && item['can_approve'] == true,
                            onApprove: () => _decide(item, 'approve'),
                            onReject: () => _decide(item, 'reject'),
                          );
                        },
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

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.item,
    required this.showActions,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> item;
  final bool showActions;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final branding = context.read<AppController>().bootstrap!.branding;
    final presentation = item['presentation'] is Map
        ? Map<String, dynamic>.from(item['presentation'] as Map)
        : <String, dynamic>{};
    final data = item['data'] is Map
        ? Map<String, dynamic>.from(item['data'] as Map)
        : <String, dynamic>{};
    final title = '${presentation['title'] ?? item['title'] ?? 'طلب موافقة'}';
    final subtitle = '${presentation['subtitle'] ?? item['subtitle'] ?? ''}';
    final requestedBy = '${presentation['requested_by'] ?? item['requested_by'] ?? ''}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: branding.surface,
        borderRadius: BorderRadius.circular(branding.radius),
        border: Border.all(color: branding.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
              Text('${item['created_at'] ?? ''}', style: TextStyle(color: branding.muted, fontSize: 11)),
            ],
          ),
          if (subtitle.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(subtitle, style: TextStyle(color: branding.muted)),
          ],
          if (requestedBy.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [const Icon(Icons.person_outline_rounded, size: 17), const SizedBox(width: 5), Text(requestedBy)]),
          ],
          if (data.isNotEmpty) ...[
            const Divider(height: 24),
            ...data.entries.take(8).map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 105, child: Text(entry.key, style: TextStyle(color: branding.muted, fontWeight: FontWeight.w700))),
                    Expanded(child: Text('${entry.value}')),
                  ],
                ),
              ),
            ),
          ],
          if (showActions) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onApprove,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('موافقة'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onReject,
                    icon: Icon(Icons.close_rounded, color: branding.danger),
                    label: Text('رفض', style: TextStyle(color: branding.danger)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
