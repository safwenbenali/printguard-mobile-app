import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/detection_model.dart';
import '../../../../core/services/providers.dart';
import '../../../../core/utils/widgets.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends ConsumerState<NotificationsScreen> {
  String? _filterClass;

  Future<void> _markAllRead() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    await ref.read(firestoreServiceProvider).markAllAsRead(uid);
    ref.invalidate(unreadCountProvider);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All alerts marked as read')),
      );
    }
  }

  Future<void> _markRead(String docId) async {
    await ref.read(firestoreServiceProvider).markAsRead(docId);
    ref.invalidate(unreadCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final stream = ref.watch(detectionsStreamProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          // Filter chip
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: PopupMenuButton<String?>(
              icon: const Icon(Icons.filter_list_rounded),
              color: AppColors.surface,
              onSelected: (val) => setState(() => _filterClass = val),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: null,
                  child: Text('All classes',
                      style: TextStyle(color: AppColors.textPrimary)),
                ),
                ...AppStrings.defectClasses.map(
                  (c) => PopupMenuItem(
                    value: c,
                    child: Text(
                      c.replaceAll('_', ' '),
                      style:
                          const TextStyle(color: AppColors.textPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Mark all read
          unread.when(
            data: (n) => n > 0
                ? IconButton(
                    icon: const Icon(Icons.done_all_rounded),
                    onPressed: _markAllRead,
                    tooltip: 'Mark all as read',
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: stream.when(
        data: (all) {
          final filtered = _filterClass == null
              ? all
              : all
                  .where((d) => d.className == _filterClass)
                  .toList();

          if (filtered.isEmpty) {
            return EmptyState(
              icon: Icons.notifications_off_outlined,
              title: _filterClass != null
                  ? 'No ${_filterClass!.replaceAll("_", " ")} alerts'
                  : 'No alerts yet',
              subtitle: 'Detections will appear here when saved.',
              onAction: _filterClass != null
                  ? () => setState(() => _filterClass = null)
                  : null,
              actionLabel: 'Clear filter',
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface,
            onRefresh: () async {
              ref.invalidate(detectionsStreamProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _AlertCard(
                record: filtered[i],
                onTap: () {
                  if (!filtered[i].isRead && filtered[i].id != null) {
                    _markRead(filtered[i].id!);
                  }
                  _showDetail(context, filtered[i]);
                },
              ),
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Failed to load alerts',
          subtitle: e.toString(),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, DetectionRecord record) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _DetailSheet(record: record),
    );
  }
}

// ── Alert card ──────────────────────────────────

class _AlertCard extends StatelessWidget {
  final DetectionRecord record;
  final VoidCallback onTap;

  const _AlertCard({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = AlertLevel.color(record.alertLevel);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: record.isRead
                ? AppColors.divider
                : color.withOpacity(0.4),
            width: record.isRead ? 1 : 1.5,
          ),
        ),
        child: Row(
          children: [
            // Defect icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: DefectInfo.color(record.className).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                DefectInfo.icon(record.className),
                color: DefectInfo.color(record.className),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.className.replaceAll('_', ' '),
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: record.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      AlertBadge(level: record.alertLevel, small: true),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        record.confidencePercent,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Text(
                        '  •  ',
                        style: TextStyle(
                            color: AppColors.textHint, fontSize: 12),
                      ),
                      Text(
                        timeago.format(record.timestamp),
                        style: const TextStyle(
                          color: AppColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Unread dot
            if (!record.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(left: 8),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Detail bottom sheet ─────────────────────────

class _DetailSheet extends StatelessWidget {
  final DetectionRecord record;
  const _DetailSheet({required this.record});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                DefectChip(className: record.className),
                const SizedBox(width: 8),
                AlertBadge(level: record.alertLevel),
              ],
            ),
            const SizedBox(height: 16),

            Text(
              record.className
                  .replaceAll('_', ' ')
                  .split(' ')
                  .map((w) => w[0].toUpperCase() + w.substring(1))
                  .join(' '),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              DefectInfo.description(record.className),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),

            _DetailRow(
              icon: Icons.percent_rounded,
              label: 'Confidence',
              value: record.confidencePercent,
            ),
            _DetailRow(
              icon: Icons.access_time_rounded,
              label: 'Detected at',
              value: DateFormat('MMM d, yyyy HH:mm:ss')
                  .format(record.timestamp),
            ),
            if (record.printerName != null)
              _DetailRow(
                icon: Icons.print_rounded,
                label: 'Printer',
                value: record.printerName!,
              ),
            _DetailRow(
              icon: Icons.mark_email_read_outlined,
              label: 'Status',
              value: record.isRead ? 'Read' : 'Unread',
            ),
            _DetailRow(
              icon: Icons.tag_rounded,
              label: 'Detection ID',
              value: record.id ?? 'Not saved',
            ),
            const SizedBox(height: 24),

            // Confidence bar
            const Text(
              'Confidence Level',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ConfidenceBar(value: record.confidenceScore, height: 10),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 16),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                    color: AppColors.textHint, fontSize: 11),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
