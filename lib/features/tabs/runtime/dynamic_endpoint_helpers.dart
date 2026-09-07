part of '../dynamic_endpoint_screen.dart';

Map<String, dynamic> _compactPresentation(Map<String, dynamic> source) {
  return <String, dynamic>{
    if (source['screen'] != null) 'screen': source['screen'],
    if (source['search'] != null) 'search': source['search'],
    if (source['filters'] != null) 'filters': source['filters'],
    if (source['sort'] != null) 'sort': source['sort'],
    if (source['hide_zero'] != null) 'hide_zero': source['hide_zero'],
    if (source['kpis'] != null) 'kpis': source['kpis'],
    if (source['groups'] != null) 'groups': source['groups'],
    'cards': _listOfMaps(source['cards']),
    if (source['pagination'] != null) 'pagination': source['pagination'],
  };
}

Map<String, dynamic> _mergePayload(
  Map<String, dynamic>? current,
  Map<String, dynamic> incoming,
) {
  if (current == null) return incoming;
  final oldPresentation = _compactPresentation(_map(current['presentation']));
  final newPresentation = _compactPresentation(_map(incoming['presentation']));
  final mergedCards = <Map<String, dynamic>>[];
  final seen = <String>{};

  for (final card in <Map<String, dynamic>>[
    ..._listOfMaps(oldPresentation['cards']),
    ..._listOfMaps(newPresentation['cards']),
  ]) {
    final id = _text(card['entry_id'] ?? card['id']);
    final signature = id.isNotEmpty
        ? 'id:$id'
        : 'row:${_text(card['title'])}|${_text(card['subtitle'])}|${_text(card['primary_value'])}';
    if (seen.add(signature)) mergedCards.add(card);
  }

  final mergedGroups = _mergeGroupTrees(
    _listOfMaps(oldPresentation['groups']),
    _listOfMaps(newPresentation['groups']),
  );

  return <String, dynamic>{
    'tab': incoming['tab'] ?? current['tab'],
    'presentation': <String, dynamic>{
      ...oldPresentation,
      ...newPresentation,
      'cards': mergedCards,
      if (mergedGroups.isNotEmpty) 'groups': mergedGroups,
    },
  };
}

List<Map<String, dynamic>> _mergeGroupTrees(
  List<Map<String, dynamic>> oldGroups,
  List<Map<String, dynamic>> newGroups,
) {
  if (oldGroups.isEmpty) return newGroups;
  if (newGroups.isEmpty) return oldGroups;

  final merged = oldGroups.map((g) => Map<String, dynamic>.from(g)).toList();
  for (final incoming in newGroups) {
    final signature = _groupSignature(incoming);
    final index = merged.indexWhere((item) => _groupSignature(item) == signature);
    if (index < 0) {
      merged.add(Map<String, dynamic>.from(incoming));
      continue;
    }

    final previous = merged[index];
    final ids = <String>{
      ..._groupEntryIds(previous),
      ..._groupEntryIds(incoming),
    };
    final children = _mergeGroupTrees(
      _listOfMaps(previous['children']),
      _listOfMaps(incoming['children']),
    );
    merged[index] = <String, dynamic>{
      ...previous,
      ...incoming,
      if (ids.isNotEmpty) 'entry_ids': ids.toList(),
      if (children.isNotEmpty) 'children': children,
    };
  }
  return merged;
}

String _groupSignature(Map<String, dynamic> group) {
  return _firstUseful([
    group['key'],
    group['id'],
    group['value'],
    group['label'],
    group['title'],
  ]);
}

Set<String> _groupEntryIds(Map<String, dynamic> group) {
  final out = <String>{};
  for (final value in (group['entry_ids'] as List? ?? const [])) {
    final id = _text(value);
    if (id.isNotEmpty) out.add(id);
  }
  for (final row in _listOfMaps(group['rows'])) {
    final id = _firstUseful([row['entry_id'], row['id']]);
    if (id.isNotEmpty) out.add(id);
  }
  return out;
}

int _pageFrom(Map<String, dynamic> data, int fallback) {
  final pagination = _findPagination(data);
  return int.tryParse('${pagination['page'] ?? pagination['current_page'] ?? ''}') ?? fallback;
}

bool _hasMoreFrom(
  Map<String, dynamic> data, {
  required int page,
  required int pageSize,
}) {
  final pagination = _findPagination(data);
  final explicit = pagination['has_more'] ?? pagination['hasMore'];
  if (explicit is bool) return explicit;
  if ('$explicit' == '1' || '$explicit'.toLowerCase() == 'true') return true;
  if ('$explicit' == '0' || '$explicit'.toLowerCase() == 'false') return false;

  final totalPages = int.tryParse(
    '${pagination['total_pages'] ?? pagination['pages'] ?? pagination['last_page'] ?? ''}',
  );
  if (totalPages != null) return page < totalPages;

  final total = int.tryParse('${pagination['total'] ?? pagination['total_items'] ?? ''}');
  final perPage = int.tryParse('${pagination['per_page'] ?? pagination['limit'] ?? ''}') ?? pageSize;
  if (total != null) return page * perPage < total;

  final cards = _listOfMaps(_map(data['presentation'])['cards']);
  return cards.length >= pageSize;
}

