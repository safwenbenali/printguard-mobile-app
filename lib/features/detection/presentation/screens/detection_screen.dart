import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_router.dart';
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
              onPressed: () {
                ref.read(detectionProvider.notifier).reset();
              },
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
                  key: ValueKey(state.result!.timestamp),
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
                  const SizedBox(width: 8),
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
              const SizedBox(width: 8),
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

// ── FIXED: Stateful _ResultView ──────────────────────────────────

class _ResultView extends ConsumerStatefulWidget {
  final DetectionRecord record;
  final VoidCallback onSave;
  final VoidCallback onNew;

  const _ResultView({
    super.key,
    required this.record,
    required this.onSave,
    required this.onNew,
  });

  @override
  ConsumerState<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends ConsumerState<_ResultView> {
  Map<String, String>? _recommendation;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchRecommendation();
  }

  Future<void> _fetchRecommendation() async {
    if (widget.record.boxes.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final topBox = widget.record.boxes
          .reduce((a, b) => a.confidence > b.confidence ? a : b);

      final apiService = ref.read(apiServiceProvider);
      final result = await apiService.getRecommendation(
        className: topBox.className,
        confidence: topBox.confidence,
        imageBase64: widget.record.imageUrl,
      );

      if (mounted) {
        setState(() {
          _recommendation = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recommendation = {
            'rootCause': 'Could not fetch recommendation',
            'suggestedFix': 'Please try again later',
            'urgencyLevel': 'NOTIFY',
          };
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Annotated image ──
        if (widget.record.imageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: widget.record.imageUrl!.startsWith('data:')
                ? Image.memory(
                    _base64ToBytes(widget.record.imageUrl!),
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
                  )
                : Image.network(
                    widget.record.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const _ImagePlaceholder(),
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
            color: AlertLevel.color(widget.record.alertLevel).withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AlertLevel.color(widget.record.alertLevel).withOpacity(0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                AlertLevel.icon(widget.record.alertLevel),
                color: AlertLevel.color(widget.record.alertLevel),
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.record.alertLevel == AlertLevel.stop
                          ? 'STOP — Critical Defect'
                          : widget.record.alertLevel == AlertLevel.notify
                              ? 'WARNING — Defect Detected'
                              : 'OK — Minor or No Defect',
                      style: TextStyle(
                        color: AlertLevel.color(widget.record.alertLevel),
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      widget.record.alertLevel == AlertLevel.stop
                          ? 'Consider stopping the print'
                          : widget.record.alertLevel == AlertLevel.notify
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

        // ── Proactive Recommendation Card ──
        if (widget.record.boxes.isNotEmpty) ...[
          if (_isLoading)
            _buildLoadingCard()
          else if (_recommendation != null)
            _buildRecommendationCard(_recommendation!),
        ],

        // ── Detection list ──
        if (widget.record.boxes.isNotEmpty) ...[
          const SectionHeader(title: 'DETECTIONS'),
          const SizedBox(height: 10),
          ...widget.record.boxes.map(
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
                      'Confidence: ${widget.record.confidencePercent}',
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
                .format(widget.record.timestamp),
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
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(
                  context,
                  AppRoutes.assistant,
                  arguments: widget.record,
                ),
                icon: const Icon(Icons.smart_toy_outlined, size: 18),
                label: const Text(' Ask AI '),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(0, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: widget.onNew,
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
                onPressed: widget.onSave,
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text('Save'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 50),
                  backgroundColor: AppColors.accentGreen,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 14),
          const Text(
            'AI is analyzing this defect…',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard(Map<String, String> rec) {
    final urgency = rec['urgencyLevel']?.toUpperCase() ?? 'NOTIFY';
    final Color urgencyColor = urgency == 'STOP'
        ? AppColors.stop
        : urgency == 'NOTIFY'
            ? AppColors.notify
            : AppColors.ok;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surface,
            AppColors.surface.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: urgencyColor.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                urgency == 'STOP'
                    ? Icons.error_outline_rounded
                    : urgency == 'NOTIFY'
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline_rounded,
                color: urgencyColor,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                urgency == 'STOP'
                    ? 'AI RECOMMENDATION — STOP'
                    : urgency == 'NOTIFY'
                        ? 'AI RECOMMENDATION — NOTIFY'
                        : 'AI RECOMMENDATION — CONTINUE',
                style: TextStyle(
                  color: urgencyColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🔍 ', style: TextStyle(fontSize: 14)),
              Expanded(
                child: Text(
                  rec['rootCause'] ?? 'No root cause available',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🔧 ', style: TextStyle(fontSize: 14)),
              Expanded(
                child: Text(
                  rec['suggestedFix'] ?? 'No fix available',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(
                Icons.smart_toy_outlined,
                color: AppColors.textHint,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'Tap "Ask AI" for more details',
                style: TextStyle(
                  color: AppColors.textHint,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Uint8List _base64ToBytes(String dataUri) {
    final base64Str = dataUri.split(',').last;
    return base64Decode(base64Str);
  }
}

// ── Detection Item ──────────────────────────────────────────────────

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