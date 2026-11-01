import '../../../core/network/api_exceptions.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/roadmap_video_model.dart';
import '../../../data/repositories/video_repository.dart';
import '../load_status.dart';

class RoadmapVideoState extends Equatable {
  final LoadStatus status;
  final RoadmapVideoModel? video;
  final String? errorMessage;

  const RoadmapVideoState({
    this.status = LoadStatus.initial,
    this.video,
    this.errorMessage,
  });

  RoadmapVideoState copyWith({
    LoadStatus? status,
    RoadmapVideoModel? video,
    String? Function()? errorMessage,
  }) =>
      RoadmapVideoState(
        status: status ?? this.status,
        video: video ?? this.video,
        errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      );

  @override
  List<Object?> get props => [status, video, errorMessage];
}

/// Renders the "Lộ trình của tôi" video. The call blocks server-side for 30-60s on render.
class RoadmapVideoCubit extends Cubit<RoadmapVideoState> {
  final VideoRepository videoRepository;

  RoadmapVideoCubit({required this.videoRepository}) : super(const RoadmapVideoState());

  Future<void> generate({bool force = false}) async {
    if (state.status == LoadStatus.loading) return; // a second tap must not queue a render
    emit(state.copyWith(status: LoadStatus.loading, errorMessage: () => null));
    try {
      if (!force) {
        final existing = await videoRepository.getRoadmapVideo();
        if (existing != null) {
          if (isClosed) return;
          emit(state.copyWith(status: LoadStatus.success, video: existing));
          return;
        }
      }

      final video = await videoRepository.createRoadmapVideo(force: force);
      if (isClosed) return;
      emit(state.copyWith(status: LoadStatus.success, video: video));
    } catch (e) {
      if (isClosed) return;
      if (e is TimeoutException || e.toString().toLowerCase().contains('timeout')) {
        try {
          final fallback = await videoRepository.getRoadmapVideo();
          if (fallback != null) {
            emit(state.copyWith(status: LoadStatus.success, video: fallback));
            return;
          }
        } catch (_) {}
      }
      emit(state.copyWith(status: LoadStatus.failure, errorMessage: () => e.toString()));
    }
  }
}
