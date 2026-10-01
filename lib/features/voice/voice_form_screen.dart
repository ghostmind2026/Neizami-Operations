import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../app/app_controller.dart';
import '../formidable/formidable_native_screen.dart';

class VoiceFormScreen extends StatefulWidget {
  const VoiceFormScreen({super.key});
  @override
  State<VoiceFormScreen> createState() => _VoiceFormScreenState();
}

class _VoiceFormScreenState extends State<VoiceFormScreen> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _loading = true, _listening = false;
  String? _error;
  String _words = '';
  List<Map<String, dynamic>> _forms = const [];

  @override
  void initState() { super.initState(); _prepare(); }

  Future<void> _prepare() async {
    try {
      final data = await context.read<AppController>().voiceCommands();
      final raw = data['forms'] is List ? data['forms'] as List : const [];
      _forms = raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      final available = await _speech.initialize(
        onStatus: (s) { if (mounted) setState(() => _listening = s == 'listening'); },
        onError: (e) { if (mounted) setState(() { _listening = false; _error = e.errorMsg; }); },
      );
      if (!available) throw Exception('التعرف الصوتي غير متاح على هذا الجهاز.');
      if (mounted) setState(() => _loading = false);
      await _listen();
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = '$e'; });
    }
  }

  Future<void> _listen() async {
    if (_loading || _speech.isListening) return;
    final locales = await _speech.locales();
    String? localeId;
    for (final l in locales) {
      final id = l.localeId.toLowerCase();
      if (id == 'ar_jo' || id == 'ar-jo') { localeId = l.localeId; break; }
    }
    if (localeId == null) {
      for (final l in locales) {
        if (l.localeId.toLowerCase().startsWith('ar')) { localeId = l.localeId; break; }
      }
    }
    setState(() { _words = ''; _error = null; });
    await _speech.listen(
      localeId: localeId,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: false,
        listenMode: stt.ListenMode.dictation,
      ),
      onResult: (r) {
        if (!mounted) return;
        setState(() => _words = r.recognizedWords);
        if (r.finalResult) _resolve();
      },
    );
  }

  void _resolve() {
    final spoken = _normalize(_words);
    if (spoken.isEmpty) return;
    Map<String, dynamic>? matched;
    var best = 0;
    for (final form in _forms) {
      for (final trigger in _strings(form['triggers'])) {
        final token = _normalize(trigger);
        if (token.isNotEmpty && spoken.contains(token) && token.length > best) {
          matched = form; best = token.length;
        }
      }
    }
    if (matched == null) {
      setState(() => _error = 'لم أتعرف على النموذج. راجع كلمات التفعيل في Mobile Bridge.');
      return;
    }

    final values = <String, dynamic>{};
    final rawFields = matched['fields'] is List ? matched['fields'] as List : const [];
    final hits = <_Hit>[];
    for (final raw in rawFields.whereType<Map>()) {
      final field = Map<String, dynamic>.from(raw);
      final key = '${field['field_key'] ?? ''}'.trim();
      if (key.isEmpty) continue;
      for (final trigger in _strings(field['triggers'])) {
        final token = _normalize(trigger);
        final index = spoken.indexOf(token);
        if (token.isNotEmpty && index >= 0) hits.add(_Hit(index, token.length, key));
      }
    }
    hits.sort((a, b) => a.index.compareTo(b.index));
    for (var i = 0; i < hits.length; i++) {
      final start = hits[i].index + hits[i].length;
      final end = i + 1 < hits.length ? hits[i + 1].index : spoken.length;
      if (end > start) {
        final value = spoken.substring(start, end).trim();
        if (value.isNotEmpty) values[hits[i].key] = value;
      }
    }

    final formKey = '${matched['form_key'] ?? ''}'.trim();
    if (formKey.isEmpty) return;
    final label = '${matched['label'] ?? formKey}'.trim();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FormidableNativeScreen(
          formKey: formKey,
          title: label,
          initialValues: values,
        ),
      ),
    );
  }

  List<String> _strings(dynamic v) {
    if (v is List) return v.map((e) => '$e'.trim()).where((e) => e.isNotEmpty).toList();
    return '$v'.split(RegExp(r'[,،\n]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  String _normalize(String v) => v.toLowerCase()
      .replaceAll(RegExp('[أإآٱ]'), 'ا').replaceAll('ى', 'ي').replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و').replaceAll('ئ', 'ي').replaceAll(RegExp(r'[ًٌٍَُِّْـ]'), '')
      .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06ff+ ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ').trim();

  @override
  Widget build(BuildContext context) {
    final b = context.read<AppController>().bootstrap!.branding;
    return Scaffold(
      backgroundColor: b.background,
      appBar: AppBar(title: const Text('تعبئة بالصوت')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          const Spacer(),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: _listening ? 112 : 94, height: _listening ? 112 : 94,
            decoration: BoxDecoration(shape: BoxShape.circle, color: b.primary.withValues(alpha: _listening ? .16 : .09)),
            child: Icon(Icons.mic_rounded, size: 48, color: b.primary),
          ),
          const SizedBox(height: 22),
          Text(_loading ? 'جاري تجهيز الأوامر...' : (_listening ? 'أتحدث الآن...' : 'اضغط الميكروفون للتحدث'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 12),
          Text(_words.isEmpty ? 'اذكر كلمة النموذج ثم أسماء الحقول وقيمها.' : _words,
              textAlign: TextAlign.center, style: TextStyle(color: b.muted, fontSize: 15, height: 1.5)),
          if (_error != null) ...[const SizedBox(height: 14), Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: b.danger))],
          const Spacer(),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            onPressed: _loading ? null : (_listening ? _speech.stop : _listen),
            icon: Icon(_listening ? Icons.stop_rounded : Icons.mic_rounded),
            label: Text(_listening ? 'إنهاء التسجيل' : 'تسجيل صوتي'),
          )),
        ]),
      ),
    );
  }
}

class _Hit {
  const _Hit(this.index, this.length, this.key);
  final int index, length;
  final String key;
}
