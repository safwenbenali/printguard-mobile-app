import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/detection_model.dart';
import '../../../../core/services/providers.dart';
import '../../../../core/utils/widgets.dart';

class DetectionScreen extends ConsumerStatefulWidget {
  const DetectionScreen({super.key});

  @override
  ConsumerState<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends ConsumerState<DetectionScreen> {
  final _picker = ImagePicker();

  Future<void> _pickAndDetect(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1280,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      await ref.read(detectionProvider.notifier).detect(bytes);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _saveResult() async {
    final id = await ref.read(detectionProvider.notifier).saveCurrentResult();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          id != null
              ? '✅ Detection saved to history'
              : '❌ Failed to save',
        ),
        backgroundColor:
            id != null ? AppColors.accentGreen : AppColors.accent,
      ),
    );
  }

  void _showSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select image source',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _SourceButton(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndDetect(ImageSource.camera);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _SourceButton(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndDetect(ImageSource.gallery);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(detectionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detection'),
        actions: [
          if (state.result != null)
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => ref.read(detectionProvider.notifier).reset(),
              tooltip: 'Reset',
            ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: state.isLoading,
        message: 'Analyzing image…',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Capture button ──
              if (state.result == null && !state.isLoading) ...[
                _CapturePrompt(onTap: _showSourcePicker),
                const SizedBox(height: 32),
                _HowItWorks(),
              ],

              // ── Error state ──
              if (state.error != null && !state.isLoading)
                _ErrorCard(
                  error: state.error!,
                  onRetry: _showSourcePicker,
                ),

              // ── Results ──
              if (state.result != null) ...[
                _ResultView(
                  record: state.result!,
                  onSave: _saveResult,
                  onNew: () {
                    ref.read(detectionProvider.notifier).reset();
                    _showSourcePicker();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sub-widgets ─────────────────────────────────

class _CapturePrompt extends StatelessWidget {
  final VoidCallback onTap;
  const _CapturePrompt({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(40),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.4),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.2),
                    AppColors.primaryDark.withOpacity(0.2),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.center_focus_strong_rounded,
                color: AppColors.primary,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Capture & Detect',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Take a photo or pick from gallery\nto analyze for 3D print defects',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_a_photo_rounded,
                      color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Select Image',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: AppColors.primary, size: 16),
              SizedBox(width: 8),
              Text(
                'Detectable defects',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: AppStrings.defectClasses
                .map((c) => DefectChip(className: c))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorCard({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return InfoCard(
      borderColor: AppColors.accent.withOpacity(0.4),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.accent, size: 36),
          const SizedBox(height: 12),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(140, 44),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final DetectionRecord record;
  final VoidCallback onSave;
  final VoidCallback onNew;

  const _ResultView({
    required this.record,
    required this.onSave,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Annotated image ──
        if (record.imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: record.imageUrl!.startsWith('data:')
                ? Image.memory(
                    _base64ToBytes(record.imageUrl!),
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const _ImagePlaceholder(),
                  )
                : Image.network(
                    record.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const _ImagePlaceholder(),
                  ),
          )
        else
          const _ImagePlaceholder(),

        const SizedBox(height: 20),

        // ── Alert level banner ──
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color:
                AlertLevel.color(record.alertLevel).withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  AlertLevel.color(record.alertLevel).withOpacity(0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                AlertLevel.icon(record.alertLevel),
                color: AlertLevel.color(record.alertLevel),
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.alertLevel == AlertLevel.stop
                          ? 'STOP — Critical Defect'
                          : record.alertLevel == AlertLevel.notify
                              ? 'WARNING — Defect Detected'
                              : 'OK — Minor or No Defect',
                      style: TextStyle(
                        color: AlertLevel.color(record.alertLevel),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      record.alertLevel == AlertLevel.stop
                          ? 'Consider stopping the print'
                          : record.alertLevel == AlertLevel.notify
                              ? 'Monitor closely'
                              : 'Print appears healthy',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Detection list ──
        if (record.boxes.isNotEmpty) ...[
          const SectionHeader(title: 'DETECTIONS'),
          const SizedBox(height: 10),
          ...record.boxes.map(
            (box) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _DetectionItem(box: box),
            ),
          ),
        ] else ...[
          InfoCard(
            child: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppColors.ok, size: 20),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'No defects detected',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Confidence: ${record.confidencePercent}',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 8),

        // ── Timestamp ──
        Center(
          child: Text(
            DateFormat('MMM d, yyyy — HH:mm:ss')
                .format(record.timestamp),
            style: const TextStyle(
              color: AppColors.textHint,
              fontSize: 12,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── Action buttons ──
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onNew,
                icon: const Icon(Icons.add_a_photo_rounded, size: 18),
                label: const Text('New Detection'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textPrimary,
                  side: const BorderSide(color: AppColors.divider),
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onSave,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 50),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Uint8List _base64ToBytes(String dataUri) {
    final base64Str = dataUri.split(',').last;
    return Uri.parse('data:application/octet-stream;base64,$base64Str')
        .data!
        .contentAsBytes();
  }
}

class _DetectionItem extends StatelessWidget {
  final BoundingBox box;
  const _DetectionItem({required this.box});

  @override
  Widget build(BuildContext context) {
    final alertLevel = AlertLevel.fromConfidence(box.confidence);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: DefectInfo.color(box.className).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              DefectInfo.icon(box.className),
              color: DefectInfo.color(box.className),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  box.className.replaceAll('_', ' '),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                ConfidenceBar(value: box.confidence),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${(box.confidence * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              AlertBadge(level: alertLevel, small: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_rounded,
              color: AppColors.textHint, size: 40),
          SizedBox(height: 8),
          Text(
            'No annotated image',
            style: TextStyle(color: AppColors.textHint, fontSize: 13),
          ),
        ],
      ),
    );
  }
}
