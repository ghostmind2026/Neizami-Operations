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

  void _onSearchChanged(String _) {
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
    final fallbackTitle = _text(widget.tab['label']).isNotEmpty ? _text(widget.tab['label']) : _text(widget.tab['key']);
    final presentation = _map(_payload?['presentation']);
    final screen = _map(presentation['screen']);
    final search = _map(presentation['search']);
    final title = _text(screen['title']).isNotEmpty ? _text(screen['title']) : fallbackTitle;
    final showSearch = search['enabled'] != false;
    final branding = context.read<AppController>().bootstrap!.branding;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          if (showSearch)
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
                  hintText: _text(search['placeholder']).isNotEmpty ? _text(search['placeholder']) : 'بحث سريع في $title',
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
                            _PresentationBody(presentation: presentation),
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

class _PresentationBody extends StatelessWidget {
  const _PresentationBody({required this.presentation});
  final Map<String, dynamic> presentation;

  @override
  Widget build(BuildContext context) {
    final screen = _map(presentation['screen']);
    final cards = _listOfMaps(presentation['cards']);
    final kpis = _normalizeItems(presentation['kpis']);
    final groups = _listOfMaps(presentation['groups']);
    final filters = _normalizeItems(presentation['filters']);
    final layout = _text(screen['layout']).isEmpty ? 'rows' : _text(screen['layout']);
    final columns = _int(screen['grid_columns'], 2).clamp(1, 4);

    if (cards.isEmpty && kpis.isEmpty && groups.isEmpty && filters.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [SizedBox(height: 120), Icon(Icons.inbox_outlined, size: 52), SizedBox(height: 12), Text('لا توجد نتائج مطابقة.', textAlign: TextAlign.center)],
      );
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (filters.isNotEmpty) SliverToBoxAdapter(child: _HorizontalSection(items: filters, kind: _SectionKind.filter)),
        if (kpis.isNotEmpty) SliverToBoxAdapter(child: _HorizontalSection(items: kpis, kind: _SectionKind.kpi)),
        if (groups.isNotEmpty) SliverToBoxAdapter(child: _GroupsSection(groups: groups)),
        if (layout == 'grid')
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 26),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate((_, index) => _PresentationCard(card: cards[index], compact: false), childCount: cards.length),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: .92,
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 26),
            sliver: SliverList.separated(
              itemCount: cards.length,
              separatorBuilder: (_, __) => const SizedBox(height: 9),
              itemBuilder: (_, index) => _PresentationCard(
                card: cards[index],
                compact: layout == 'compact',
                elevated: layout == 'cards',
              ),
            ),
          ),
      ],
    );
  }
}

enum _SectionKind { filter, kpi }

class _HorizontalSection extends StatelessWidget {
  const _HorizontalSection({required this.items, required this.kind});
  final List<Map<String, dynamic>> items;
  final _SectionKind kind;

  @override
  Widget build(BuildContext context) {
    final branding = context.read<AppController>().bootstrap!.branding;
    return SizedBox(
      height: kind == _SectionKind.kpi ? 92 : 58,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final item = items[index];
          final label = _firstUseful([item['label'], item['title'], item['name'], item['key']]);
          final value = _firstUseful([item['value'], item['count'], item['total']]);
          return Container(
            constraints: BoxConstraints(minWidth: kind == _SectionKind.kpi ? 104 : 90),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: branding.surface,
              border: Border.all(color: branding.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: kind == _SectionKind.kpi
                ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: branding.muted, fontSize: 12, fontWeight: FontWeight.w700)),
                  ])
                : Center(child: Text(value.isEmpty ? label : '$label: $value', style: const TextStyle(fontWeight: FontWeight.w800))),
          );
        },
      ),
    );
  }
}

class _GroupsSection extends StatelessWidget {
  const _GroupsSection({required this.groups});
  final List<Map<String, dynamic>> groups;

