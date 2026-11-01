import 'package:dev_radar_ai/presentation/widgets/video/dev_radar_video_player.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DevRadarVideoPlayer builds with loading indicator initially', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: DevRadarVideoPlayer(url: 'http://localhost:8080/dummy.mp4'),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
