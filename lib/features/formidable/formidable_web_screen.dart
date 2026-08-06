import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../app/app_controller.dart';
import '../../config/app_config.dart';

class FormidableWebScreen extends StatefulWidget {
  const FormidableWebScreen({
    super.key,
    required this.formKey,
    required this.title,
  });

  final String formKey;
  final String title;

  @override
  State<FormidableWebScreen> createState() => _FormidableWebScreenState();
}

class _FormidableWebScreenState extends State<FormidableWebScreen> {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;
    _initialize();
  }

  Future<void> _initialize() async {
    final app = context.read<AppController>();
    final token = await app.sessions.readToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      setState(() => _error = 'جلسة الدخول غير متوفرة.');
      return;
    }

    final uri = AppConfig.mobileFormUri(widget.formKey, token);
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(app.bootstrap!.branding.background)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true && mounted) {
              setState(() {
                _loading = false;
                _error = error.description;
              });
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
                child: Text(_error!, textAlign: TextAlign.center),
              ),
            ),
          if (_loading && _error == null)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
