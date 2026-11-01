import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/repositories/video_repository.dart';
import '../../state/load_status.dart';
import '../../state/video/repo_video_cubit.dart';
import '../../widgets/common/glass_page_scaffold.dart';
import '../../widgets/common/state_views.dart';
import '../../widgets/video/video_result_view.dart';

/// Renders a detailed analysis video for a specific repository (9:16)
/// and allows viewing and sharing it via the system share sheet.
class RepoVideoScreen extends StatelessWidget {
  final int repoId;
  final String repoName;
  final String repoFullName;

  const RepoVideoScreen({
    super.key,
    required this.repoId,
    required this.repoName,
    required this.repoFullName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (ctx) => RepoVideoCubit(
        videoRepository: ctx.read<VideoRepository>(),
        repoId: repoId,
      )..generate(),
      child: _RepoVideoView(
        repoName: repoName,
        repoFullName: repoFullName,
      ),
    );
  }
}

class _RepoVideoView extends StatelessWidget {
  final String repoName;
  final String repoFullName;

  const _RepoVideoView({
    required this.repoName,
    required this.repoFullName,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RepoVideoCubit, RepoVideoState>(
      builder: (context, state) {
        final cubit = context.read<RepoVideoCubit>();
        return GlassPageScaffold(
          title: 'Phân tích $repoName',
          subtitle: 'Video tổng quan chuyên sâu: $repoFullName',
          body: switch (state.status) {
            LoadStatus.initial || LoadStatus.loading => const _Rendering(),
            LoadStatus.failure => ErrorRetryView(
                message: state.errorMessage ?? 'Không tạo được video phân tích',
                onRetry: cubit.generate,
              ),
            LoadStatus.success => _Result(
                url: ApiConstants.absoluteUrl(state.video!.url),
                repoName: repoName,
                repoFullName: repoFullName,
              ),
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
          const Text('Đang dựng video phân tích...', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            'Đang tổng hợp thông tin, giọng đọc tiếng Việt và hiệu ứng.\nMất khoảng 30-60 giây, bạn đừng rời màn hình nhé.',
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
  final String repoName;
  final String repoFullName;

  const _Result({
    required this.url,
    required this.repoName,
    required this.repoFullName,
  });

  @override
  Widget build(BuildContext context) {
    return VideoResultView(
      url: url,
      onRegenerate: () => context.read<RepoVideoCubit>().generate(force: true),
      onShare: _share,
    );
  }

  Future<void> _share(BuildContext buttonContext) async {
    await SharePlus.instance.share(
      ShareParams(
        title: 'Video phân tích $repoName',
        text: 'Xem video phân tích chi tiết repository $repoFullName trên Dev Radar AI!',
        uri: Uri.parse(url),
        sharePositionOrigin: sharePositionOf(buttonContext),
      ),
    );
  }
}
