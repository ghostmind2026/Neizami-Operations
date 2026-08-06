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
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final api = context.read<AppController>().api;
      final query = _searchController.text.trim();
      final data = await api.get(
        '/tabs/${widget.tab['key']}',
        query: query.isEmpty
            ? null
            : <String, dynamic>{
                'q': query,
                'search': query,
                'page': 1,
                'limit': 40,
              },
      );
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
                        onPressed: () {
                          _searchController.clear();
                          _load();
                        },
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
                            Icon(Icons.error_outline_rounded,
                                size: 46, color: branding.muted),
                            const SizedBox(height: 12),
                            Text(_error!, textAlign: TextAlign.center),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _load,
                              child: const Text('إعادة المحاولة'),
                            ),
                          ],
                        )
                      : Stack(
                          children: [
                            _EndpointBody(payload: _payload ?? const {}),
                            if (_loading)
                              const Positioned(
                                top: 0,
                                left: 0,
                                right: 0,
                                child: LinearProgressIndicator(minHeight: 2),
                              ),
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
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: .5),
            ),
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
    final data = endpoint is Map
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
          Text('لا توجد نتائج مطابقة.', textAlign: TextAlign.center),
        ],
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
    final branding = context.read<AppController>().bootstrap!.branding;
    final presentation = row['presentation'] is Map
        ? Map<String, dynamic>.from(row['presentation'])
        : <String, dynamic>{};
    final formatted = row['formatted'] is Map
        ? Map<String, dynamic>.from(row['formatted'])
        : <String, dynamic>{};
    final raw = row['raw'] is Map
        ? Map<String, dynamic>.from(row['raw'])
        : <String, dynamic>{};

    final visible = <MapEntry<String, dynamic>>[];
    final merged = <String, dynamic>{...formatted, ...raw, ...row};

    for (final entry in merged.entries) {
      if (_technicalKey(entry.key)) continue;
      if (!_usableValue(entry.value)) continue;
      visible.add(entry);
    }

    final explicitTitle = _cleanText(
      presentation['title'] ?? row['title'] ?? row['name'] ?? row['label'],
    );
    final titleEntry = _bestTitleEntry(visible);
    final title = explicitTitle.isNotEmpty
        ? explicitTitle
        : titleEntry != null
            ? _cleanText(titleEntry.value)
            : 'بدون عنوان';

    final subtitle = _cleanText(
      presentation['subtitle'] ?? row['subtitle'] ?? '',
    );

    final details = visible
        .where((entry) {
          final value = _cleanText(entry.value);
          return value.isNotEmpty && value != title && value != subtitle;
        })
        .where((entry) => !_looksLikeOpaqueKey(entry.key))
        .take(4)
        .toList();

    return Material(
      color: branding.surface,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 11),
        decoration: BoxDecoration(
          border: Border.all(color: branding.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                height: 1.25,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: branding.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (details.isNotEmpty) const SizedBox(height: 9),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: details
                  .map(
                    (entry) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: branding.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_humanize(entry.key)}: ${_cleanText(entry.value)}',
                        style: TextStyle(
                          color: branding.text,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  static MapEntry<String, dynamic>? _bestTitleEntry(
    List<MapEntry<String, dynamic>> entries,
  ) {
    MapEntry<String, dynamic>? best;
    var bestScore = -999;

    for (final entry in entries) {
      final text = _cleanText(entry.value);
      if (text.isEmpty) continue;

      var score = 0;
      final key = entry.key.toLowerCase();

      if (_preferredTitleKey(key)) score += 100;
      if (!_isNumeric(text)) score += 25;
      if (text.length >= 4) score += 10;
      if (text.length >= 8) score += 8;
      if (RegExp(r'[\u0600-\u06FFa-zA-Z]').hasMatch(text)) score += 10;
      if (_looksLikeOpaqueKey(entry.key)) score -= 35;
      if (_genericValue(text)) score -= 20;
      if (_technicalValue(text)) score -= 50;

      if (score > bestScore) {
        bestScore = score;
        best = entry;
      }
    }

    return best;
  }

  static bool _preferredTitleKey(String key) {
    const preferred = [
      'title',
      'name',
      'item name',
      'item_name',
      'final item',
      'customer',
      'supplier',
      'device',
      'product',
      'label',
      'الاسم',
      'اسم',
      'العميل',
      'المورد',
      'الجهاز',
      'الصنف',
    ];
    return preferred.any(key.contains);
  }

  static bool _usableValue(dynamic value) {
    if (value == null || value is Map || value is List) return false;
    final text = _cleanText(value);
    return text.isNotEmpty && text != 'null';
  }

  static String _cleanText(dynamic value) => '$value'.trim();

  static bool _technicalKey(String key) {
    final clean = key.toLowerCase().trim();
    return const {
          'raw',
          'formatted',
          'presentation',
          'entry_id',
          'id',
          'key',
          'field_key',
          'meta',
        }.contains(clean) ||
        clean.contains('entry id') ||
        clean.contains('field key');
  }

  static bool _looksLikeOpaqueKey(String key) {
    final clean = key.trim();
    if (clean.isEmpty) return true;
    if (RegExp(r'^\d+$').hasMatch(clean)) return true;
    if (RegExp(r'^[a-z0-9_]{3,14}$', caseSensitive: false)
            .hasMatch(clean) &&
        RegExp(r'\d').hasMatch(clean)) {
      return true;
    }
    return false;
  }

  static bool _isNumeric(String value) =>
      double.tryParse(value.replaceAll(',', '')) != null;

  static bool _genericValue(String value) {
    final clean = value.toLowerCase();
    return const {
      'صيانة',
      'مبيعات',
      'نشط',
      'فعال',
      'yes',
      'no',
      'true',
      'false',
    }.contains(clean);
  }

  static bool _technicalValue(String value) {
    final clean = value.toLowerCase();
    return clean == 'entry id' ||
        clean == 'field key' ||
        clean.startsWith('tpl_col_');
  }

  static String _humanize(String value) {
    final clean = value
        .replaceAll(RegExp(r'^tpl_col_'), '')
        .replaceAll('_', ' ')
        .trim();
    if (_looksLikeOpaqueKey(clean)) return 'تفصيل';
    return clean;
  }
}
