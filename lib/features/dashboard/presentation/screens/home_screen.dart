import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/providers.dart';
import '../../../../core/utils/widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    // Refresh server status every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.invalidate(serverStatusProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Sign Out',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style:
                ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(authServiceProvider).signOut();
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authServiceProvider).currentUserEmail ?? '';
    final serverStatus = ref.watch(serverStatusProvider);
    final todayCount = ref.watch(todayCountProvider);
    final unread = ref.watch(unreadCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('PrintGuard AI'),
        actions: [
          IconButton(
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
      tooltip: 'Settings',
    ),
          // Notification bell with badge
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.notifications),
              ),
              unread.when(
                data: (count) => count > 0
                    ? Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              count > 9 ? '9+' : '$count',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 9),
                            ),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            onPressed: _signOut,
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        onRefresh: () async {
          ref.invalidate(serverStatusProvider);
          ref.invalidate(todayCountProvider);
          ref.invalidate(unreadCountProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Greeting ──
              Text(
                'Hello, ${email.split('@').first}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Monitor your 3D prints',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),

              // ── Status card ──
              serverStatus.when(
                data: (status) => _StatusCard(status: status),
                loading: () => const _StatusCardShimmer(),
                error: (_, __) => _StatusCard(status: null),
              ),
              const SizedBox(height: 24),

              // ── Quick stats row ──
              Row(
                children: [
                  Expanded(
                    child: StatTile(
                      label: 'Detections Today',
                      value: todayCount.when(
                        data: (n) => '$n',
                        loading: () => '—',
                        error: (_, __) => '—',
                      ),
                      icon: Icons.radar_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatTile(
                      label: 'Unread Alerts',
                      value: unread.when(
                        data: (n) => '$n',
                        loading: () => '—',
                        error: (_, __) => '—',
                      ),
                      icon: Icons.notifications_active_rounded,
                      color: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const SectionHeader(title: 'QUICK ACCESS'),
              const SizedBox(height: 12),

              // ── Navigation grid ──
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
                children: [
                  _NavCard(
                    title: 'Live Stream',
                    subtitle: 'Real-time MJPEG feed',
                    icon: Icons.videocam_rounded,
                    color: const Color(0xFF1565C0),
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.stream),
                  ),
                  _NavCard(
                    title: 'Detection',
                    subtitle: 'Capture & analyze',
                    icon: Icons.center_focus_strong_rounded,
                    color: AppColors.primary,
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.detection),
                  ),
                  _NavCard(
                    title: 'Alerts',
                    subtitle: 'Detection history',
                    icon: Icons.notifications_rounded,
                    color: AppColors.accent,
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.notifications),
                    badge: unread.whenOrNull(data: (n) => n > 0 ? '$n' : null),
                  ),
                  _NavCard(
                    title: 'Statistics',
                    subtitle: 'Analytics & charts',
                    icon: Icons.bar_chart_rounded,
                    color: const Color(0xFF6A1B9A),
                    onTap: () =>
                        Navigator.pushNamed(context, AppRoutes.statistics),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // ── System indicators ──
              const SectionHeader(title: 'SYSTEM STATUS'),
              const SizedBox(height: 12),
              serverStatus.when(
                data: (s) => _SystemIndicators(status: s),
                loading: () => const _SystemIndicators(status: null),
                error: (_, __) => const _SystemIndicators(status: null),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Status card widget ─────────────────────────

class _StatusCard extends StatelessWidget {
  final dynamic status; // ServerStatus or null

  const _StatusCard({this.status});

  @override
  Widget build(BuildContext context) {
    final isOnline = status?.modelLoaded == true;
    const lastStr = 'N/A';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOnline
              ? [
                  AppColors.primaryDark,
                  AppColors.primary,
                ]
              : [
                  const Color(0xFF1a1a2e),
                  const Color(0xFF2d1b1b),
                ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isOnline ? AppColors.primary : AppColors.accent)
                .withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusDot(online: isOnline, size: 10),
              const SizedBox(width: 8),
              Text(
                isOnline ? 'AI Model Online' : 'AI Model Offline',
                style: TextStyle(
                  color:
                      isOnline ? AppColors.textPrimary : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isOnline ? 'LIVE' : 'OFFLINE',
                  style: TextStyle(
                    color: isOnline ? AppColors.ok : AppColors.accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _StatusInfo(
                label: 'Last detection',
                value: lastStr,
                icon: Icons.access_time_rounded,
              ),
              const SizedBox(width: 24),
              _StatusInfo(
  label: 'Server version',
  value: status?.serverVersion ?? '—',
  icon: Icons.info_outline_rounded,
),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusInfo extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatusInfo({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 14),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusCardShimmer extends StatelessWidget {
  const _StatusCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

// ── Nav card widget ────────────────────────────

class _NavCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? badge;

  const _NavCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.divider),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            if (badge != null)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── System indicators row ──────────────────────

class _SystemIndicators extends StatelessWidget {
  final dynamic status;

  const _SystemIndicators({this.status});

  @override
  Widget build(BuildContext context) {
    final modelOk = status?.modelLoaded == true;


    return Row(
      children: [
        _Indicator(
          label: 'Server',
          online: status != null,
          icon: Icons.dns_rounded,
        ),
        const SizedBox(width: 12),
        _Indicator(
          label: 'AI Model',
          online: modelOk,
          icon: Icons.psychology_rounded,
        ),
        const SizedBox(width: 12),
        _Indicator(
          label: 'Camera',
          online: status?.cameraConnected == true,
          icon: Icons.videocam_rounded,
        ),
      ],
    );
  }
}

class _Indicator extends StatelessWidget {
  final String label;
  final bool online;
  final IconData icon;

  const _Indicator({
    required this.label,
    required this.online,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            StatusDot(online: online),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    online ? 'OK' : 'Offline',
                    style: TextStyle(
                      color:
                          online ? AppColors.online : AppColors.offline,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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
