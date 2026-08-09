import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';
import 'formidable_web_screen.dart';

class FormidableNativeScreen extends StatefulWidget {
  const FormidableNativeScreen({super.key, required this.formKey, required this.title});
  final String formKey;
  final String title;

  @override
  State<FormidableNativeScreen> createState() => _FormidableNativeScreenState();
}

class _FormidableNativeScreenState extends State<FormidableNativeScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _schema;
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _values = {};
  final Map<String, List<Map<String, dynamic>>> _dynamicOptions = {};
  final Set<String> _lookupLoading = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await context.read<AppController>().api.get('/forms/${widget.formKey}');
      if (!mounted) return;
      final fields = _list(data['fields']);
      for (final field in fields) {
        final key = _text(field['key']);
        if (key.isEmpty) continue;
        final type = _text(field['type']);
        final defaultValue = field['default'];
        if (type == 'checkbox') {
          _values[key] = defaultValue is List ? List<dynamic>.from(defaultValue) : <dynamic>[];
        } else if (type == 'select' || type == 'radio' || type == 'lookup') {
          _values[key] = _text(defaultValue);
        } else {
          final controller = TextEditingController(text: _text(defaultValue));
          controller.addListener(() => _onControllerChanged(key));
          _controllers[key] = controller;
        }
      }
      _schema = data;
      _recalculate();
      setState(() => _loading = false);
      for (final field in fields.where((f) => _text(f['type']) == 'lookup')) {
        await _refreshLookup(field);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  void _onControllerChanged(String key) {
    _values[key] = _controllers[key]?.text ?? '';
    _afterValueChanged(key);
  }

  void _setValue(String key, dynamic value) {
    _values[key] = value;
    _afterValueChanged(key);
  }

  void _afterValueChanged(String changedKey) {
    _recalculate();
    final fields = _list(_schema?['fields']);
    for (final field in fields) {
      final lookup = _map(field['lookup']);
      final depends = _stringList(lookup['depends_on']);
      if (_text(field['type']) == 'lookup' && depends.contains(changedKey)) {
        _values[_text(field['key'])] = '';
        _refreshLookup(field);
      }
    }
    if (mounted) setState(() {});
  }

  void _recalculate() {
    final fields = _list(_schema?['fields']);
    for (var pass = 0; pass < 3; pass++) {
      for (final field in fields) {
        final calc = _map(field['calculation']);
        final expression = _text(calc['expression']);
        if (expression.isEmpty) continue;
        final key = _text(field['key']);
        final value = _MathEvaluator(expression, _currentValues()).evaluate();
        if (value == null) continue;
        final decimals = int.tryParse('${calc['decimals'] ?? 2}') ?? 2;
        final formatted = value.toStringAsFixed(decimals).replaceFirst(RegExp(r'\.0+$'), '');
        _values[key] = formatted;
        final controller = _controllers[key];
        if (controller != null && controller.text != formatted) {
          controller.value = TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
        }
      }
    }
  }

  Map<String, dynamic> _currentValues() {
    final out = <String, dynamic>{..._values};
    for (final entry in _controllers.entries) out[entry.key] = entry.value.text;
    return out;
  }

  bool _isVisible(Map<String, dynamic> field) {
    final contract = _map(field['conditional']);
    if (contract.isEmpty) return true;
    final rules = _list(contract['rules']);
    if (rules.isEmpty) return true;
    final values = _currentValues();
    final results = rules.map((rule) {
      final actual = values[_text(rule['field'])];
      final expected = rule['value'];
      switch (_text(rule['operator'])) {
        case 'not_equals': return '$actual' != '$expected';
        case 'contains': return '$actual'.toLowerCase().contains('$expected'.toLowerCase());
        case 'gt': return (double.tryParse('$actual') ?? 0) > (double.tryParse('$expected') ?? 0);
        case 'lt': return (double.tryParse('$actual') ?? 0) < (double.tryParse('$expected') ?? 0);
        default: return '$actual' == '$expected';
      }
    }).toList();
    final matched = _text(contract['mode']) == 'any' ? results.any((v) => v) : results.every((v) => v);
    return _text(contract['action']) == 'hide' ? !matched : matched;
  }

  Future<void> _refreshLookup(Map<String, dynamic> field) async {
    final key = _text(field['key']);
    final lookup = _map(field['lookup']);
    final endpoint = _text(lookup['endpoint']);
    if (key.isEmpty || endpoint.isEmpty || _lookupLoading.contains(key)) return;
    setState(() => _lookupLoading.add(key));
    try {
      final result = await context.read<AppController>().api.get(endpoint, query: {'values': jsonEncode(_currentValues())});
      if (!mounted) return;
      setState(() => _dynamicOptions[key] = _list(result['options']));
    } catch (_) {
      if (!mounted) return;
      setState(() => _dynamicOptions[key] = _list(field['options']));
    } finally {
      if (mounted) setState(() => _lookupLoading.remove(key));
    }
  }

  Future<void> _submit() async {
    final schema = _schema;
    if (schema == null || _saving) return;
    _recalculate();
    final fields = _list(schema['fields']);
    final payload = <String, dynamic>{};
    final missing = <String>[];
    final values = _currentValues();

    for (final field in fields) {
      if (!_isVisible(field)) continue;
      final key = _text(field['key']);
      if (key.isEmpty) continue;
      final value = values[key];
      final empty = value == null || (value is String && value.trim().isEmpty) || (value is List && value.isEmpty);
      if (field['required'] == true && empty) missing.add(_text(field['label']).isEmpty ? key : _text(field['label']));
      payload[key] = value;
    }
    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('أكمل الحقول المطلوبة: ${missing.join('، ')}')));
      return;
    }

    setState(() => _saving = true);
    try {
      final result = await context.read<AppController>().api.post('/forms/${widget.formKey}', body: {'fields': payload});
      if (!mounted) return;
      final entryId = result['entry_id'];
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(entryId == null ? 'تم الحفظ بنجاح.' : 'تم الحفظ بنجاح #$entryId')));
      Navigator.pop(context, result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openWebFallback() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => FormidableWebScreen(formKey: widget.formKey, title: widget.title, forceWeb: true)));
  }

  @override
  Widget build(BuildContext context) {
    final schema = _schema;
    final nativeReady = schema?['native_ready'] == true;
    final mode = _text(schema?['mode']);
    final form = _map(schema?['form']);
    final title = _text(form['name']).isNotEmpty ? _text(form['name']) : widget.title;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _load, onWeb: _openWebFallback)
              : mode == 'web' || !nativeReady
                  ? _FallbackState(schema: schema ?? const {}, onWeb: _openWebFallback)
                  : _buildForm(schema ?? const {}),
    );
  }

  Widget _buildForm(Map<String, dynamic> schema) {
    final fields = _list(schema['fields']);
    final visible = fields.where(_isVisible).toList();
    final submitLabel = _text(schema['submit_label']).isNotEmpty ? _text(schema['submit_label']) : 'حفظ';
    final branding = context.read<AppController>().bootstrap!.branding;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        for (final field in visible) ...[
          _NativeField(
            field: field,
            controller: _controllers[_text(field['key'])],
            value: _values[_text(field['key'])],
            options: _text(field['type']) == 'lookup' ? (_dynamicOptions[_text(field['key'])] ?? _list(field['options'])) : _list(field['options']),
            loading: _lookupLoading.contains(_text(field['key'])),
            onChanged: (value) => _setValue(_text(field['key']), value),
          ),
          const SizedBox(height: 14),
        ],
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
          label: Text(submitLabel),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), backgroundColor: branding.primary),
        ),
      ],
    );
  }
}

