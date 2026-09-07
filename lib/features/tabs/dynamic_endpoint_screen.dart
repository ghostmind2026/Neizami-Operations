import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';
import '../../core/ui/neizami_ui.dart';
part 'runtime/dynamic_endpoint_toolbar.dart';
part 'runtime/dynamic_endpoint_cards.dart';
part 'runtime/dynamic_endpoint_helpers.dart';


class DynamicEndpointScreen extends StatefulWidget {
  const DynamicEndpointScreen({super.key, required this.tab});

  final Map<String, dynamic> tab;

  @override
  State<DynamicEndpointScreen> createState() => _DynamicEndpointScreenState();
}

class _DynamicEndpointScreenState extends State<DynamicEndpointScreen> {
  static const int _pageSize = 40;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, String> _filters = <String, String>{};

  Timer? _debounce;
  Map<String, dynamic>? _payload;
  String? _error;
  String _lastExecutedSearch = '';
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  int get _minSearchChars {
    final search = _map(_map(_payload?['presentation'])['search']);
    final value = int.tryParse('${search['min_chars'] ?? ''}');
    return value == null ? 3 : value.clamp(1, 8).toInt();
  }

  bool get _searchTooShort {
    final text = _searchController.text.trim();
    return text.isNotEmpty && text.characters.length < _minSearchChars;
  }

  void _onScroll() {
    if (!_hasMore || _loading || _loadingMore || !_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.extentAfter < 520) {
      _load(reset: false);
    }
  }

