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

  Future<void> _capture() async {
    final image = await _picker.pickImage(source: ImageSource.camera, imageQuality: 88);
    if (image != null && mounted) setState(() => _images.add(image));
  }

  Future<void> _gallery() async {
    final images = await _picker.pickMultiImage(imageQuality: 88);
    if (images.isNotEmpty && mounted) setState(() => _images.addAll(images));
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
              onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('سيتم ربط الرفع بالسجل المختار عند تفعيل Endpoint المعرض.')),
              ),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text('رفع ${_images.length} صورة'),
            ),
          ],
        ],
      ),
    );
  }
}
