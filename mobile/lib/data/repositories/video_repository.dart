import '../datasources/remote/video_remote_datasource.dart';
import '../models/roadmap_video_model.dart';

/// The roadmap video repository with caching and replay support.
abstract class VideoRepository {
  /// Fetches an existing cached roadmap video, or null if 404/not found.
  Future<RoadmapVideoModel?> getRoadmapVideo();

  /// Fetches an existing cached repo video, or null if 404/not found.
  Future<RoadmapVideoModel?> getRepoVideo(int repoId);

  /// Renders a summary video of the caller's learning roadmap. Blocks for
  /// 30-60 seconds. Throws a 400 when the roadmap is empty.
  Future<RoadmapVideoModel> createRoadmapVideo({bool force = false});

  /// Renders a detailed analysis video for a specific repo. Blocks for 30-60 seconds.
  Future<RoadmapVideoModel> createRepoVideo(int repoId, {bool force = false});
}

class VideoRepositoryImpl implements VideoRepository {
  final VideoRemoteDataSource remoteDataSource;

  VideoRepositoryImpl({required this.remoteDataSource});

  @override
  Future<RoadmapVideoModel?> getRoadmapVideo() async {
    final data = await remoteDataSource.getRoadmapVideo();
    return data != null ? RoadmapVideoModel.fromJson(data) : null;
  }

  @override
  Future<RoadmapVideoModel?> getRepoVideo(int repoId) async {
    final data = await remoteDataSource.getRepoVideo(repoId);
    return data != null ? RoadmapVideoModel.fromJson(data) : null;
  }

  @override
  Future<RoadmapVideoModel> createRoadmapVideo({bool force = false}) async =>
      RoadmapVideoModel.fromJson(await remoteDataSource.createRoadmapVideo(force: force));

  @override
  Future<RoadmapVideoModel> createRepoVideo(int repoId, {bool force = false}) async =>
      RoadmapVideoModel.fromJson(await remoteDataSource.createRepoVideo(repoId, force: force));
}