  void _onSearchChanged(String value) {
    ++_requestSerial;
    if (mounted) setState(() {});
    _debounce?.cancel();
    final normalized = value.trim();

    if (normalized.isNotEmpty && normalized.characters.length < _minSearchChars) {
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 320), () {
      _executeSearch(normalized);
    });
  }

  void _executeSearch(String value) {
    final normalized = value.trim();
    if (normalized == _lastExecutedSearch) return;
    _lastExecutedSearch = normalized;
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (!reset && (_loadingMore || !_hasMore)) return;

    final requestId = ++_requestSerial;
    final targetPage = reset ? 1 : _page + 1;

    if (mounted) {
      setState(() {
        if (reset) {
          _loading = true;
          _error = null;
        } else {
          _loadingMore = true;
        }
      });
    }

    try {
      final search = _searchController.text.trim();
      final query = <String, dynamic>{
        'page': targetPage,
        'per_page': _pageSize,
        'limit': _pageSize,
        if (search.isNotEmpty && !_searchTooShort) 'search': search,
        if (search.isNotEmpty && !_searchTooShort) 'q': search,
        if (_filters.isNotEmpty) 'filters': jsonEncode(_filters),
      };

      final data = await context.read<AppController>().api.get(
        '/tabs/${widget.tab['key']}',
        query: query,
      );

      if (!mounted || requestId != _requestSerial) return;

      final nextPage = _pageFrom(data, targetPage);
      final hasMore = _hasMoreFrom(data, page: nextPage, pageSize: _pageSize);
      final compact = _compactPayload(data);

      setState(() {
        _payload = reset ? compact : _mergePayload(_payload, compact);
        _page = nextPage;
        _hasMore = hasMore;
      });
    } catch (error) {
      if (!mounted || requestId != _requestSerial) return;
      if (_payload == null || reset) {
        setState(() => _error = '$error');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث النتائج: $error')),
        );
      }
    } finally {
      if (mounted && requestId == _requestSerial) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Map<String, dynamic> _compactPayload(Map<String, dynamic> data) {
    return <String, dynamic>{
      if (data['tab'] != null) 'tab': data['tab'],
      if (data['presentation'] != null) 'presentation': data['presentation'],
    };
  }

  Future<void> _openFilters(List<Map<String, dynamic>> definitions) async {
    if (definitions.isEmpty) return;
    final draft = <String, String>{..._filters};

    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .82,
                ),
                decoration: BoxDecoration(
                  color: context.nz.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                      child: Column(
                        children: [
                          Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: context.nz.border,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                          const SizedBox(height: 14),
                          NzSectionHeader(
                            title: 'تصفية النتائج',
                            subtitle: 'اختر قيمة واحدة من كل مجموعة',
                            trailing: TextButton(
                              onPressed: () => setSheetState(() => draft.clear()),
                              child: const Text('مسح الكل'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
                        itemCount: definitions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 18),
                        itemBuilder: (_, index) {
                          final definition = definitions[index];
                          final key = _filterKey(definition);
                          if (key.isEmpty) return const SizedBox.shrink();
                          final label = _filterLabel(definition, key);
                          final options = _filterOptions(definition);
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  color: context.nz.text,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 9),
                              Wrap(
                                spacing: 7,
                                runSpacing: 7,
                                children: [
                                  NzFilterChip(
                                    label: 'الكل',
                                    selected: !draft.containsKey(key),
                                    onSelected: () => setSheetState(() => draft.remove(key)),
                                  ),
                                  for (final option in options)
                                    NzFilterChip(
                                      label: _optionLabel(option),
                                      count: _optionCount(option),
                                      selected: draft[key] == _optionValue(option),
                                      onSelected: () {
                                        final value = _optionValue(option);
                                        setSheetState(() {
                                          if (value.isEmpty || draft[key] == value) {
                                            draft.remove(key);
                                          } else {
                                            draft[key] = value;
                                          }
                                        });
                                      },
                                    ),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(context, draft),
                        icon: const Icon(Icons.tune_rounded),
                        label: Text(
                          draft.isEmpty ? 'عرض كل النتائج' : 'تطبيق (${draft.length})',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result == null || !mounted) return;
    setState(() {
      _filters
        ..clear()
        ..addAll(result);
    });
    await _load(reset: true);
  }

  Future<void> _setFilter(String key, String value) async {
    if (key.isEmpty) return;
    setState(() {
      if (value.isEmpty || _filters[key] == value) {
        _filters.remove(key);
      } else {
        _filters[key] = value;
      }
    });
    await _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final presentation = _map(_payload?['presentation']);
    final screen = _map(presentation['screen']);
    final search = _map(presentation['search']);
    final filters = _filterDefinitions(presentation['filters']);
    final fallbackTitle = _text(widget.tab['label']).isNotEmpty
        ? _text(widget.tab['label'])
        : _text(widget.tab['key']);
    final title = _text(screen['title']).isNotEmpty
        ? _text(screen['title'])
        : fallbackTitle;
    final showSearch = search['enabled'] != false;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          if (showSearch || filters.isNotEmpty)
            _EndpointToolbar(
              controller: _searchController,
              showSearch: showSearch,
              searchBusy: _loading && _payload != null,
              searchTooShort: _searchTooShort,
              minSearchChars: _minSearchChars,
              hintText: _text(search['placeholder']).isNotEmpty
                  ? _text(search['placeholder'])
                  : 'بحث سريع في $title',
              filters: filters,
              activeFilters: _filters,
              onSearchChanged: _onSearchChanged,
              onSearchSubmitted: _executeSearch,
              onClearSearch: () {
                _searchController.clear();
                _executeSearch('');
                setState(() {});
              },
              onOpenFilters: () => _openFilters(filters),
              onQuickFilter: _setFilter,
              onClearFilters: () {
                setState(() => _filters.clear());
                _load(reset: true);
              },
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(reset: true),
              child: _body(presentation),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(Map<String, dynamic> presentation) {
    if (_loading && _payload == null) {
      return ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => const NzSkeletonCard(),
      );
    }

    if (_error != null && _payload == null) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          NzEmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'تعذر تحميل البيانات',
            message: _error,
            action: FilledButton.tonal(
              onPressed: () => _load(reset: true),
              child: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      );
    }

    final cards = _listOfMaps(presentation['cards']);
    final kpis = _flattenKpis(presentation['kpis']);
    final groups = _listOfMaps(presentation['groups']);
    final screen = _map(presentation['screen']);

    if (cards.isEmpty && groups.isEmpty && kpis.isEmpty) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          NzEmptyState(
            title: 'لا توجد نتائج مطابقة',
            message: 'جرّب تغيير البحث أو إزالة بعض الفلاتر.',
          ),
        ],
      );
    }

    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            if (kpis.isNotEmpty)
              SliverToBoxAdapter(
                child: _KpiStrip(
                  items: kpis,
                  activeFilters: _filters,
                  onFilter: _setFilter,
                ),
              ),
            if (groups.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                  child: _GroupBrowser(
                    groups: groups,
                    cards: cards,
                    screen: screen,
                  ),
                ),
              )
            else
              _cardsSliver(cards, screen),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 28),
                child: _loadingMore
                    ? const Column(
                        children: [
                          NzSkeletonCard(compact: true),
                          SizedBox(height: 8),
                          Text('جاري تحميل المزيد...'),
                        ],
                      )
                    : _hasMore
                        ? Center(
                            child: Text(
                              'مرّر للأسفل لتحميل المزيد',
                              style: TextStyle(color: context.nz.muted, fontSize: 12),
                            ),
                          )
                        : cards.isEmpty
                            ? const SizedBox.shrink()
                            : Center(
                                child: Text(
                                  'تم تحميل كل النتائج',
                                  style: TextStyle(color: context.nz.muted, fontSize: 12),
                                ),
                              ),
              ),
            ),
          ],
        ),
        if (_loading && _payload != null)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
      ],
    );
  }

  Widget _cardsSliver(List<Map<String, dynamic>> cards, Map<String, dynamic> screen) {
    final layout = _text(screen['layout']).isEmpty ? 'rows' : _text(screen['layout']);
    final columns = (int.tryParse('${screen['grid_columns'] ?? 2}') ?? 2).clamp(1, 2).toInt();

    if (layout == 'grid' && columns > 1) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
        sliver: SliverGrid(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 9,
            mainAxisSpacing: 9,
            childAspectRatio: .88,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) => _PresentationCard(
              card: cards[index],
              compact: false,
              grid: true,
            ),
            childCount: cards.length,
          ),
        ),
      );
    }

    final compact = layout == 'compact';
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: EdgeInsets.only(bottom: index == cards.length - 1 ? 0 : 9),
            child: _PresentationCard(
              card: cards[index],
              compact: compact,
            ),
          ),
          childCount: cards.length,
        ),
      ),
    );
  }
}
