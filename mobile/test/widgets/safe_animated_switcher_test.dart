import 'package:dev_radar_ai/presentation/widgets/common/safe_animated_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _duration = Duration(milliseconds: 250);

/// The feed when a language chip is tapped back and forth on a fast local backend:
/// each state lasts less than the transition, so old children are still fading out.
const _quickFlips = ['loading', 'list', 'loading', 'list'];

/// Pumps [_quickFlips] through [switcher] and returns the Flutter errors it reported.
Future<List<FlutterErrorDetails>> _flipQuickly(
  WidgetTester tester,
  Widget Function(Widget child) switcher,
) async {
  final errors = <FlutterErrorDetails>[];
  final previous = FlutterError.onError;
  FlutterError.onError = errors.add;
  try {
    for (final state in _quickFlips) {
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: switcher(Text(state, key: ValueKey(state))),
      ));
      await tester.pump(const Duration(milliseconds: 30));
    }
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}

void main() {
  testWidgets('plain AnimatedSwitcher reports duplicate keys on quick flips (the bug)', (tester) async {
    final errors = await _flipQuickly(tester, (child) => AnimatedSwitcher(duration: _duration, child: child));
    expect(errors.map((e) => e.exceptionAsString()), contains(contains('Duplicate keys found')));
  });

  testWidgets('SafeAnimatedSwitcher handles quick flips', (tester) async {
    final errors = await _flipQuickly(tester, (child) => SafeAnimatedSwitcher(duration: _duration, child: child));
    expect(errors, isEmpty);

    await tester.pumpAndSettle();
    expect(find.text('list'), findsOneWidget);
    expect(find.text('loading'), findsNothing);
  });

  testWidgets('SafeAnimatedSwitcher does not re-animate a rebuild of the same child', (tester) async {
    Widget build(String text) => Directionality(
          textDirection: TextDirection.ltr,
          child: SafeAnimatedSwitcher(duration: _duration, child: Text(text, key: const ValueKey('list'))),
        );

    await tester.pumpWidget(build('a'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(build('b'));

    // Same key -> updated in place: one child, no cross-fade.
    expect(find.byType(FadeTransition), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
    expect(find.text('a'), findsNothing);
  });
}
