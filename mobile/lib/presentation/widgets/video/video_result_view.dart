import 'package:flutter/material.dart';

import '../glass/glass_button.dart';
import '../glass/glass_card.dart';
import 'dev_radar_video_player.dart';

/// Rendered video (9:16) with a balanced action row: "Dựng lại" and "Chia sẻ" side by
/// side, same size. Shared by the repo video and the roadmap video screens.
///
/// The body of GlassPageScaffold has no padding, so this view adds the same 16 px
/// side gutter as the page header, plus room above the system navigation bar.
class VideoResultView extends StatelessWidget {
  final String url;
  final VoidCallback onRegenerate;

  /// Called with the share button's context, so the share sheet can anchor to it (iPad).
  final void Function(BuildContext buttonContext) onShare;

  const VideoResultView({
    super.key,
    required this.url,
    required this.onRegenerate,
    required this.onShare,
  });

  static const double _gutter = 16;
  static const double _buttonHeight = 52;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(_gutter, 4, _gutter, _gutter),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: GlassCard(
                padding: const EdgeInsets.all(10),
                borderRadius: 24,
                child: AspectRatio(aspectRatio: 9 / 16, child: DevRadarVideoPlayer(url: url)),
              ),
            ),
          ),
          const SizedBox(height: _gutter),
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  text: 'Dựng lại',
                  icon: Icons.refresh_rounded,
                  style: GlassButtonStyle.secondary,
                  height: _buttonHeight,
                  onPressed: onRegenerate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Builder(
                  builder: (buttonContext) => GlassButton(
                    text: 'Chia sẻ',
                    icon: Icons.ios_share_rounded,
                    height: _buttonHeight,
                    onPressed: () => onShare(buttonContext),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Where the share sheet should point to on iPad: the given widget's box on screen.
Rect? sharePositionOf(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  return box == null ? null : box.localToGlobal(Offset.zero) & box.size;
}
