import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';
import 'formidable_web_screen.dart';

class FormidableNativeScreen extends StatefulWidget {
  const FormidableNativeScreen({
    super.key,
    required this.formKey,
    required this.title,
  });

  final String formKey;
  final String title;

  @override
  State<FormidableNativeScreen> createState() =>
      _FormidableNativeScreenState();
}

class _FormidableNativeScreenState extends State<FormidableNativeScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _schema;

  final Map<String, TextEditingController> _controllers = {};
  final Map<String, dynamic> _values = {};

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
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final data = await context
          .read<AppController>()
          .api
          .get('/forms/${widget.formKey}');

      if (!mounted) return;

      for (final controller in _controllers.values) {
        controller.dispose();
      }
      _controllers.clear();
      _values.clear();

      final fields = _fieldsOf(data);
      for (final field in fields) {
        final key = _text(field['key']);
        if (key.isEmpty || !_isSupported(field)) continue;

        final type = _typeOf(field);
        final defaultValue = field['default'];

        if (type == 'checkbox') {
          if (defaultValue is List) {
            _values[key] = List<dynamic>.from(defaultValue);
          } else {
            final value = _text(defaultValue);
            _values[key] = value.isEmpty ? <dynamic>[] : <dynamic>[value];
          }
        } else if (type == 'select') {
          _values[key] = _text(defaultValue);
        } else {
          _controllers[key] = TextEditingController(
            text: _text(defaultValue),
          );
        }
      }

      setState(() {
        _schema = data;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _submit() async {
    final schema = _schema;
    if (schema == null || _saving) return;

    final fields = _fieldsOf(schema).where(_isSupported).toList();
    final payload = <String, dynamic>{};
    final missing = <String>[];

    for (final field in fields) {
      final key = _text(field['key']);
      if (key.isEmpty) continue;

      final type = _typeOf(field);
      final value = type == 'text' || type == 'number'
          ? (_controllers[key]?.text ?? '')
          : _values[key];

      final empty = value == null ||
          (value is String && value.trim().isEmpty) ||
          (value is List && value.isEmpty);

      if (field['required'] == true && empty) {
        final label = _text(field['label']);
        missing.add(label.isEmpty ? key : label);
      }

      payload[key] = value;
    }

    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('أكمل الحقول المطلوبة: ${missing.join('، ')}'),
        ),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final result = await context.read<AppController>().api.post(
        '/forms/${widget.formKey}',
        body: {'fields': payload},
      );

      if (!mounted) return;

      final entryId = result['entry_id'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            entryId == null
                ? 'تم الحفظ بنجاح.'
                : 'تم الحفظ بنجاح #$entryId',
          ),
        ),
      );
      Navigator.pop(context, result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openWebFallback() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FormidableWebScreen(
          formKey: widget.formKey,
          title: widget.title,
          forceWeb: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schema = _schema;
    final fields = _fieldsOf(schema);
    final unsupported = fields.where((field) => !_isSupported(field)).toList();
    final mode = _text(schema?['mode']);
    final form = _map(schema?['form']);
    final title = _text(form['name']).isNotEmpty
        ? _text(form['name'])
        : widget.title;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(
                  message: _error!,
                  onRetry: _load,
                  onWeb: _openWebFallback,
                )
              : mode == 'web' || unsupported.isNotEmpty
                  ? _FallbackState(
                      unsupported: unsupported,
                      onWeb: _openWebFallback,
                    )
                  : _buildForm(schema ?? const {}),
    );
  }

  Widget _buildForm(Map<String, dynamic> schema) {
    final fields = _fieldsOf(schema).where(_isSupported).toList();
    final submitLabel = _text(schema['submit_label']).isNotEmpty
        ? _text(schema['submit_label'])
        : 'حفظ';
    final branding = context.read<AppController>().bootstrap!.branding;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        for (final field in fields) ...[
          _SimpleNativeField(
            field: field,
            controller: _controllers[_text(field['key'])],
            value: _values[_text(field['key'])],
            onChanged: (value) {
              setState(() => _values[_text(field['key'])] = value);
            },
          ),
          const SizedBox(height: 14),
        ],
        FilledButton.icon(
          onPressed: _saving ? null : _submit,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: Text(submitLabel),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: branding.primary,
          ),
        ),
      ],
    );
  }
}