Map<String, dynamic> _findPagination(dynamic value, [int depth = 0]) {
  if (depth > 5) return <String, dynamic>{};
  if (value is Map) {
    final map = Map<String, dynamic>.from(value);
    for (final key in const ['pagination', 'pager', 'meta']) {
      final found = _map(map[key]);
      if (_looksLikePagination(found)) return found;
    }
    if (_looksLikePagination(map)) return map;
    for (final child in map.values) {
      final found = _findPagination(child, depth + 1);
      if (found.isNotEmpty) return found;
    }
  }
  return <String, dynamic>{};
}

bool _looksLikePagination(Map<String, dynamic> map) {
  return map.containsKey('page') ||
      map.containsKey('current_page') ||
      map.containsKey('total_pages') ||
      map.containsKey('has_more') ||
      (map.containsKey('total') && (map.containsKey('per_page') || map.containsKey('limit')));
}

List<Map<String, dynamic>> _filterDefinitions(dynamic value) {
  final items = <Map<String, dynamic>>[];
  if (value is List) {
    items.addAll(
      value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
    );
  } else if (value is Map) {
    for (final entry in value.entries) {
      if (entry.value is Map) {
        items.add(<String, dynamic>{
          'key': '${entry.key}',
          ...Map<String, dynamic>.from(entry.value as Map),
        });
      }
    }
  }
  return items
      .where((e) => _filterKey(e).isNotEmpty && _filterOptions(e).isNotEmpty)
      .toList();
}

String _filterKey(Map<String, dynamic> filter) {
  return _firstUseful([filter['key'], filter['field'], filter['field_key'], filter['name']]);
}

String _filterLabel(Map<String, dynamic> filter, String fallback) {
  return _firstUseful([filter['label'], filter['title'], filter['name'], fallback]);
}

List<Map<String, dynamic>> _filterOptions(Map<String, dynamic> filter) {
  final raw = filter['options'] ?? filter['values'] ?? filter['items'];
  if (raw is List) {
    return raw.map((item) {
      if (item is Map) return Map<String, dynamic>.from(item);
      return <String, dynamic>{'value': '$item', 'label': '$item'};
    }).toList();
  }
  if (raw is Map) {
    return raw.entries
        .map((e) => <String, dynamic>{'value': '${e.key}', 'label': '${e.key}', 'count': e.value})
        .toList();
  }
  return const <Map<String, dynamic>>[];
}

String _optionValue(Map<String, dynamic> option) {
  return _firstUseful([option['value'], option['key'], option['id'], option['label']]);
}

String _optionLabel(Map<String, dynamic> option) {
  return _firstUseful([option['label'], option['name'], option['title'], option['value']]);
}

String? _optionCount(Map<String, dynamic> option) {
  final value = _firstUseful([option['count'], option['rows'], option['total']]);
  return value.isEmpty ? null : value;
}

List<Map<String, dynamic>> _flattenKpis(dynamic raw) {
  final input = _listOfMaps(raw);
  final out = <Map<String, dynamic>>[];
  for (final item in input) {
    final cards = _listOfMaps(item['cards']);
    if (cards.isEmpty) {
      final label = _firstUseful([item['label'], item['title'], item['name']]);
      final value = _firstUseful([item['value'], item['count'], item['total']]);
      if (label.isNotEmpty || value.isNotEmpty) out.add(item);
      continue;
    }
    final inheritedKey = _firstUseful([item['filter_key'], item['key']]);
    for (final card in cards) {
      out.add(<String, dynamic>{
        ...card,
        if (_text(card['filter_key']).isEmpty && inheritedKey.isNotEmpty) 'filter_key': inheritedKey,
      });
    }
  }
  return out;
}

Map<String, dynamic> _field(Map<String, dynamic> fields, String key) {
  return _map(fields[key]);
}

String _fieldValue(Map<String, dynamic> field) => _text(field['value']);
String _fieldLabel(Map<String, dynamic> field) => _text(field['label']);
bool _fieldShowLabel(Map<String, dynamic> field) => field['show_label'] == true;

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _listOfMaps(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

String _firstUseful(List<dynamic> values) {
  for (final value in values) {
    final text = _text(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _text(dynamic value) {
  if (value == null) return '';
  final text = '$value'.trim();
  if (text.isEmpty || text.toLowerCase() == 'null' || text.toLowerCase() == 'undefined') {
    return '';
  }
  return text;
}
