import 'package:munich_ways/ui/map/voice_guidance.dart';

/// Lets a rider inspect the map until confirmed movement follows the gesture.
/// Owns no timers or navigation state; the model owns camera-follow intent.
class NavigationCameraFollowGate {
  NavigationCameraFollowGate(
      {this.interactionDelay = const Duration(seconds: 3)});

  final Duration interactionDelay;
  final Set<int> _pointers = {};
  DateTime? _lastInteractionAt;

  bool get interacting => _pointers.isNotEmpty;

  void pointerDown(int pointer, DateTime now) {
    _pointers.add(pointer);
    recordInteraction(now);
  }

  void pointerUp(int pointer, DateTime now) {
    _pointers.remove(pointer);
    recordInteraction(now);
  }

  void recordInteraction(DateTime now) => _lastInteractionAt = now;

  bool shouldResume({
    required DateTime now,
    required DateTime fixTime,
    required NavigationMotionSample motion,
  }) {
    final lastInteraction = _lastInteractionAt;
    return !interacting &&
        lastInteraction != null &&
        now.difference(lastInteraction) >= interactionDelay &&
        fixTime.isAfter(lastInteraction) &&
        !fixTime.isAfter(now) &&
        motion.moving &&
        motion.confirmedMeters > 0;
  }

  void reset() {
    _pointers.clear();
    _lastInteractionAt = null;
  }
}