class _SimpleNativeField extends StatelessWidget {
  const _SimpleNativeField({
    required this.field,
    required this.controller,
    required this.value,
    required this.onChanged,
  });

  final Map<String, dynamic> field;
  final TextEditingController? controller;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    final type = _typeOf(field);
    final label = _text(field['label']);
    final description = _text(field['description']);
    final required = field['required'] == true;
    final readonly = field['readonly'] == true;
    final options = _optionsOf(field['options']);

    Widget input;

    if (type == 'select') {
      final current = _text(value);
      input = DropdownButtonFormField<String>(
        value: options.any((option) => option.value == current)
            ? current
            : null,
        isExpanded: true,
        items: [
          for (final option in options)
            DropdownMenuItem<String>(
              value: option.value,
              child: Text(option.label),
            ),
        ],
        onChanged: readonly ? null : onChanged,
      );
    } else if (type == 'checkbox') {
      final selected = value is List
          ? value.map((item) => '$item').toSet()
          : <String>{};

      input = Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            FilterChip(
              selected: selected.contains(option.value),
              label: Text(option.label),
              onSelected: readonly
                  ? null
                  : (enabled) {
                      final next = <String>{...selected};
                      if (enabled) {
                        next.add(option.value);
                      } else {
                        next.remove(option.value);
                      }
                      onChanged(next.toList());
                    },
            ),
        ],
      );
    } else {
      input = TextFormField(
        controller: controller,
        readOnly: readonly,
        keyboardType: type == 'number'
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 2, bottom: 7),
            child: Text(
              required ? '$label *' : label,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        input,
        if (description.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _FallbackState extends StatelessWidget {
  const _FallbackState({
    required this.unsupported,
    required this.onWeb,
  });

  final List<Map<String, dynamic>> unsupported;
  final VoidCallback onWeb;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline_rounded, size: 48),
            const SizedBox(height: 12),
            const Text(
              'هذا النموذج ليس ضمن Simple Formidable Mobile.',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            if (unsupported.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                unsupported
                    .map(
                      (field) =>
                          '${_text(field['label'])} (${_text(field['type'])})',
                    )
                    .join('، '),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'المدعوم حاليًا: Text، Number، Dropdown، Checkbox.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: onWeb,
              child: const Text('فتح النموذج الكامل'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.onWeb,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onWeb;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onRetry,
              child: const Text('إعادة المحاولة'),
            ),
            TextButton(
              onPressed: onWeb,
              child: const Text('فتح Web Runtime'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option {
  const _Option(this.value, this.label);

  final String value;
  final String label;
}

bool _isSupported(Map<String, dynamic> field) {
  const supported = {'text', 'number', 'select', 'checkbox'};
  return supported.contains(_typeOf(field));
}

String _typeOf(Map<String, dynamic> field) {
  final type = _text(field['type']).toLowerCase();
  if (type == 'dropdown') return 'select';
  return type;
}

List<Map<String, dynamic>> _fieldsOf(dynamic schema) {
  return _list(_map(schema)['fields']);
}

List<_Option> _optionsOf(dynamic value) {
  if (value is! List) return const [];

  final out = <_Option>[];
  for (final item in value) {
    if (item is Map) {
      final option = Map<String, dynamic>.from(item);
      final rawValue = _text(option['value']).isNotEmpty
          ? _text(option['value'])
          : _text(option['label']);
      if (rawValue.isEmpty) continue;
      final label = _text(option['label']).isNotEmpty
          ? _text(option['label'])
          : rawValue;
      out.add(_Option(rawValue, label));
    } else {
      final text = _text(item);
      if (text.isNotEmpty) out.add(_Option(text, text));
    }
  }
  return out;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

String _text(dynamic value) {
  if (value == null) return '';
  final text = '$value'.trim();
  if (text.isEmpty || text == 'null' || text == 'undefined') return '';
  return text;
}
