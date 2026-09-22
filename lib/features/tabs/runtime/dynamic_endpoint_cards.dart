part of '../dynamic_endpoint_screen.dart';

class _PresentationCard extends StatelessWidget {
  const _PresentationCard({
    required this.card,
    this.compact = false,
    this.grid = false,
  });

  final Map<String, dynamic> card;
  final bool compact;
  final bool grid;

  @override
  Widget build(BuildContext context) {
    final fields = _map(card['fields']);
    final title = _text(card['title']);
    final subtitle = _text(card['subtitle']);
    final image = _text(card['image']);
    final primary = _field(fields, 'primary_value');
    final secondary = _field(fields, 'secondary_value');
    final badge = _field(fields, 'badge');
    final reference = _field(fields, 'reference');
    final date = _field(fields, 'date');

    final primaryText = _fieldValue(primary);
    final numeric = double.tryParse(primaryText.replaceAll(',', ''));
    final accent = numeric != null && numeric <= 0
        ? context.nz.danger
        : numeric != null && numeric <= 5
            ? context.nz.warning
            : context.nz.primary;

    return Container(
      padding: EdgeInsets.all(compact ? 10 : (grid ? 12 : 13)),
      decoration: BoxDecoration(
        color: context.nz.surface,
        borderRadius: BorderRadius.circular(12),
        // BoxDecoration cannot combine borderRadius with non-uniform Border
        // colors. Keep a uniform outline; the accent is drawn separately.
        border: Border.all(color: context.nz.border),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: .055),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            start: 0,
            top: 4,
            bottom: 4,
            child: Container(
              width: 2.5,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 5),
            child: grid
          ? _gridContent(
              context,
              title: title,
              subtitle: subtitle,
              image: image,
              primary: primary,
              secondary: secondary,
              badge: badge,
              reference: reference,
              date: date,
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (image.isNotEmpty) ...[
                  _CardImage(url: image, compact: compact),
                  const SizedBox(width: 11),
                ],
                Expanded(
                  child: _mainContent(
                    context,
                    title: title,
                    subtitle: subtitle,
                    primary: primary,
                    secondary: secondary,
                    badge: badge,
                    reference: reference,
                    date: date,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridContent(
    BuildContext context, {
    required String title,
    required String subtitle,
    required String image,
    required Map<String, dynamic> primary,
    required Map<String, dynamic> secondary,
    required Map<String, dynamic> badge,
    required Map<String, dynamic> reference,
    required Map<String, dynamic> date,
  }) {
    if (image.isEmpty) {
      return _noImageGridContent(
        context,
        title: title,
        subtitle: subtitle,
        primary: primary,
        secondary: secondary,
        badge: badge,
        reference: reference,
        date: date,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (image.isNotEmpty) ...[
          SizedBox(
            height: 58,
            width: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                image,
                fit: BoxFit.cover,
                cacheWidth: 480,
                filterQuality: FilterQuality.low,
                errorBuilder: (_, __, ___) => Container(
                  color: context.nz.surfaceSoft,
                  child: Icon(Icons.image_not_supported_outlined, color: context.nz.muted),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Expanded(
          child: _mainContent(
            context,
            title: title,
            subtitle: subtitle,
            primary: primary,
            secondary: secondary,
            badge: badge,
            reference: reference,
            date: date,
          ),
        ),
      ],
    );
  }

  Widget _noImageGridContent(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Map<String, dynamic> primary,
    required Map<String, dynamic> secondary,
    required Map<String, dynamic> badge,
    required Map<String, dynamic> reference,
    required Map<String, dynamic> date,
  }) {
    final primaryValue = _fieldValue(primary);
    final secondaryValue = _fieldValue(secondary);
    final primaryLabel = _fieldLabel(primary).isEmpty ? 'سعر البيع' : _fieldLabel(primary);
    final secondaryLabel = _fieldLabel(secondary).isEmpty ? 'سعر التكلفة' : _fieldLabel(secondary);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title.isEmpty ? '—' : title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.start,
                style: TextStyle(
                  color: context.nz.text,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  height: 1.28,
                ),
              ),
            ),
            if (_fieldValue(badge).isNotEmpty) ...[
              const SizedBox(width: 6),
              _ValuePill(field: badge, accent: true),
            ],
          ],
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.nz.muted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (_fieldValue(reference).isNotEmpty || _fieldValue(date).isNotEmpty) ...[
          const SizedBox(height: 7),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              if (_fieldValue(reference).isNotEmpty) _ValuePill(field: reference),
              if (_fieldValue(date).isNotEmpty)
                _ValuePill(field: date, icon: Icons.schedule_rounded),
            ],
          ),
        ],
        const Spacer(),
        if (primaryValue.isNotEmpty || secondaryValue.isNotEmpty)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (secondaryValue.isNotEmpty)
                Expanded(
                  child: _PricePanel(
                    label: secondaryLabel,
                    value: secondaryValue,
                    selling: false,
                  ),
                ),
              if (primaryValue.isNotEmpty && secondaryValue.isNotEmpty)
                const SizedBox(width: 7),
              if (primaryValue.isNotEmpty)
                Expanded(
                  child: _PricePanel(
                    label: primaryLabel,
                    value: primaryValue,
                    selling: true,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _mainContent(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Map<String, dynamic> primary,
    required Map<String, dynamic> secondary,
    required Map<String, dynamic> badge,
    required Map<String, dynamic> reference,
    required Map<String, dynamic> date,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                title.isEmpty ? '—' : title,
                maxLines: grid ? 2 : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.nz.text,
                  fontSize: compact ? 14 : (grid ? 14.5 : 15.5),
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
              ),
            ),
            if (_fieldValue(badge).isNotEmpty) ...[
              const SizedBox(width: 8),
              _ValuePill(field: badge, accent: true),
            ],
          ],
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.nz.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
        if (_fieldValue(primary).isNotEmpty) ...[
          SizedBox(height: compact ? 7 : 10),
          Text(
            _fieldValue(primary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.nz.text,
              fontSize: compact ? 18 : (grid ? 22 : 20),
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          if (_fieldShowLabel(primary) && _fieldLabel(primary).isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              _fieldLabel(primary),
              style: TextStyle(color: context.nz.muted, fontSize: 10.5),
            ),
          ],
        ],
        if (!compact) ...[
          const SizedBox(height: 9),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (_fieldValue(secondary).isNotEmpty) _ValuePill(field: secondary),
              if (_fieldValue(reference).isNotEmpty) _ValuePill(field: reference),
              if (_fieldValue(date).isNotEmpty)
                _ValuePill(field: date, icon: Icons.schedule_rounded),
            ],
          ),
        ],
      ],
    );
  }
}

