import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';
import '../../core/ui/neizami_ui.dart';
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
  State<FormidableNativeScreen> createState() => _FormidableNativeScreenState();
}

class _FormidableNativeScreenState extends State<FormidableNativeScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Map<String, dynamic>? _schema;

  final Map<String, TextEditingController> _controllers = <String, TextEditingController>{};
  final Map<String, dynamic> _values = <String, dynamic>{};
  final Map<String, FocusNode> _focusNodes = <String, FocusNode>{};

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
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await context.read<AppController>().api.get(
        '/forms/${widget.formKey}',
      );
      if (!mounted) return;

      for (final controller in _controllers.values) {
        controller.dispose();
      }
      for (final node in _focusNodes.values) {
        node.dispose();
      }
      _controllers.clear();
      _focusNodes.clear();
      _values.clear();

      for (final field in _supportedFields(data['fields'])) {
        final key = _text(field['key']);
        if (key.isEmpty) continue;
        final type = _normalizeType(field['type']);
        final defaultValue = field['default'];

        if (type == 'checkbox') {
          _values[key] = defaultValue is List
              ? List<String>.from(defaultValue.map((e) => '$e'))
              : <String>[];
        } else if (type == 'select') {
          _values[key] = _text(defaultValue);
        } else {
          _controllers[key] = TextEditingController(text: _text(defaultValue));
          _focusNodes[key] = FocusNode();
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

  List<Map<String, dynamic>> _supportedFields(dynamic raw) {
    return _list(raw)
        .where((field) => const {'text', 'number', 'select', 'dropdown', 'checkbox'}
            .contains(_normalizeType(field['type'])))
        .toList();
  }

  Map<String, dynamic> _currentValues() {
    final out = <String, dynamic>{..._values};
    for (final entry in _controllers.entries) {
      out[entry.key] = entry.value.text.trim();
    }
    return out;
  }

  Future<void> _submit() async {
    final schema = _schema;
    if (schema == null || _saving) return;

    FocusScope.of(context).unfocus();
    final fields = _supportedFields(schema['fields']);
    final values = _currentValues();
    final payload = <String, dynamic>{};
    final missing = <String>[];

    for (final field in fields) {
      final key = _text(field['key']);
      if (key.isEmpty) continue;
      final value = values[key];
      final empty = value == null ||
          (value is String && value.trim().isEmpty) ||
          (value is List && value.isEmpty);

      if (field['required'] == true && empty) {
        missing.add(_text(field['label']).isEmpty ? key : _text(field['label']));
      }
      payload[key] = value;
    }

    if (missing.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('أكمل الحقول المطلوبة: ${missing.join('، ')}')),
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
            entryId == null ? 'تم الحفظ بنجاح.' : 'تم الحفظ بنجاح #$entryId',
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
    final form = _map(schema?['form']);
    final title = _text(form['name']).isNotEmpty ? _text(form['name']) : widget.title;
    final fields = _supportedFields(schema?['fields']);
    final nativeReady = schema?['native_ready'] != false;
    final mode = _text(schema?['mode']);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: _loading
          ? const _FormSkeleton()
          : _error != null
              ? _FormError(
                  message: _error!,
                  onRetry: _load,
                  onWeb: _openWebFallback,
                )
              : mode == 'web' || !nativeReady
                  ? _UnsupportedForm(
                      schema: schema ?? const <String, dynamic>{},
                      onWeb: _openWebFallback,
                    )
                  : fields.isEmpty
                      ? const NzEmptyState(
                          title: 'لا توجد حقول مفعلة للموبايل',
                          message: 'اختر Text / Number / Dropdown / Checkbox من إعدادات Mobile Bridge.',
                        )
                      : _buildForm(schema ?? const <String, dynamic>{}, fields),
      bottomNavigationBar: !_loading &&
              _error == null &&
              mode != 'web' &&
              nativeReady &&
              fields.isNotEmpty
          ? SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 9, 14, 12),
                decoration: BoxDecoration(
                  color: context.nz.surface,
                  border: Border(top: BorderSide(color: context.nz.border)),
                ),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _submit,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    _text(schema?['submit_label']).isNotEmpty
                        ? _text(schema?['submit_label'])
                        : 'حفظ',
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildForm(
    Map<String, dynamic> schema,
    List<Map<String, dynamic>> fields,
  ) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        if (_text(_map(schema['form'])['description']).isNotEmpty) ...[
          NzSurface(
            soft: true,
            padding: const EdgeInsets.all(13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: context.nz.primary, size: 20),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    _text(_map(schema['form'])['description']),
                    style: TextStyle(color: context.nz.muted, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        NzSurface(
          padding: const EdgeInsets.fromLTRB(14, 15, 14, 15),
          child: Column(
            children: [
              for (var index = 0; index < fields.length; index++) ...[
                _NativeField(
                  field: fields[index],
                  controller: _controllers[_text(fields[index]['key'])],
                  focusNode: _focusNodes[_text(fields[index]['key'])],
                  value: _values[_text(fields[index]['key'])],
                  isLastTextField: _isLastTextField(fields, index),
                  onChanged: (value) {
                    setState(() => _values[_text(fields[index]['key'])] = value);
                  },
                  onNext: () => _focusNext(fields, index),
                ),
                if (index != fields.length - 1) ...[
                  const SizedBox(height: 15),
                  const Divider(),
                  const SizedBox(height: 15),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'سيتم الحفظ مباشرة في Formidable وتشغيل الـHooks الحالية.',
          textAlign: TextAlign.center,
          style: TextStyle(color: context.nz.muted, fontSize: 11.5),
        ),
      ],
    );
  }

  bool _isLastTextField(List<Map<String, dynamic>> fields, int index) {
    for (var i = index + 1; i < fields.length; i++) {
      final type = _normalizeType(fields[i]['type']);
      if (type == 'text' || type == 'number') return false;
    }
    return true;
  }

  void _focusNext(List<Map<String, dynamic>> fields, int index) {
    for (var i = index + 1; i < fields.length; i++) {
      final key = _text(fields[i]['key']);
      final node = _focusNodes[key];
      if (node != null) {
        node.requestFocus();
        return;
      }
    }
    FocusScope.of(context).unfocus();
  }
}

class _NativeField extends StatelessWidget {
  const _NativeField({
    required this.field,
    required this.controller,
    required this.focusNode,
    required this.value,
    required this.isLastTextField,
    required this.onChanged,
    required this.onNext,
  });

  final Map<String, dynamic> field;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final dynamic value;
  final bool isLastTextField;
  final ValueChanged<dynamic> onChanged;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final type = _normalizeType(field['type']);
    final label = _text(field['label']);
    final description = _text(field['description']);
    final required = field['required'] == true;
    final readonly = field['readonly'] == true;
    final options = _list(field['options']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 2, bottom: 7),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: context.nz.text,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
                children: [
                  TextSpan(text: label),
                  if (required)
                    TextSpan(
                      text: '  *',
                      style: TextStyle(color: context.nz.danger),
                    ),
                ],
              ),
            ),
          ),
        _input(context, type, options),
        if (description.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(color: context.nz.muted, fontSize: 11.5, height: 1.35),
          ),
        ],
      ],
    );
  }

  Widget _input(
    BuildContext context,
    String type,
    List<Map<String, dynamic>> options,
  ) {
    if (type == 'select') {
      final current = _text(value);
      return DropdownButtonFormField<String>(
        value: options.any((o) => _optionValue(o) == current) ? current : null,
        isExpanded: true,
        decoration: const InputDecoration(hintText: 'اختر...'),
        items: options
            .map(
              (option) => DropdownMenuItem<String>(
                value: _optionValue(option),
                child: Text(_optionLabel(option)),
              ),
            )
            .toList(),
        onChanged: readonly ? null : (next) => onChanged(next ?? ''),
      );
    }

    if (type == 'checkbox') {
      final selected = value is List
          ? value.map((e) => '$e').toSet()
          : <String>{};
      if (options.isEmpty) {
        return Text('لا توجد خيارات.', style: TextStyle(color: context.nz.muted));
      }
      return Wrap(
        spacing: 7,
        runSpacing: 7,
        children: options.map((option) {
          final optionValue = _optionValue(option);
          final checked = selected.contains(optionValue);
          return FilterChip(
            selected: checked,
            showCheckmark: true,
            label: Text(_optionLabel(option)),
            onSelected: readonly
                ? null
                : (enabled) {
              final next = <String>{...selected};
              if (enabled) {
                next.add(optionValue);
              } else {
                next.remove(optionValue);
              }
              onChanged(next.toList());
            },
          );
        }).toList(),
      );
    }

    final numeric = type == 'number';
    return TextField(
      controller: controller,
      focusNode: focusNode,
      readOnly: readonly,
      keyboardType: numeric
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      inputFormatters: numeric
          ? <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]')),
            ]
          : null,
      textInputAction: isLastTextField ? TextInputAction.done : TextInputAction.next,
      onSubmitted: (_) => onNext(),
      decoration: InputDecoration(
        hintText: _text(field['placeholder']).isNotEmpty
            ? _text(field['placeholder'])
            : null,
      ),
    );
  }
}

