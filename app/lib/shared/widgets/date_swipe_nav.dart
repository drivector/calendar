import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Wraps [child] with two ways to step forward/back through whatever
/// [onPrevious]/[onNext] represent — a touch swipe (drag) and a trackpad
/// horizontal scroll. Used both for date/week navigation (Day, Week) and,
/// on screens with no competing horizontal gesture (Goals, Log activity),
/// for stepping between tabs — never both on the same screen, since two
/// nested instances would fight over the same swipe. Arrow *buttons* are a
/// separate, explicit affordance (see [StepArrowButton]) — this widget only
/// covers the gestural paths.
class DateSwipeNav extends StatefulWidget {
  const DateSwipeNav({
    super.key,
    required this.onPrevious,
    required this.onNext,
    required this.child,
  });

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final Widget child;

  @override
  State<DateSwipeNav> createState() => _DateSwipeNavState();
}

class _DateSwipeNavState extends State<DateSwipeNav> {
  // Trackpad delivers a continuous stream of small scroll events for one
  // physical swipe, not a single gesture with a start/end like touch drag —
  // so a step is triggered once the accumulated delta crosses a threshold,
  // then further triggers are locked out until the stream goes quiet for
  // [_cooldown], which reads as "one swipe, one step".
  static const _triggerThreshold = 60.0;
  static const _cooldown = Duration(milliseconds: 250);

  double _accumulated = 0;
  Timer? _quietTimer;
  bool _locked = false;

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final delta = event.scrollDelta;
    // A predominantly-vertical scroll (mouse wheel, or scrolling page
    // content) isn't a navigation gesture — only react to a clearly
    // horizontal one.
    if (delta.dx.abs() <= delta.dy.abs()) return;

    _quietTimer?.cancel();
    _quietTimer = Timer(_cooldown, () {
      _accumulated = 0;
      _locked = false;
    });

    if (_locked) return;
    _accumulated += delta.dx;
    if (_accumulated.abs() < _triggerThreshold) return;

    _locked = true;
    // Positive dx == content scrolls further right, the same direction a
    // left-to-right touch drag with negative velocity produces below — both
    // read as "advance forward in time". Flip this if it feels backwards on
    // a real trackpad; direction couldn't be confirmed against real
    // hardware in this environment.
    if (_accumulated > 0) {
      widget.onNext();
    } else {
      widget.onPrevious();
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity == 0) return;
    if (velocity < 0) {
      widget.onNext();
    } else {
      widget.onPrevious();
    }
  }

  @override
  void dispose() {
    _quietTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: GestureDetector(
        onHorizontalDragEnd: _onHorizontalDragEnd,
        child: widget.child,
      ),
    );
  }
}
