import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../app/app_controller.dart';
import '../../config/app_config.dart';

class FormidableLegacyWebScreen extends StatefulWidget {
  const FormidableLegacyWebScreen({
    super.key,
    required this.formKey,
    required this.title,
  });

  final String formKey;
  final String title;

  @override
  State<FormidableLegacyWebScreen> createState() => _FormidableLegacyWebScreenState();
}

class _FormidableLegacyWebScreenState extends State<FormidableLegacyWebScreen> {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller == null) _initialize();
  }

  Future<void> _initialize() async {
    final app = context.read<AppController>();
    final token = await app.sessions.readToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'جلسة الدخول غير متوفرة.');
      return;
    }

    final branding = app.bootstrap!.branding;
    final uri = AppConfig.mobileFormUri(widget.formKey, token);
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(branding.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() { _loading = true; _error = null; });
          },
          onPageFinished: (_) async {
            await _controller?.runJavaScript(_mobileFormScript(
              background: _hex(branding.background),
              surface: _hex(branding.surface),
              text: _hex(branding.text),
              muted: _hex(branding.muted),
              border: _hex(branding.border),
              primary: _hex(branding.primary),
              radius: branding.radius,
            ));
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() { _loading = false; _error = error.description; });
            }
          },
        ),
      )
      ..loadRequest(uri);

    setState(() => _controller = controller);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          if (_controller != null) WebViewWidget(controller: _controller!),
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 44),
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          if (_loading && _error == null)
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  static String _hex(Color color) {
    final value = color.toARGB32().toRadixString(16).padLeft(8, '0');
    return '#${value.substring(2)}';
  }

  static String _mobileFormScript({
    required String background,
    required String surface,
    required String text,
    required String muted,
    required String border,
    required String primary,
    required double radius,
  }) => '''
(function(){
  document.documentElement.setAttribute('dir','rtl');
  const selectors = ['header','footer','#wpadminbar','.site-header','.site-footer','.elementor-location-header','.elementor-location-footer','.ast-above-header-wrap','.main-header-bar-wrap','.breadcrumbs','.page-header','.entry-header'];
  selectors.forEach(s => document.querySelectorAll(s).forEach(e => e.style.display='none'));
  const style = document.createElement('style');
  style.innerHTML = `
    html,body{margin:0!important;padding:0!important;background:$background!important;color:$text!important;overflow-x:hidden!important}
    body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Arial,sans-serif!important}
    #page,.site,.site-content,.content-area,.site-main,.entry-content,.elementor,.elementor-section,.elementor-container{width:100%!important;max-width:none!important;margin:0!important;padding:0!important;background:$background!important}
    .frm_forms{padding:14px!important;margin:0!important}
    .frm_form_fields{background:$surface!important;border:1px solid $border!important;border-radius:${radius}px!important;padding:16px!important;box-shadow:none!important}
    .frm_form_field{margin-bottom:14px!important}
    .frm_primary_label{display:block!important;color:$text!important;font-size:14px!important;font-weight:800!important;margin-bottom:7px!important}
    .frm_description,.frm_error{font-size:12px!important;color:$muted!important}
    input[type=text],input[type=number],input[type=email],input[type=tel],input[type=date],input[type=time],input[type=password],select,textarea{width:100%!important;min-height:48px!important;box-sizing:border-box!important;border:1px solid $border!important;border-radius:${radius - 4}px!important;background:$surface!important;color:$text!important;padding:10px 12px!important;font-size:16px!important;box-shadow:none!important}
    textarea{min-height:110px!important}
    input:focus,select:focus,textarea:focus{outline:none!important;border-color:$primary!important;box-shadow:0 0 0 3px ${primary}22!important}
    .frm_button_submit,button[type=submit],input[type=submit]{width:100%!important;min-height:50px!important;border:0!important;border-radius:${radius - 3}px!important;background:$primary!important;color:#fff!important;font-size:16px!important;font-weight:900!important;padding:12px 18px!important}
    .frm_add_form_row,.frm_remove_form_row{min-height:42px!important;border-radius:12px!important}
    img{max-width:100%!important;height:auto!important}
  `;
  document.head.appendChild(style);
  const form = document.querySelector('.frm_forms, form');
  if(form){ form.scrollIntoView({block:'start'}); }
})();
''';
}
