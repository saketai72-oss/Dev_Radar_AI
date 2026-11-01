import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/video/dev_radar_video_player.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/video_repository.dart';
import '../../state/load_status.dart';
import '../../state/video/roadmap_video_cubit.dart';
import '../../widgets/common/glass_page_scaffold.dart';
import '../../widgets/common/state_views.dart';
import '../../widgets/glass/glass_button.dart';
import '../../widgets/glass/glass_card.dart';
import '../../widgets/glass/glass_icon_button.dart';

/// Renders the user's learning roadmap as a 9:16 video and offers it to the
/// system share sheet. Launching this screen starts the render: the button that
/// opens it already said "create".
class RoadmapVideoScreen extends StatelessWidget {
  const RoadmapVideoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => RoadmapVideoCubit(videoRepository: ctx.read<VideoRepository>())..generate(),
      child: const _RoadmapVideoView(),
    );
  }
}

class _RoadmapVideoView extends StatelessWidget {
  const _RoadmapVideoView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RoadmapVideoCubit, RoadmapVideoState>(
      builder: (context, state) {
        final cubit = context.read<RoadmapVideoCubit>();
        return GlassPageScaffold(
          title: 'Video lộ trình',
          subtitle: 'Tổng kết hành trình học tập của bạn',
          body: switch (state.status) {
            LoadStatus.initial || LoadStatus.loading => const _Rendering(),
            LoadStatus.failure => ErrorRetryView(
                message: state.errorMessage ?? 'Không tạo được video',
                onRetry: cubit.generate,
              ),
            LoadStatus.success => _Result(url: ApiConstants.absoluteUrl(state.video!.url)),
          },
        );
      },
    );
  }
}

class _Rendering extends StatelessWidget {
  const _Rendering();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 20),
          const Text('Đang dựng video...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'Mất khoảng 30-60 giây. Bạn đừng rời màn hình nhé.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  final String url;

  const _Result({required this.url});

  @override
  Widget build(BuildContext context) {
    return Column(
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
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: GlassButton(
                text: 'Chia sẻ video',
                icon: Icons.ios_share_rounded,
                height: 56,
                onPressed: () => _share(context),
              ),
            ),
            const SizedBox(width: 12),
            GlassIconButton(
              icon: Icons.refresh_rounded,
              tooltip: 'Dựng lại video mới',
              size: 56,
              iconSize: 22,
              onPressed: () => context.read<RoadmapVideoCubit>().generate(force: true),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _share(BuildContext context) async {
    // iPad anchors the sheet to the button that opened it.
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        title: 'Lộ trình học tập của tôi',
        text: 'Xem tổng kết Lộ trình học tập Dev Radar AI của tôi!',
        uri: Uri.parse(url),
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }
}