class _FormSkeleton extends StatelessWidget {
  const _FormSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(14),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const NzSkeletonCard(compact: true),
    );
  }
}

class _FormError extends StatelessWidget {
  const _FormError({
    required this.message,
    required this.onRetry,
    required this.onWeb,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onWeb;

  @override
  Widget build(BuildContext context) {
    return NzEmptyState(
      icon: Icons.error_outline_rounded,
      title: 'تعذر تحميل النموذج',
      message: message,
      action: Column(
        children: [
          FilledButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
          const SizedBox(height: 8),
          TextButton(onPressed: onWeb, child: const Text('فتح النموذج الكامل')),
        ],
      ),
    );
  }
}

class _UnsupportedForm extends StatelessWidget {
  const _UnsupportedForm({required this.schema, required this.onWeb});

  final Map<String, dynamic> schema;
  final VoidCallback onWeb;

  @override
  Widget build(BuildContext context) {
    final unsupported = _list(schema['unsupported_fields']);
    return NzEmptyState(
      icon: Icons.web_asset_rounded,
      title: 'هذا النموذج ليس Simple Mobile Form',
      message: unsupported.isEmpty
          ? 'فعّل فقط Text / Number / Dropdown / Checkbox لهذا النموذج.'
          : 'الحقول غير المدعومة: ${unsupported.map((f) => _text(f['label']).isEmpty ? _text(f['type']) : _text(f['label'])).join('، ')}',
      action: FilledButton.tonal(
        onPressed: onWeb,
        child: const Text('فتح النموذج الكامل'),
      ),
    );
  }
}

String _normalizeType(dynamic raw) {
  final type = _text(raw).toLowerCase();
  if (type == 'dropdown') return 'select';
  return type;
}

String _optionValue(Map<String, dynamic> option) {
  return _firstUseful([option['value'], option['key'], option['id'], option['label']]);
}

String _optionLabel(Map<String, dynamic> option) {
  return _firstUseful([option['label'], option['name'], option['title'], option['value']]);
}

String _firstUseful(List<dynamic> values) {
  for (final value in values) {
    final text = _text(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _list(dynamic value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

String _text(dynamic value) {
  if (value == null) return '';
  final text = '$value'.trim();
  if (text.isEmpty || text.toLowerCase() == 'null' || text.toLowerCase() == 'undefined') {
    return '';
  }
  return text;
}
