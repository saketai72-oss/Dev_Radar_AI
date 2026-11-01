import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/app_colors.dart';

/// Interactive glassmorphism video player for Dev Radar AI.
///
/// Features:
/// - Reliable mute / unmute toggle (sync state + web autoplay support).
/// - Play / pause / toggle on tap or button.
/// - Interactive scrubber bar + timestamp indicators (`mm:ss / mm:ss`).
/// - Quick seek: +/- 5 seconds.
/// - Fullscreen modal player with seamless controller handover (no reload).
/// - Auto-hiding control overlays.
class DevRadarVideoPlayer extends StatefulWidget {
  final String url;
  final VideoPlayerController? controller;
  final bool isFullscreen;

  const DevRadarVideoPlayer({
    super.key,
    required this.url,
    this.controller,
    this.isFullscreen = false,
  });

  @override
  State<DevRadarVideoPlayer> createState() => _DevRadarVideoPlayerState();
}

class _DevRadarVideoPlayerState extends State<DevRadarVideoPlayer> {
  late final VideoPlayerController _controller;
  late final bool _ownsController;
  bool _ready = false;
  bool _hasError = false;
  bool _isMuted = kIsWeb; // Web browsers block unmuted autoplay
  bool _isPlaying = true;
  bool _showControls = true;
  Timer? _hideTimer;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
      _ready = _controller.value.isInitialized;
      _isPlaying = _controller.value.isPlaying;
      _isMuted = _controller.value.volume == 0;
      _position = _controller.value.position;
      _duration = _controller.value.duration;
      _controller.addListener(_onControllerUpdate);
      _startHideTimer();
    } else {
      _ownsController = true;
      _initNewController();
    }
  }

  void _initNewController() {
    setState(() {
      _ready = false;
      _hasError = false;
    });

    final initialVolume = kIsWeb ? 0.0 : 1.0;
    _isMuted = initialVolume == 0.0;
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..setVolume(initialVolume)
      ..setLooping(true);

    _controller.addListener(_onControllerUpdate);

    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() {
        _ready = true;
        _hasError = false;
        _duration = _controller.value.duration;
      });
      _controller.play();
      _startHideTimer();
    }).catchError((_) {
      if (!mounted) return;
      setState(() {
        _ready = false;
        _hasError = true;
      });
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.removeListener(_onControllerUpdate);
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onControllerUpdate() {
    if (!mounted) return;
    final val = _controller.value;
    final pos = val.position;
    final dur = val.duration;
    final playing = val.isPlaying;
    final muted = val.volume == 0;

    if (_position != pos || _duration != dur || _isPlaying != playing || _isMuted != muted) {
      setState(() {
        _position = pos;
        _duration = dur;
        _isPlaying = playing;
        _isMuted = muted;
      });
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _resetHideTimer() {
    setState(() => _showControls = true);
    if (_isPlaying) {
      _startHideTimer();
    }
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      if (_showControls && _isPlaying) {
        _startHideTimer();
      }
    });
  }

  void _togglePlayPause() {
    if (!_ready) return;
    if (_controller.value.isPlaying) {
      _controller.pause();
      _hideTimer?.cancel();
      setState(() {
        _isPlaying = false;
        _showControls = true;
      });
    } else {
      _controller.play();
      setState(() {
        _isPlaying = true;
        _showControls = true;
      });
      _startHideTimer();
    }
  }

  void _toggleMute() {
    final nextMuted = !_isMuted;
    setState(() => _isMuted = nextMuted);
    _controller.setVolume(nextMuted ? 0.0 : 1.0);
    _resetHideTimer();
  }

  void _seekRelative(int secondsDelta) {
    if (!_ready) return;
    final newMs = (_position.inMilliseconds + secondsDelta * 1000)
        .clamp(0, _duration.inMilliseconds);
    _controller.seekTo(Duration(milliseconds: newMs));
    _resetHideTimer();
  }

  void _seekTo(Duration target) {
    if (!_ready) return;
    _controller.seekTo(target);
    _resetHideTimer();
  }

  void _openFullscreen() {
    if (widget.isFullscreen) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: DevRadarVideoPlayer(
              url: widget.url,
              controller: _controller,
              isFullscreen: true,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 40),
            const SizedBox(height: 12),
            const Text(
              'Không thể tải video',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _initNewController,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (!_ready) {
      return const Center(child: CircularProgressIndicator());
    }

    final maxMs = _duration.inMilliseconds > 0 ? _duration.inMilliseconds : 1;
    final currentMs = _position.inMilliseconds.clamp(0, maxMs);

    return GestureDetector(
      onTap: _toggleControls,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video surface
          Center(
            child: AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            ),
          ),

          // Central play icon overlay (when paused or controls active)
          if (!_isPlaying || _showControls)
            Center(
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Material(
                  color: Colors.black45,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _togglePlayPause,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // Top action bar (Mute + Fullscreen toggle)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: _showControls ? 10 : -60,
            left: 10,
            right: 10,
            child: Row(
              children: [
                if (widget.isFullscreen)
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    tooltip: 'Thoát toàn màn hình',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                const Spacer(),
                // Mute / Unmute pill button
                Material(
                  color: Colors.black.withAlpha(170),
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _toggleMute,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isMuted ? 'Bật tiếng' : 'Tắt tiếng',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Fullscreen button
                Material(
                  color: Colors.black.withAlpha(170),
                  borderRadius: BorderRadius.circular(20),
                  child: IconButton(
                    iconSize: 20,
                    icon: Icon(
                      widget.isFullscreen
                          ? Icons.fullscreen_exit_rounded
                          : Icons.fullscreen_rounded,
                      color: Colors.white,
                    ),
                    tooltip: widget.isFullscreen ? 'Thu nhỏ' : 'Toàn màn hình',
                    onPressed: widget.isFullscreen
                        ? () => Navigator.of(context).pop()
                        : _openFullscreen,
                  ),
                ),
              ],
            ),
          ),

          // Bottom control bar (Play/pause, rewind, scrub bar, forward, timestamp)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            bottom: _showControls ? 10 : -90,
            left: 10,
            right: 10,
            child: Material(
              color: Colors.black.withAlpha(190),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Scrub slider
                    Row(
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3.5,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                              activeTrackColor: AppColors.primary,
                              inactiveTrackColor: Colors.white24,
                              thumbColor: AppColors.primary,
                            ),
                            child: Slider(
                              value: currentMs.toDouble(),
                              min: 0.0,
                              max: maxMs.toDouble(),
                              onChanged: (val) {
                                _seekTo(Duration(milliseconds: val.toInt()));
                              },
                            ),
                          ),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    // Controls row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          iconSize: 22,
                          icon: const Icon(Icons.replay_5_rounded, color: Colors.white),
                          tooltip: 'Lùi 5s',
                          onPressed: () => _seekRelative(-5),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          iconSize: 32,
                          icon: Icon(
                            _isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                            color: Colors.white,
                          ),
                          tooltip: _isPlaying ? 'Tạm dừng' : 'Phát tiếp',
                          onPressed: _togglePlayPause,
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          iconSize: 22,
                          icon: const Icon(Icons.forward_5_rounded, color: Colors.white),
                          tooltip: 'Tiến 5s',
                          onPressed: () => _seekRelative(5),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
