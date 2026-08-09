import 'package:flutter/material.dart';

import 'formidable_legacy_web_screen.dart';
import 'formidable_native_screen.dart';

/// Backward-compatible launcher used by the existing Home actions.
/// Native schema is now the default. The old WebView runtime remains available
/// only as a fallback for complex Formidable fields.
class FormidableWebScreen extends StatelessWidget {
  const FormidableWebScreen({
    super.key,
    required this.formKey,
    required this.title,
    this.forceWeb = false,
  });

  final String formKey;
  final String title;
  final bool forceWeb;

  @override
  Widget build(BuildContext context) {
    if (forceWeb) {
      return FormidableLegacyWebScreen(formKey: formKey, title: title);
    }
    return FormidableNativeScreen(formKey: formKey, title: title);
  }
}
