import 'package:bloc_test/bloc_test.dart';
import 'package:dev_radar_ai/core/network/api_exceptions.dart';
import 'package:dev_radar_ai/data/models/roadmap_video_model.dart';
import 'package:dev_radar_ai/data/repositories/video_repository.dart';
import 'package:dev_radar_ai/presentation/state/load_status.dart';
import 'package:dev_radar_ai/presentation/state/video/repo_video_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockVideoRepository extends Mock implements VideoRepository {}

const repoVideo = RoadmapVideoModel(
  jobId: 'repo_abc',
  url: '/api/v1/videos/repo_abc',
  durationSeconds: 22.0,
  sizeBytes: 750000,
);

void main() {
  late MockVideoRepository videos;

  setUp(() => videos = MockVideoRepository());

  RepoVideoCubit build() => RepoVideoCubit(videoRepository: videos, repoId: 99);

  blocTest<RepoVideoCubit, RepoVideoState>(
    'generate with cached video returns instant replay without calling createRepoVideo',
    build: () {
      when(() => videos.getRepoVideo(99)).thenAnswer((_) async => repoVideo);
      return build();
    },
    act: (cubit) => cubit.generate(),
    verify: (cubit) {
      expect(cubit.state.status, LoadStatus.success);
      expect(cubit.state.video, repoVideo);
      expect(cubit.state.errorMessage, isNull);
      verify(() => videos.getRepoVideo(99)).called(1);
      verifyNever(() => videos.createRepoVideo(any(), force: any(named: 'force')));
    },
  );

  blocTest<RepoVideoCubit, RepoVideoState>(
    'generate with cache miss calls createRepoVideo with force: false',
    build: () {
      when(() => videos.getRepoVideo(99)).thenAnswer((_) async => null);
      when(() => videos.createRepoVideo(99, force: false)).thenAnswer((_) async => repoVideo);
      return build();
    },
    act: (cubit) => cubit.generate(),
    verify: (cubit) {
      expect(cubit.state.status, LoadStatus.success);
      expect(cubit.state.video, repoVideo);
      expect(cubit.state.errorMessage, isNull);
      verify(() => videos.getRepoVideo(99)).called(1);
      verify(() => videos.createRepoVideo(99, force: false)).called(1);
    },
  );

  blocTest<RepoVideoCubit, RepoVideoState>(
    'generate with force: true skips cache check and calls createRepoVideo with force: true',
    build: () {
      when(() => videos.createRepoVideo(99, force: true)).thenAnswer((_) async => repoVideo);
      return build();
    },
    act: (cubit) => cubit.generate(force: true),
    verify: (cubit) {
      expect(cubit.state.status, LoadStatus.success);
      expect(cubit.state.video, repoVideo);
      expect(cubit.state.errorMessage, isNull);
      verifyNever(() => videos.getRepoVideo(any()));
      verify(() => videos.createRepoVideo(99, force: true)).called(1);
    },
  );

  blocTest<RepoVideoCubit, RepoVideoState>(
    'generate reports a failure',
    build: () {
      when(() => videos.getRepoVideo(99)).thenAnswer((_) async => null);
      when(() => videos.createRepoVideo(99, force: false))
          .thenThrow(ApiException('Không tìm thấy repository', statusCode: 404));
      return build();
    },
    act: (cubit) => cubit.generate(),
    verify: (cubit) {
      expect(cubit.state.status, LoadStatus.failure);
      expect(cubit.state.errorMessage, 'Không tìm thấy repository');
    },
  );

  blocTest<RepoVideoCubit, RepoVideoState>(
    'a second tap while rendering does not queue another render',
    build: () {
      when(() => videos.getRepoVideo(99)).thenAnswer((_) async => repoVideo);
      return build();
    },
    act: (cubit) async {
      final first = cubit.generate();
      await cubit.generate();
      await first;
    },
    verify: (_) => verify(() => videos.getRepoVideo(99)).called(1),
  );

  test('initial state is idle with no video', () {
    final cubit = build();
    expect(cubit.state.status, LoadStatus.initial);
    expect(cubit.state.video, isNull);
    cubit.close();
  });
}