class _NativeField extends StatelessWidget {
  const _NativeField({required this.field, required this.controller, required this.value, required this.options, required this.loading, required this.onChanged});
  final Map<String, dynamic> field;
  final TextEditingController? controller;
  final dynamic value;
  final List<Map<String, dynamic>> options;
  final bool loading;
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    final type = _text(field['type']);
    final label = _text(field['label']);
    final description = _text(field['description']);
    final required = field['required'] == true;
    final readonly = field['readonly'] == true;
    Widget input;
    if (type == 'select' || type == 'radio' || type == 'lookup') {
      final current = _text(value);
      input = DropdownButtonFormField<String>(
        value: options.any((o) => _text(o['value']) == current) ? current : null,
        isExpanded: true,
        items: options.map((option) => DropdownMenuItem<String>(value: _text(option['value']), child: Text(_text(option['label']).isEmpty ? _text(option['value']) : _text(option['label'])))).toList(),
        onChanged: loading || readonly ? null : onChanged,
        decoration: InputDecoration(suffixIcon: loading ? const Padding(padding: EdgeInsets.all(14), child: SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))) : null),
      );
    } else if (type == 'checkbox') {
      final selected = value is List ? List<dynamic>.from(value) : <dynamic>[];
      input = Wrap(spacing: 8, runSpacing: 8, children: options.map((option) {
        final optionValue = _text(option['value']);
        final checked = selected.map((e) => '$e').contains(optionValue);
        return FilterChip(selected: checked, label: Text(_text(option['label']).isEmpty ? optionValue : _text(option['label'])), onSelected: readonly ? null : (enabled) {
          final next = List<dynamic>.from(selected)..removeWhere((e) => '$e' == optionValue);
          if (enabled) next.add(optionValue);
          onChanged(next);
        });
      }).toList());
    } else {
      var keyboard = TextInputType.text;
      if (type == 'email') keyboard = TextInputType.emailAddress;
      if (type == 'phone') keyboard = TextInputType.phone;
      if (type == 'number') keyboard = const TextInputType.numberWithOptions(decimal: true);
      if (type == 'url') keyboard = TextInputType.url;
      input = TextFormField(
        controller: controller,
        keyboardType: keyboard,
        maxLines: type == 'textarea' ? 4 : 1,
        readOnly: readonly || type == 'date' || type == 'time',
        onTap: readonly ? null : type == 'date' ? () async {
          final picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
          if (picked != null) controller?.text = '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
        } : type == 'time' ? () async {
          final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
          if (picked != null) controller?.text = picked.format(context);
        } : null,
        decoration: InputDecoration(
          filled: readonly,
          suffixIcon: readonly ? const Icon(Icons.calculate_outlined) : type == 'date' ? const Icon(Icons.calendar_month_rounded) : type == 'time' ? const Icon(Icons.schedule_rounded) : null,
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (label.isNotEmpty) Padding(padding: const EdgeInsetsDirectional.only(start: 2, bottom: 7), child: Text(required ? '$label *' : label, style: const TextStyle(fontWeight: FontWeight.w800))),
      input,
      if (description.isNotEmpty) ...[const SizedBox(height: 5), Text(description, style: Theme.of(context).textTheme.bodySmall)],
    ]);
  }
}

