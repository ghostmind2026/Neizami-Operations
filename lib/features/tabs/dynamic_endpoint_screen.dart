import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';

class DynamicEndpointScreen extends StatefulWidget {
  const DynamicEndpointScreen({super.key, required this.tab});

  final Map<String, dynamic> tab;

  @override
  State<DynamicEndpointScreen> createState() => _DynamicEndpointScreenState();
}

class _DynamicEndpointScreenState extends State<DynamicEndpointScreen> {
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _payload;

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
      final api = context.read<AppController>().api;
      final data = await api.get('/tabs/${widget.tab['key']}');
      if (!mounted) return;
      setState(() => _payload = data);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = '${widget.tab['label'] ?? widget.tab['key'] ?? ''}';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                    ],
                  )
                : _EndpointBody(payload: _payload ?? const {}),
      ),
    );
  }
}

class _EndpointBody extends StatelessWidget {
  const _EndpointBody({required this.payload});

  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final endpoint = payload['endpoint'];
    final data = endpoint is Map<String, dynamic>
        ? endpoint
        : endpoint is Map
            ? Map<String, dynamic>.from(endpoint)
            : <String, dynamic>{};
    final rows = _findRows(data);

    if (rows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 120),
          Icon(Icons.inbox_outlined, size: 52),
          SizedBox(height: 12),
          Text('لا توجد بيانات لعرضها.', textAlign: TextAlign.center),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => _EndpointCard(row: rows[index]),
    );
  }

  static List<Map<String, dynamic>> _findRows(Map<String, dynamic> data) {
    for (final key in const ['rows', 'items', 'data', 'results']) {
      final value = data[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      if (value is Map) {
        final nested = _findRows(Map<String, dynamic>.from(value));
        if (nested.isNotEmpty) return nested;
      }
    }
    return const [];
  }
}

class _EndpointCard extends StatelessWidget {
  const _EndpointCard({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppController>();
    final branding = app.bootstrap!.branding;
    final source = <String, dynamic>{
      ...?row['formatted'] is Map ? Map<String, dynamic>.from(row['formatted']) : null,
      ...?row['raw'] is Map ? Map<String, dynamic>.from(row['raw']) : null,
      ...row,
    };
    source.removeWhere((key, value) =>
        key == 'raw' ||
        key == 'formatted' ||
        value == null ||
        '$value'.trim().isEmpty ||
        value is Map ||
        value is List);
    final entries = source.entries.take(7).toList();
    final title = entries.isEmpty ? 'سجل' : '${entries.first.value}';

    return Material(
      color: branding.surface,
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
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            if (entries.length > 1) const SizedBox(height: 10),
            for (final entry in entries.skip(1))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        _humanize(entry.key),
                        style: TextStyle(color: branding.muted, fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 3,
                      child: Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _humanize(String value) => value
      .replaceAll(RegExp(r'^tpl_col_'), '')
      .replaceAll('_', ' ')
      .trim();
}
