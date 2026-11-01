import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exceptions.dart';

/// Raw JSON calls for /videos. The repository parses the result.
abstract class VideoRemoteDataSource {
  /// GET /videos/roadmap -> RoadmapVideoOut or null if 404.
  Future<Map<String, dynamic>?> getRoadmapVideo();

  /// GET /videos/repos/{repo_id} -> RoadmapVideoOut or null if 404.
  Future<Map<String, dynamic>?> getRepoVideo(int repoId);

  /// POST /videos/roadmap?force={force} -> RoadmapVideoOut {job_id, url, duration_seconds, size_bytes}.
  /// Blocks server-side for 30-60 seconds while the engine renders.
  Future<Map<String, dynamic>> createRoadmapVideo({bool force = false});

  /// POST /videos/repos/{repo_id}?force={force} -> RoadmapVideoOut {job_id, url, duration_seconds, size_bytes}.
  Future<Map<String, dynamic>> createRepoVideo(int repoId, {bool force = false});
}

class VideoRemoteDataSourceImpl implements VideoRemoteDataSource {
  final ApiClient apiClient;

  VideoRemoteDataSourceImpl({required this.apiClient});

  @override
  Future<Map<String, dynamic>?> getRoadmapVideo() async {
    try {
      final response = await apiClient.get('${ApiConstants.videos}/roadmap');
      return response.data as Map<String, dynamic>?;
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.message.contains('404')) return null;
      rethrow;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>?> getRepoVideo(int repoId) async {
    try {
      final response = await apiClient.get('${ApiConstants.videos}/repos/$repoId');
      return response.data as Map<String, dynamic>?;
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.message.contains('404')) return null;
      rethrow;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> createRoadmapVideo({bool force = false}) async {
    final response = await apiClient.post(
      '${ApiConstants.videos}/roadmap',
      queryParameters: {'force': force},
      // A render takes 30-60s, far past the client's 30s default.
      options: Options(
        sendTimeout: ApiConstants.slowRequestTimeout,
        receiveTimeout: ApiConstants.slowRequestTimeout,
      ),
    );
    return response.data as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> createRepoVideo(int repoId, {bool force = false}) async {
    final response = await apiClient.post(
      '${ApiConstants.videos}/repos/$repoId',
      queryParameters: {'force': force},
      options: Options(
        sendTimeout: ApiConstants.slowRequestTimeout,
        receiveTimeout: ApiConstants.slowRequestTimeout,
      ),
    );
    return response.data as Map<String, dynamic>;
  }
}
