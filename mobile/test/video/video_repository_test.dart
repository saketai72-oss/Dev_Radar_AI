import 'package:dev_radar_ai/data/datasources/remote/video_remote_datasource.dart';
import 'package:dev_radar_ai/data/repositories/video_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockVideoRemoteDataSource extends Mock implements VideoRemoteDataSource {}

void main() {
  late MockVideoRemoteDataSource remote;
  late VideoRepository repository;

  setUp(() {
    remote = MockVideoRemoteDataSource();
    repository = VideoRepositoryImpl(remoteDataSource: remote);
  });

  group('getRoadmapVideo', () {
    test('returns RoadmapVideoModel when video is cached', () async {
      when(() => remote.getRoadmapVideo()).thenAnswer((_) async => {
            'job_id': 'abc123',
            'url': '/api/v1/videos/abc123',
            'duration_seconds': 19.05,
            'size_bytes': 691932,
          });

      final video = await repository.getRoadmapVideo();

      expect(video, isNotNull);
      expect(video!.jobId, 'abc123');
      expect(video.url, '/api/v1/videos/abc123');
      expect(video.durationSeconds, closeTo(19.05, 0.001));
      expect(video.sizeBytes, 691932);
      verify(() => remote.getRoadmapVideo()).called(1);
    });

    test('returns null when video is not cached (404)', () async {
      when(() => remote.getRoadmapVideo()).thenAnswer((_) async => null);

      final video = await repository.getRoadmapVideo();

      expect(video, isNull);
      verify(() => remote.getRoadmapVideo()).called(1);
    });
  });

  group('getRepoVideo', () {
    test('returns RoadmapVideoModel when repo video is cached', () async {
      when(() => remote.getRepoVideo(42)).thenAnswer((_) async => {
            'job_id': 'repo_xyz',
            'url': '/api/v1/videos/repo_xyz',
            'duration_seconds': 25.5,
            'size_bytes': 850000,
          });

      final video = await repository.getRepoVideo(42);

      expect(video, isNotNull);
      expect(video!.jobId, 'repo_xyz');
      expect(video.url, '/api/v1/videos/repo_xyz');
      expect(video.durationSeconds, closeTo(25.5, 0.001));
      expect(video.sizeBytes, 850000);
      verify(() => remote.getRepoVideo(42)).called(1);
    });

    test('returns null when repo video is not cached (404)', () async {
      when(() => remote.getRepoVideo(42)).thenAnswer((_) async => null);

      final video = await repository.getRepoVideo(42);

      expect(video, isNull);
      verify(() => remote.getRepoVideo(42)).called(1);
    });
  });

  group('createRoadmapVideo', () {
    test('parses the render result with default force=false', () async {
      when(() => remote.createRoadmapVideo(force: false)).thenAnswer((_) async => {
            'job_id': 'abc123',
            'url': '/api/v1/videos/abc123',
            'duration_seconds': 19.05,
            'size_bytes': 691932,
          });

      final video = await repository.createRoadmapVideo();

      expect(video.jobId, 'abc123');
      expect(video.url, '/api/v1/videos/abc123');
      expect(video.durationSeconds, closeTo(19.05, 0.001));
      expect(video.sizeBytes, 691932);
      verify(() => remote.createRoadmapVideo(force: false)).called(1);
    });

    test('passes force=true when specified', () async {
      when(() => remote.createRoadmapVideo(force: true)).thenAnswer((_) async => {
            'job_id': 'abc_forced',
            'url': '/api/v1/videos/abc_forced',
            'duration_seconds': 20.0,
            'size_bytes': 700000,
          });

      final video = await repository.createRoadmapVideo(force: true);

      expect(video.jobId, 'abc_forced');
      verify(() => remote.createRoadmapVideo(force: true)).called(1);
    });

    test('propagates a failure (e.g. 400 on an empty roadmap)', () async {
      when(() => remote.createRoadmapVideo(force: false)).thenThrow(Exception('Lộ trình còn trống'));

      expect(repository.createRoadmapVideo(), throwsA(isA<Exception>()));
    });
  });

  group('createRepoVideo', () {
    test('parses the repo render result with default force=false', () async {
      when(() => remote.createRepoVideo(42, force: false)).thenAnswer((_) async => {
            'job_id': 'repo_xyz',
            'url': '/api/v1/videos/repo_xyz',
            'duration_seconds': 25.5,
            'size_bytes': 850000,
          });

      final video = await repository.createRepoVideo(42);

      expect(video.jobId, 'repo_xyz');
      expect(video.url, '/api/v1/videos/repo_xyz');
      expect(video.durationSeconds, closeTo(25.5, 0.001));
      expect(video.sizeBytes, 850000);
      verify(() => remote.createRepoVideo(42, force: false)).called(1);
    });

    test('passes force=true when specified', () async {
      when(() => remote.createRepoVideo(42, force: true)).thenAnswer((_) async => {
            'job_id': 'repo_forced',
            'url': '/api/v1/videos/repo_forced',
            'duration_seconds': 26.0,
            'size_bytes': 860000,
          });

      final video = await repository.createRepoVideo(42, force: true);

      expect(video.jobId, 'repo_forced');
      verify(() => remote.createRepoVideo(42, force: true)).called(1);
    });
  });
}
