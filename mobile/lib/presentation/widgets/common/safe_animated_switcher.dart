import 'package:flutter/widgets.dart';

/// Drop-in [AnimatedSwitcher] that never fails with "Duplicate keys found".
///
/// AnimatedSwitcher keeps the outgoing child in a Stack while it fades out. When the
/// child flips A -> B -> A faster than [duration] (a fast local backend makes the feed
/// go loading -> list -> loading in under 250 ms when a chip is tapped twice), the new
/// "A" joins the old "A" that is still fading out, and the Stack holds two widgets with
/// the same key.
///
/// Each time the child changes (different key or type, like AnimatedSwitcher itself
/// decides), it is wrapped in a [KeyedSubtree] with a new serial number, so a child
/// that comes back never shares a key with one still on screen. Rebuilds of the same
/// child keep the same serial, so nothing re-animates.
class SafeAnimatedSwitcher extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration? reverseDuration;
  final Curve switchInCurve;
  final Curve switchOutCurve;
  final AnimatedSwitcherTransitionBuilder transitionBuilder;
  final AnimatedSwitcherLayoutBuilder layoutBuilder;

  const SafeAnimatedSwitcher({
    super.key,
    required this.child,
    required this.duration,
    this.reverseDuration,
    this.switchInCurve = Curves.linear,
    this.switchOutCurve = Curves.linear,
    this.transitionBuilder = AnimatedSwitcher.defaultTransitionBuilder,
    this.layoutBuilder = AnimatedSwitcher.defaultLayoutBuilder,
  });

  @override
  State<SafeAnimatedSwitcher> createState() => _SafeAnimatedSwitcherState();
}

class _SafeAnimatedSwitcherState extends State<SafeAnimatedSwitcher> {
  int _serial = 0;

  @override
  void didUpdateWidget(SafeAnimatedSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!Widget.canUpdate(oldWidget.child, widget.child)) _serial++;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: widget.duration,
      reverseDuration: widget.reverseDuration,
      switchInCurve: widget.switchInCurve,
      switchOutCurve: widget.switchOutCurve,
      transitionBuilder: widget.transitionBuilder,
      layoutBuilder: widget.layoutBuilder,
      child: KeyedSubtree(key: ValueKey<int>(_serial), child: widget.child),
    );
  }
}
