import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';

class ReceiptsSearchScreen extends StatefulWidget {
  const ReceiptsSearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<ReceiptsSearchScreen> createState() => _ReceiptsSearchScreenState();
}

class _ReceiptsSearchScreenState extends State<ReceiptsSearchScreen> {
  late final TextEditingController _query = TextEditingController(text: widget.initialQuery);
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  Future<void> _search() async {
    final value = _query.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final app = context.read<AppController>();
      final home = app.bootstrap!.home;
      final endpoint = '${home['receipts_search_endpoint'] ?? home['search_endpoint'] ?? '/search'}';
      final response = await app.api.get(endpoint.startsWith('/') ? endpoint : '/$endpoint', query: {'q': value, 'search': value});
      final payload = _map(response['payload']).isNotEmpty ? _map(response['payload']) : response;
      final raw = payload['items'] ?? payload['results'] ?? payload['rows'] ?? const [];
      _items = (raw as List? ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (error) {
      _error = '$error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.trim().isNotEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  Widget build(BuildContext context) {
    final branding = context.read<AppController>().bootstrap!.branding;
    return Scaffold(
      backgroundColor: branding.background,
      appBar: AppBar(title: const Text('البحث في الاستلامات')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _query,
              autofocus: widget.initialQuery.isEmpty,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'رقم الاستلام، اسم العميل، الهاتف أو الجهاز',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(onPressed: _search, icon: const Icon(Icons.arrow_back_rounded)),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _error != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
                : _items.isEmpty
                    ? const Center(child: Text('ابدأ بكتابة بيانات الاستلام للبحث.'))
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          final item = _items[index];
                          final title = _first(item, const ['title', 'repair_receipt_number', 'receipt', 'customer_name', 'name']);
                          final subtitle = _first(item, const ['subtitle', 'repair_device_name', 'device', 'phone']);
                          return Card(
                            child: ListTile(
                              leading: const CircleAvatar(child: Icon(Icons.build_outlined)),
                              title: Text(title.isEmpty ? 'استلام' : title, style: const TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: subtitle.isEmpty ? null : Text(subtitle),
                              trailing: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  String _first(Map<String, dynamic> source, List<String> keys) {
    for (final key in keys) {
      final value = '${source[key] ?? ''}'.trim();
      if (value.isNotEmpty && value != 'null') return value;
    }
    return '';
  }
}
