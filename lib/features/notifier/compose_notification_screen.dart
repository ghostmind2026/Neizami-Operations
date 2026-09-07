import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';

class ComposeNotificationScreen extends StatefulWidget {
  const ComposeNotificationScreen({super.key});

  @override
  State<ComposeNotificationScreen> createState() =>
      _ComposeNotificationScreenState();
}

class _ComposeNotificationScreenState extends State<ComposeNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _message = TextEditingController();

  bool _loading = true;
  bool _sending = false;
  bool _warning = false;
  bool _positive = false;
  String? _loadError;
  String _recipientType = 'user';
  String? _recipient;
  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _roles = const [];
  late final AppController _app;

  @override
  void initState() {
    super.initState();
    _app = context.read<AppController>();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final response = await _app.api.get('/notifications/compose');
      final payload = _map(response['payload']).isNotEmpty
          ? _map(response['payload'])
          : response;
      _users = _list(payload['users']);
      _roles = _list(payload['roles']);
    } catch (error) {
      _loadError = '$error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    if (_recipientType != 'all' &&
        (_recipient == null || _recipient!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('اختر مستلمًا.')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      await _app.api.post('/notifications', body: {
        'recipient_type': _recipientType,
        'recipient': _recipient,
        'title': _title.text.trim(),
        'message': _message.text.trim(),
        'with_warning': _warning,
        'with_positive': _positive,
      });

      if (!mounted) return;

      unawaited(_app.refreshDashboard());
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الإشعار.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branding = context.read<AppController>().bootstrap!.branding;
    return Scaffold(
      backgroundColor: branding.background,
      appBar: AppBar(title: const Text('إرسال إشعار')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 48),
                        const SizedBox(height: 12),
                        Text(_loadError!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(18),
                    children: [
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'user',
                            label: Text('موظف'),
                            icon: Icon(Icons.person_outline),
                          ),
                          ButtonSegment(
                            value: 'role',
                            label: Text('دور'),
                            icon: Icon(Icons.groups_outlined),
                          ),
                          ButtonSegment(
                            value: 'all',
                            label: Text('الجميع'),
                            icon: Icon(Icons.campaign_outlined),
                          ),
                        ],
                        selected: {_recipientType},
                        onSelectionChanged: (value) => setState(() {
                          _recipientType = value.first;
                          _recipient = null;
                        }),
                      ),
                      const SizedBox(height: 18),
                      if (_recipientType != 'all')
                        DropdownButtonFormField<String>(
                          value: _recipient,
                          decoration: InputDecoration(
                            labelText: _recipientType == 'user'
                                ? 'الموظف'
                                : 'الدور',
                          ),
                          items: [
                            for (final item
                                in (_recipientType == 'user' ? _users : _roles))
                              if (_valueOf(item).isNotEmpty)
                                DropdownMenuItem<String>(
                                  value: _valueOf(item),
                                  child: Text(_labelOf(item)),
                                ),
                          ],
                          onChanged: (value) =>
                              setState(() => _recipient = value),
                        ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _title,
                        decoration: const InputDecoration(labelText: 'العنوان'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'العنوان مطلوب.'
                                : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _message,
                        minLines: 5,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'نص الإشعار',
                          alignLabelWithHint: true,
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'نص الإشعار مطلوب.'
                                : null,
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        value: _warning,
                        onChanged: (value) =>
                            setState(() => _warning = value),
                        title: const Text('كرت تنبيه'),
                        subtitle: const Text(
                          'يظهر ضمن الكروت التحذيرية للموظف.',
                        ),
                      ),
                      SwitchListTile(
                        value: _positive,
                        onChanged: (value) =>
                            setState(() => _positive = value),
                        title: const Text('نجمة إيجابية'),
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: const Text('إرسال الإشعار'),
                      ),
                    ],
                  ),
                ),
    );
  }

  String _valueOf(Map<String, dynamic> item) {
    return '${item['id'] ?? item['value'] ?? item['key'] ?? ''}'.trim();
  }

  String _labelOf(Map<String, dynamic> item) {
    final label =
        '${item['name'] ?? item['label'] ?? item['title'] ?? ''}'.trim();
    return label.isEmpty ? _valueOf(item) : label;
  }

  Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _list(dynamic value) {
    return (value as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}