class _PricePanel extends StatelessWidget {
  const _PricePanel({
    required this.label,
    required this.value,
    required this.selling,
  });

  final String label;
  final String value;
  final bool selling;

  @override
  Widget build(BuildContext context) {
    final tint = selling ? context.nz.success : context.nz.primary;
    return Container(
      constraints: const BoxConstraints(minHeight: 67),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: Color.alphaBlend(tint.withValues(alpha: .09), context.nz.surface),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: tint.withValues(alpha: .13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                selling ? Icons.sell_rounded : Icons.stacked_bar_chart_rounded,
                size: 13,
                color: tint,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tint,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.nz.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValuePill extends StatelessWidget {
  const _ValuePill({required this.field, this.accent = false, this.icon});

  final Map<String, dynamic> field;
  final bool accent;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final label = _fieldLabel(field);
    final value = _fieldValue(field);
    final showLabel = _fieldShowLabel(field) && label.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: accent ? context.nz.primarySoft : context.nz.surfaceSoft,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: accent ? context.nz.primary.withValues(alpha: .22) : context.nz.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: accent ? context.nz.primary : context.nz.muted),
            const SizedBox(width: 4),
          ],
          Text(
            showLabel ? '$label: $value' : value,
            style: TextStyle(
              color: accent ? context.nz.primary : context.nz.text,
              fontSize: 10.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardImage extends StatelessWidget {
  const _CardImage({required this.url, required this.compact});

  final String url;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 44.0 : 58.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: 240,
        cacheHeight: 240,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: context.nz.surfaceSoft,
          child: Icon(Icons.image_outlined, color: context.nz.muted),
        ),
      ),
    );
  }
}

class _GroupBrowser extends StatefulWidget {
  const _GroupBrowser({
    required this.groups,
    required this.cards,
    required this.screen,
    this.showCards = true,
  });

  final List<Map<String, dynamic>> groups;
  final List<Map<String, dynamic>> cards;
  final Map<String, dynamic> screen;
  final bool showCards;

  @override
  State<_GroupBrowser> createState() => _GroupBrowserState();
}

class _GroupBrowserState extends State<_GroupBrowser> {
  final List<int> _selected = <int>[0];

