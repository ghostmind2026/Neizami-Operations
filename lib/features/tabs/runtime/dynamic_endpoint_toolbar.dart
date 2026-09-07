part of '../dynamic_endpoint_screen.dart';

class _EndpointToolbar extends StatelessWidget {
  const _EndpointToolbar({
    required this.controller,
    required this.showSearch,
    required this.searchBusy,
    required this.searchTooShort,
    required this.minSearchChars,
    required this.hintText,
    required this.filters,
    required this.activeFilters,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onClearSearch,
    required this.onOpenFilters,
    required this.onQuickFilter,
    required this.onClearFilters,
  });

  final TextEditingController controller;
  final bool showSearch;
  final bool searchBusy;
  final bool searchTooShort;
  final int minSearchChars;
  final String hintText;
  final List<Map<String, dynamic>> filters;
  final Map<String, String> activeFilters;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onClearSearch;
  final VoidCallback onOpenFilters;
  final Future<void> Function(String key, String value) onQuickFilter;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final first = filters.isEmpty ? <String, dynamic>{} : filters.first;
    final firstKey = _filterKey(first);
    final firstOptions = firstKey.isEmpty ? const <Map<String, dynamic>>[] : _filterOptions(first);

    return Container(
      color: context.nz.background,
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
      child: Column(
        children: [
          if (showSearch)
            Row(
              children: [
                Expanded(
                  child: NzSearchField(
                    controller: controller,
                    onChanged: onSearchChanged,
                    onSubmitted: onSearchSubmitted,
                    onClear: onClearSearch,
                    hintText: hintText,
                    busy: searchBusy,
                  ),
                ),
                if (filters.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Badge(
                    isLabelVisible: activeFilters.isNotEmpty,
                    label: Text('${activeFilters.length}'),
                    child: IconButton.filledTonal(
                      tooltip: 'الفلاتر',
                      onPressed: onOpenFilters,
                      icon: const Icon(Icons.tune_rounded),
                    ),
                  ),
                ],
              ],
            )
          else if (filters.isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                onPressed: onOpenFilters,
                icon: const Icon(Icons.tune_rounded),
                label: Text(
                  activeFilters.isEmpty ? 'الفلاتر' : 'الفلاتر (${activeFilters.length})',
                ),
              ),
            ),
          if (searchTooShort) ...[
            const SizedBox(height: 5),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                'اكتب $minSearchChars أحرف على الأقل للبحث.',
                style: TextStyle(color: context.nz.muted, fontSize: 11.5),
              ),
            ),
          ],
          if (firstOptions.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: firstOptions.take(10).length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 7),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return NzFilterChip(
                      label: activeFilters.isEmpty ? 'الكل' : 'مسح الفلاتر',
                      selected: activeFilters.isEmpty,
                      icon: activeFilters.isEmpty ? Icons.done_rounded : Icons.close_rounded,
                      onSelected: onClearFilters,
                    );
                  }
                  final option = firstOptions[index - 1];
                  final value = _optionValue(option);
                  return NzFilterChip(
                    label: _optionLabel(option),
                    count: _optionCount(option),
                    selected: activeFilters[firstKey] == value,
                    onSelected: () => onQuickFilter(firstKey, value),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KpiStrip extends StatelessWidget {
  const _KpiStrip({
    required this.items,
    required this.activeFilters,
    required this.onFilter,
  });

  final List<Map<String, dynamic>> items;
  final Map<String, String> activeFilters;
  final Future<void> Function(String key, String value) onFilter;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final label = _firstUseful([item['label'], item['title'], item['name']]);
          final value = _firstUseful([item['value'], item['total'], item['count']]);
          final filterKey = _text(item['filter_key']);
          final filterValue = _text(item['filter_value']);
          final active = filterKey.isNotEmpty && activeFilters[filterKey] == filterValue;
          return GestureDetector(
            onTap: filterKey.isEmpty ? null : () => onFilter(filterKey, filterValue),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 132,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: active ? context.nz.primarySoft : context.nz.surface,
                borderRadius: BorderRadius.circular(context.nz.radius),
                border: Border.all(
                  color: active ? context.nz.primary : context.nz.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: context.nz.text.withValues(alpha: .03),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.nz.text,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active ? context.nz.primary : context.nz.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
