import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/providers.dart';
import '../../../../core/utils/widgets.dart';

class StreamScreen extends ConsumerStatefulWidget {
  const StreamScreen({super.key});

  @override
  ConsumerState<StreamScreen> createState() => _StreamScreenState();
}

class _StreamScreenState extends ConsumerState<StreamScreen> {
  bool _isMonitoring = false;
  bool _isConnecting = false;
  int _frameCount = 0;
  String _fps = '0';
  DateTime? _lastFrameTime;
  StreamSubscription? _sub;
  Uint8List? _currentFrame;
  String? _error;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  String get _streamUrl => ref.read(apiServiceProvider).streamUrl;

  Future<void> _toggleMonitoring() async {
    if (_isMonitoring) {
      _stopStream();
    } else {
      await _startStream();
    }
  }

  Future<void> _startStream() async {
    setState(() {
      _isConnecting = true;
      _error = null;
      _frameCount = 0;
      _fps = '0';
    });

    try {
      final request = http.Request('GET', Uri.parse(_streamUrl));
      final client = http.Client();
      final response = await client.send(request).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          client.close();
          throw TimeoutException('Connection timed out');
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      setState(() {
        _isMonitoring = true;
        _isConnecting = false;
      });

      // Parse MJPEG stream: boundary-separated JPEG frames
      final buffer = <int>[];
      _sub = response.stream.listen(
        (chunk) {
          buffer.addAll(chunk);
          _extractFrames(buffer);
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _error = 'Stream error: $e';
              _isMonitoring = false;
            });
          }
          client.close();
        },
        onDone: () {
          if (mounted) {
            setState(() {
              _isMonitoring = false;
              _isConnecting = false;
            });
          }
          client.close();
        },
        cancelOnError: true,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _error = 'Cannot connect to stream.\n$e';
        });
      }
    }
  }

  void _extractFrames(List<int> buffer) {
    // MJPEG frames start with 0xFF 0xD8 and end with 0xFF 0xD9
    const startMarker = [0xFF, 0xD8];
    const endMarker = [0xFF, 0xD9];

    var start = -1;
    for (var i = 0; i < buffer.length - 1; i++) {
      if (buffer[i] == startMarker[0] && buffer[i + 1] == startMarker[1]) {
        start = i;
      }
      if (start != -1 &&
          buffer[i] == endMarker[0] &&
          buffer[i + 1] == endMarker[1]) {
        final frameBytes =
            Uint8List.fromList(buffer.sublist(start, i + 2));
        buffer.removeRange(0, i + 2);

        if (mounted) {
          final now = DateTime.now();
          if (_lastFrameTime != null) {
            final diff = now.difference(_lastFrameTime!).inMilliseconds;
            if (diff > 0) {
              final fps = (1000 / diff).toStringAsFixed(1);
              setState(() {
                _currentFrame = frameBytes;
                _frameCount++;
                _fps = fps;
                _lastFrameTime = now;
              });
            }
          } else {
            setState(() {
              _currentFrame = frameBytes;
              _frameCount++;
              _lastFrameTime = now;
            });
          }
        }
        break;
      }
    }
  }

  void _stopStream() {
    _sub?.cancel();
    _sub = null;
    setState(() {
      _isMonitoring = false;
      _isConnecting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Live Stream'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              child: StatusDot(online: _isMonitoring),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                _isMonitoring ? 'LIVE' : 'IDLE',
                style: TextStyle(
                  color: _isMonitoring ? AppColors.online : AppColors.offline,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Video area ──
          Expanded(
            child: Stack(
              children: [
                // Frame display
                if (_currentFrame != null)
                  Center(
                    child: Image.memory(
                      _currentFrame!,
                      gaplessPlayback: true,
                      fit: BoxFit.contain,
                    ),
                  )
                else
                  _Placeholder(
                    isConnecting: _isConnecting,
                    error: _error,
                  ),

                // Overlay stats
                if (_isMonitoring)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: _StatsOverlay(
                      frameCount: _frameCount,
                      fps: _fps,
                    ),
                  ),
              ],
            ),
          ),

          // ── Controls ──
          Container(
            padding: const EdgeInsets.all(20),
            color: AppColors.surface,
            child: Column(
              children: [
                // Server URL hint
                Text(
                  'Stream: $_streamUrl',
                  style: const TextStyle(
                    color: AppColors.textHint,
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 16),

                // Start/Stop button
                ElevatedButton.icon(
                  onPressed: _isConnecting ? null : _toggleMonitoring,
                  icon: Icon(
                    _isMonitoring
                        ? Icons.stop_rounded
                        : Icons.play_arrow_rounded,
                  ),
                  label: Text(
                    _isConnecting
                        ? 'Connecting…'
                        : _isMonitoring
                            ? 'Stop Monitoring'
                            : 'Start Monitoring',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _isMonitoring ? AppColors.accent : AppColors.primary,
                  ),
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final bool isConnecting;
  final String? error;

  const _Placeholder({required this.isConnecting, this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isConnecting) ...[
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              'Connecting to stream…',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.videocam_off_rounded,
                color: AppColors.textHint,
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Stream not active',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Press Start Monitoring to connect\nto the MJPEG stream',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatsOverlay extends StatelessWidget {
  final int frameCount;
  final String fps;

  const _StatsOverlay({required this.frameCount, required this.fps});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '● LIVE',
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            '$fps fps',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
          Text(
            '$frameCount frames',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
