import 'package:bloc_test/bloc_test.dart';
import 'package:dev_radar_ai/core/network/api_exceptions.dart';
import 'package:dev_radar_ai/data/models/roadmap_video_model.dart';
import 'package:dev_radar_ai/data/repositories/video_repository.dart';
import 'package:dev_radar_ai/presentation/state/load_status.dart';
import 'package:dev_radar_ai/presentation/state/video/roadmap_video_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockVideoRepository extends Mock implements VideoRepository {}

const video = RoadmapVideoModel(
  jobId: 'abc123',
  url: '/api/v1/videos/abc123',
  durationSeconds: 19.05,
  sizeBytes: 691932,
);

void main() {
  late MockVideoRepository videos;

  setUp(() => videos = MockVideoRepository());

  RoadmapVideoCubit build() => RoadmapVideoCubit(videoRepository: videos);

  blocTest<RoadmapVideoCubit, RoadmapVideoState>(
    'generate with cached video returns instant replay without calling createRoadmapVideo',
    build: () {
      when(() => videos.getRoadmapVideo()).thenAnswer((_) async => video);
      return build();
    },
    act: (cubit) => cubit.generate(),
    verify: (cubit) {
      expect(cubit.state.status, LoadStatus.success);
      expect(cubit.state.video, video);
      expect(cubit.state.errorMessage, isNull);
      verify(() => videos.getRoadmapVideo()).called(1);
      verifyNever(() => videos.createRoadmapVideo(force: any(named: 'force')));
    },
  );

  blocTest<RoadmapVideoCubit, RoadmapVideoState>(
    'generate with cache miss calls createRoadmapVideo with force: false',
    build: () {
      when(() => videos.getRoadmapVideo()).thenAnswer((_) async => null);
      when(() => videos.createRoadmapVideo(force: false)).thenAnswer((_) async => video);
      return build();
    },
    act: (cubit) => cubit.generate(),
    verify: (cubit) {
      expect(cubit.state.status, LoadStatus.success);
      expect(cubit.state.video, video);
      expect(cubit.state.errorMessage, isNull);
      verify(() => videos.getRoadmapVideo()).called(1);
      verify(() => videos.createRoadmapVideo(force: false)).called(1);
    },
  );

  blocTest<RoadmapVideoCubit, RoadmapVideoState>(
    'generate with force: true skips cache check and calls createRoadmapVideo with force: true',
    build: () {
      when(() => videos.createRoadmapVideo(force: true)).thenAnswer((_) async => video);
      return build();
    },
    act: (cubit) => cubit.generate(force: true),
    verify: (cubit) {
      expect(cubit.state.status, LoadStatus.success);
      expect(cubit.state.video, video);
      expect(cubit.state.errorMessage, isNull);
      verifyNever(() => videos.getRoadmapVideo());
      verify(() => videos.createRoadmapVideo(force: true)).called(1);
    },
  );

  blocTest<RoadmapVideoCubit, RoadmapVideoState>(
    'generate reports a failure, e.g. an empty roadmap',
    build: () {
      when(() => videos.getRoadmapVideo()).thenAnswer((_) async => null);
      when(() => videos.createRoadmapVideo(force: false))
          .thenThrow(ApiException('Lộ trình còn trống, chưa thể tạo video', statusCode: 400));
      return build();
    },
    act: (cubit) => cubit.generate(),
    verify: (cubit) {
      expect(cubit.state.status, LoadStatus.failure);
      expect(cubit.state.errorMessage, 'Lộ trình còn trống, chưa thể tạo video');
    },
  );

  blocTest<RoadmapVideoCubit, RoadmapVideoState>(
    'a second tap while rendering does not queue another render',
    build: () {
      when(() => videos.getRoadmapVideo()).thenAnswer((_) async => video);
      return build();
    },
    act: (cubit) async {
      final first = cubit.generate();
      await cubit.generate(); // still loading -> must be a no-op
      await first;
    },
    verify: (_) => verify(() => videos.getRoadmapVideo()).called(1),
  );

  test('initial state is idle with no video', () {
    final cubit = build();
    expect(cubit.state.status, LoadStatus.initial);
    expect(cubit.state.video, isNull);
    cubit.close();
  });
}