  @override
  Widget build(BuildContext context) {
    final branding = context.read<AppController>().bootstrap!.branding;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      child: Column(
        children: groups.map((group) {
          final label = _firstUseful([group['label'], group['title'], group['name'], group['key']]);
          final count = _text(group['count']);
          final kpis = _normalizeItems(group['kpis']);
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: branding.surface,
              border: Border.all(color: branding.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
                  if (count.isNotEmpty) Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: branding.background, borderRadius: BorderRadius.circular(10)),
                    child: Text(count, style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ]),
                if (kpis.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: kpis.map((item) {
                      final itemLabel = _firstUseful([item['label'], item['title'], item['name'], item['key']]);
                      final value = _firstUseful([item['value'], item['count'], item['total']]);
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(color: branding.background, borderRadius: BorderRadius.circular(11)),
                        child: Text('$itemLabel: $value', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PresentationCard extends StatelessWidget {
  const _PresentationCard({required this.card, this.compact = false, this.elevated = false});
  final Map<String, dynamic> card;
  final bool compact;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final branding = context.read<AppController>().bootstrap!.branding;
    final fields = _map(card['fields']);
    final title = _text(card['title']);
    final subtitle = _text(card['subtitle']);
    final chips = <Map<String, dynamic>>[];
    for (final key in const ['primary_value', 'secondary_value', 'badge', 'reference', 'date']) {
      final field = _map(fields[key]);
      final value = _text(field['value']);
      if (value.isNotEmpty) chips.add(field);
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: compact ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Text(title, maxLines: compact ? 1 : 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: compact ? 15 : 16, height: 1.25, fontWeight: FontWeight.w900)),
        if (subtitle.isNotEmpty && !compact) ...[
          const SizedBox(height: 4),
          Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: branding.muted, fontSize: 12.5, fontWeight: FontWeight.w700)),
        ],
        if (chips.isNotEmpty) SizedBox(height: compact ? 6 : 9),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: chips.map((field) {
            final label = _text(field['label']);
            final value = _text(field['value']);
            final showLabel = field['show_label'] == true && label.isNotEmpty;
            return Container(
              padding: EdgeInsets.symmetric(horizontal: compact ? 7 : 9, vertical: compact ? 3 : 5),
              decoration: BoxDecoration(color: branding.background, borderRadius: BorderRadius.circular(10)),
              child: Text(showLabel ? '$label: $value' : value, style: TextStyle(color: branding.text, fontSize: compact ? 10.5 : 11.5, fontWeight: FontWeight.w700)),
            );
          }).toList(),
        ),
      ],
    );

    return Material(
      elevation: elevated ? 1.5 : 0,
      color: branding.surface,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 72 : 104),
        padding: EdgeInsets.fromLTRB(14, compact ? 10 : 13, 14, compact ? 9 : 11),
        decoration: BoxDecoration(border: Border.all(color: branding.border), borderRadius: BorderRadius.circular(18)),
        child: content,
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

Map<String, dynamic> _map(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<Map<String, dynamic>> _listOfMaps(dynamic value) => value is List ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];
List<Map<String, dynamic>> _normalizeItems(dynamic value) {
  if (value is List) return _listOfMaps(value);
  if (value is Map) {
    return value.entries.map((entry) {
      if (entry.value is Map) return <String, dynamic>{'key': entry.key, ...Map<String, dynamic>.from(entry.value as Map)};
      return <String, dynamic>{'key': entry.key, 'label': entry.key, 'value': entry.value};
    }).toList();
  }
  return const [];
}
String _firstUseful(List<dynamic> values) { for (final value in values) { final text = _text(value); if (text.isNotEmpty) return text; } return ''; }
String _text(dynamic value) { if (value == null) return ''; final text = '$value'.trim(); if (text.isEmpty || text.toLowerCase() == 'null' || text.toLowerCase() == 'undefined') return ''; return text; }
int _int(dynamic value, int fallback) => value is num ? value.toInt() : int.tryParse('$value') ?? fallback;
