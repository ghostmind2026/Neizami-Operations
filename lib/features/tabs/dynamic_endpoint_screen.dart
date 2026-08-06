import 'dart:async';

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
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _payload;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() {});
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 320), _load);
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final query = _searchController.text.trim();
      final data = await context.read<AppController>().api.get(
        '/tabs/${widget.tab['key']}',
        query: query.isEmpty ? null : {'q': query, 'search': query, 'page': 1, 'limit': 40},
      );
      if (mounted) setState(() => _payload = data);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _text(widget.tab['label']).isNotEmpty ? _text(widget.tab['label']) : _text(widget.tab['key']);
    final branding = context.read<AppController>().bootstrap!.branding;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Container(
            color: branding.background,
            padding: const EdgeInsets.fromLTRB(14, 7, 14, 10),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'بحث سريع في $title',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () { _searchController.clear(); _load(); },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading && _payload == null
                  ? const _LoadingList()
                  : _error != null
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(24),
                          children: [
                            const SizedBox(height: 80),
                            Icon(Icons.error_outline_rounded, size: 46, color: branding.muted),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FilledButton(onPressed: _load, child: const Text('إعادة المحاولة')),
                          ],
                        )
                      : Stack(
                          children: [
                            _EndpointBody(payload: _payload ?? const {}),
                            if (_loading) const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator(minHeight: 2)),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingList extends StatelessWidget {
  const _LoadingList();
  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => Container(
          height: 112,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: .5)),
          ),
        ),
      );
}

class _EndpointBody extends StatelessWidget {
  const _EndpointBody({required this.payload});
  final Map<String, dynamic> payload;

  @override
  Widget build(BuildContext context) {
    final endpoint = payload['endpoint'];
    final data = endpoint is Map ? Map<String, dynamic>.from(endpoint) : <String, dynamic>{};
    final rows = _findRows(data);
    if (rows.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [SizedBox(height: 120), Icon(Icons.inbox_outlined, size: 52), SizedBox(height: 12), Text('لا توجد نتائج مطابقة.', textAlign: TextAlign.center)],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 26),
      itemCount: rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (_, index) => _EndpointCard(row: rows[index]),
    );
  }

  static List<Map<String, dynamic>> _findRows(Map<String, dynamic> data) {
    for (final key in const ['rows', 'items', 'data', 'results']) {
      final value = data[key];
      if (value is List) return value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
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
    final branding = context.read<AppController>().bootstrap!.branding;
    final presentation = row['presentation'] is Map ? Map<String, dynamic>.from(row['presentation']) : <String, dynamic>{};
    final formatted = row['formatted'] is Map ? Map<String, dynamic>.from(row['formatted']) : <String, dynamic>{};
    final raw = row['raw'] is Map ? Map<String, dynamic>.from(row['raw']) : <String, dynamic>{};
    final source = <String, dynamic>{...formatted, ...raw, ...row};

    final title = _pickTitle(presentation, source);
    final subtitle = _firstUseful([presentation['subtitle'], row['subtitle'], source['summary'], source['description']]);
    final details = <MapEntry<String, dynamic>>[];

    for (final entry in source.entries) {
      final value = _text(entry.value);
      if (value.isEmpty || value == title || value == subtitle) continue;
      if (_technicalKey(entry.key) || entry.value is Map || entry.value is List) continue;
      details.add(MapEntry(entry.key, entry.value));
      if (details.length == 4) break;
    }

    return Material(
      color: branding.surface,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 11),
        decoration: BoxDecoration(border: Border.all(color: branding.border), borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, height: 1.25, fontWeight: FontWeight.w900)),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: branding.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ],
            if (details.isNotEmpty) const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: details.map((entry) {
                final label = _label(entry.key);
                final value = _text(entry.value);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(color: branding.background, borderRadius: BorderRadius.circular(10)),
                  child: Text(label.isEmpty ? value : '$label: $value', style: TextStyle(color: branding.text, fontSize: 11.5, fontWeight: FontWeight.w700)),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  static String _pickTitle(Map<String, dynamic> presentation, Map<String, dynamic> source) {
    final direct = _firstUseful([
      presentation['title'], source['title'], source['name'], source['label'],
      source['item_name_final'], source['item name final'], source['supplier_name'],
      source['customer_name'], source['device_name'], source['employee_name'],
    ]);
    if (direct.isNotEmpty) return direct;
    for (final entry in source.entries) {
      if (_technicalKey(entry.key) || entry.value is Map || entry.value is List) continue;
      final value = _text(entry.value);
      if (value.isNotEmpty) return value;
    }
    return 'بدون عنوان';
  }

  static String _firstUseful(List<dynamic> values) {
    for (final value in values) {
      final text = _text(value);
      if (text.isNotEmpty) return text;
    }
    return '';
  }

  static bool _technicalKey(String key) {
    final clean = key.toLowerCase().trim();
    return const {'raw','formatted','presentation','entry_id','id','key','field_key','meta'}.contains(clean) || clean.contains('entry id') || clean.contains('field key');
  }

  static String _label(String key) {
    final clean = key.replaceAll(RegExp(r'^tpl_col_'), '').replaceAll('_', ' ').trim();
    if (RegExp(r'^[a-z0-9]{5,10}$', caseSensitive: false).hasMatch(clean) && RegExp(r'\d').hasMatch(clean)) return '';
    return clean;
  }
}

String _text(dynamic value) {
  if (value == null) return '';
  final text = '$value'.trim();
  if (text.isEmpty || text.toLowerCase() == 'null' || text.toLowerCase() == 'undefined') return '';
  return text;
}