class _FallbackState extends StatelessWidget {
  const _FallbackState({required this.schema, required this.onWeb});
  final Map<String, dynamic> schema;
  final VoidCallback onWeb;
  @override
  Widget build(BuildContext context) {
    final unsupported = _list(schema['unsupported_fields']);
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.web_asset_rounded, size: 48), const SizedBox(height: 12),
      const Text('هذا النموذج يحتاج Runtime الكامل.', style: TextStyle(fontWeight: FontWeight.w900)),
      if (unsupported.isNotEmpty) ...[const SizedBox(height: 8), Text(unsupported.map((f) => '${_text(f['label'])} (${_text(f['type'])})').join('، '), textAlign: TextAlign.center)],
      const SizedBox(height: 18), FilledButton(onPressed: onWeb, child: const Text('فتح النموذج الكامل')),
    ])));
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry, required this.onWeb});
  final String message; final VoidCallback onRetry; final VoidCallback onWeb;
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(message, textAlign: TextAlign.center), const SizedBox(height: 14), FilledButton(onPressed: onRetry, child: const Text('إعادة المحاولة')), TextButton(onPressed: onWeb, child: const Text('فتح النسخة الكاملة'))])));
}

class _MathEvaluator {
  _MathEvaluator(this.expression, this.values);
  final String expression; final Map<String, dynamic> values;
  int _i = 0; late String _s;
  double? evaluate() {
    _s = expression.replaceAllMapped(RegExp(r'\[([a-zA-Z0-9_-]+)\]'), (m) => '${double.tryParse('${values[m.group(1)] ?? 0}') ?? 0}').replaceAll('%', '/100');
    _i = 0;
    try { final v = _expr(); _skip(); return _i == _s.length ? v : null; } catch (_) { return null; }
  }
  double _expr() { var v = _term(); while (true) { _skip(); if (_eat('+')) v += _term(); else if (_eat('-')) v -= _term(); else return v; } }
  double _term() { var v = _factor(); while (true) { _skip(); if (_eat('*')) v *= _factor(); else if (_eat('/')) v /= _factor(); else return v; } }
  double _factor() { _skip(); if (_eat('+')) return _factor(); if (_eat('-')) return -_factor(); if (_eat('(')) { final v = _expr(); if (!_eat(')')) throw const FormatException(); return v; } final start = _i; while (_i < _s.length && RegExp(r'[0-9.]').hasMatch(_s[_i])) _i++; if (start == _i) throw const FormatException(); return double.parse(_s.substring(start, _i)); }
  bool _eat(String c) { _skip(); if (_i < _s.length && _s[_i] == c) { _i++; return true; } return false; }
  void _skip() { while (_i < _s.length && _s[_i].trim().isEmpty) _i++; }
}

Map<String, dynamic> _map(dynamic value) => value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<Map<String, dynamic>> _list(dynamic value) => value is List ? value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];
List<String> _stringList(dynamic value) => value is List ? value.map((e) => _text(e)).where((e) => e.isNotEmpty).toList() : const [];
String _text(dynamic value) { if (value == null) return ''; final text = '$value'.trim(); if (text.isEmpty || text.toLowerCase() == 'null' || text.toLowerCase() == 'undefined') return ''; return text; }