  @override
  Widget build(BuildContext context) {
    final selectedPath = <Map<String, dynamic>>[];
    var layer = widget.groups;
    var depth = 0;
    while (layer.isNotEmpty) {
      final requested = depth < _selected.length ? _selected[depth] : 0;
      final index = requested >= 0 && requested < layer.length ? requested : 0;
      final group = layer[index];
      selectedPath.add(group);
      layer = _listOfMaps(group['children']);
      depth++;
    }

    final selected = selectedPath.isEmpty ? <String, dynamic>{} : selectedPath.last;
    final cards = _cardsForGroup(selected, widget.cards);
    final kpis = _flattenKpis(selected['kpis']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var level = 0; level < selectedPath.length; level++)
          _groupTabs(level),
        if (kpis.isNotEmpty) ...[
          const SizedBox(height: 2),
          _KpiStrip(
            items: kpis,
            activeFilters: const <String, String>{},
            onFilter: (_, __) async {},
          ),
        ],
        if (!widget.showCards)
          const SizedBox.shrink()
        else if (cards.isEmpty)
          const NzEmptyState(
            title: 'لا توجد نتائج في هذه المجموعة',
            message: 'اختر مجموعة أخرى أو غيّر الفلاتر.',
          )
        else
          _groupCards(cards),
      ],
    );
  }

  Widget _groupCards(List<Map<String, dynamic>> cards) {
    final layout = _text(widget.screen['layout']);
    if (layout == 'grid') {
      // This browser itself lives inside a SliverToBoxAdapter. A nested
      // GridView/ListView here can enter layout with unbounded height and
      // trigger RenderBox/sliver assertions. Build finite rows instead.
      return LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final itemWidth = (width - 10) / 2;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final card in cards)
                SizedBox(
                  width: itemWidth,
                  child: AspectRatio(
                    aspectRatio: 1.18,
                    child: _PresentationCard(card: card, grid: true),
                  ),
                ),
            ],
          );
        },
      );
    }

    final compact = layout == 'compact';
    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          _PresentationCard(card: cards[i], compact: compact),
          if (i != cards.length - 1) const SizedBox(height: 9),
        ],
      ],
    );
  }

  Widget _groupTabs(int level) {
    var layer = widget.groups;
    for (var i = 0; i < level; i++) {
      if (layer.isEmpty) return const SizedBox.shrink();
      final requested = i < _selected.length ? _selected[i] : 0;
      final parent = requested >= 0 && requested < layer.length ? requested : 0;
      layer = _listOfMaps(layer[parent]['children']);
    }
    if (layer.isEmpty) return const SizedBox.shrink();

    final requestedIndex = _selected.length > level ? _selected[level] : 0;
    final selectedIndex = requestedIndex >= 0 && requestedIndex < layer.length ? requestedIndex : 0;
    final sourceLabel = _text(layer.first['source_label']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sourceLabel.isNotEmpty) ...[
            Text(
              sourceLabel,
              style: TextStyle(
                color: context.nz.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
          ],
          SizedBox(
            height: 39,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: layer.length,
              separatorBuilder: (_, __) => const SizedBox(width: 7),
              itemBuilder: (_, index) {
                final item = layer[index];
                return NzFilterChip(
                  label: _text(item['label']),
                  count: _text(item['count']),
                  selected: selectedIndex == index,
                  onSelected: () {
                    setState(() {
                      while (_selected.length <= level) _selected.add(0);
                      _selected[level] = index;
                      if (_selected.length > level + 1) {
                        _selected.removeRange(level + 1, _selected.length);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _cardsForGroup(
    Map<String, dynamic> group,
    List<Map<String, dynamic>> cards,
  ) {
    final ids = <int>{};
    for (final value in (group['entry_ids'] as List? ?? const [])) {
      final id = int.tryParse('$value');
      if (id != null) ids.add(id);
    }
    for (final row in _listOfMaps(group['rows'])) {
      final id = int.tryParse('${row['entry_id'] ?? row['id'] ?? ''}');
      if (id != null) ids.add(id);
    }
    // Group metadata is only a filter over cards already returned by the
    // independent rows request. It never participates in fetching the cards.
    if (ids.isEmpty) return cards;
    return cards.where((card) {
      final id = int.tryParse('${card['entry_id'] ?? card['id'] ?? ''}');
      return id != null && ids.contains(id);
    }).toList();
  }
}
