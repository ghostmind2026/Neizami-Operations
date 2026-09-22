import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../app/app_controller.dart';

class DeviceCameraScreen extends StatefulWidget {
  const DeviceCameraScreen({super.key});

  @override
  State<DeviceCameraScreen> createState() => _DeviceCameraScreenState();
}

class _DeviceCameraScreenState extends State<DeviceCameraScreen> {
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _images = [];
  final TextEditingController _noteController = TextEditingController();
  bool _cameraOpened = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openCameraOnce());
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _openCameraOnce() async {
    if (_cameraOpened || !mounted) return;
    _cameraOpened = true;
    await _capture();
  }

  Future<void> _capture() async {
    final image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 88);
    if (image != null && mounted) {
      setState(() => _images.add(image));
      await _showNoteSheet();
    }
  }

  Future<void> _showNoteSheet() async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          18,
          18,
          18 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'ملاحظة على الجهاز',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _noteController,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'اكتب ملاحظة اختيارية...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: const Text('حفظ الملاحظة'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _gallery() async {
    final images = await _picker.pickMultiImage(imageQuality: 88);
    if (images.isNotEmpty && mounted) setState(() => _images.addAll(images));
  }

  Future<void> _upload() async {
    if (_images.isEmpty || _uploading) return;
    setState(() => _uploading = true);
    try {
      final api = context.read<AppController>().api;
      final note = _noteController.text.trim();
      for (final image in List<XFile>.from(_images)) {
        await api.uploadFile(
          '/device-photos',
          filePath: image.path,
          fields: {'note': note},
        );
      }
      if (!mounted) return;
      setState(() {
        _images.clear();
        _noteController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم رفع الصور بنجاح.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر رفع الصور: $error')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branding = context.read<AppController>().bootstrap!.branding;
    return Scaffold(
      backgroundColor: branding.background,
      appBar: AppBar(title: const Text('تصوير جهاز')),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _capture,
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('فتح الكاميرا'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _gallery,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('اختيار صور'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _noteController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'ملاحظة',
              hintText: 'ملاحظة اختيارية على الجهاز...',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          if (_images.isEmpty)
            Container(
              height: 260,
              decoration: BoxDecoration(
                color: branding.surface,
                borderRadius: BorderRadius.circular(branding.radius),
                border: Border.all(color: branding.border),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 52),
                  SizedBox(height: 12),
                  Text('لم تتم إضافة صور بعد.'),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _images.length,
              itemBuilder: (_, index) => Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.file(File(_images[index].path), fit: BoxFit.cover),
                  ),
                  PositionedDirectional(
                    top: 6,
                    end: 6,
                    child: IconButton.filled(
                      onPressed: () => setState(() => _images.removeAt(index)),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              ),
            ),
          if (_images.isNotEmpty) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _uploading ? null : _upload,
              icon: _uploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(_uploading ? 'جاري الرفع...' : 'رفع ${_images.length} صورة'),
            ),
          ],
        ],
      ),
    );
  }
}
