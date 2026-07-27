import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:munich_ways/ui/theme.dart';

/// Branded hand-off between the native launch screen and the interactive map.
class MapInitialLoadingOverlay extends StatefulWidget {
  const MapInitialLoadingOverlay({super.key, required this.message});

  final String message;

  @override
  State<MapInitialLoadingOverlay> createState() =>
      _MapInitialLoadingOverlayState();
}

class _MapInitialLoadingOverlayState extends State<MapInitialLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return IgnorePointer(
      child: Semantics(
        label: widget.message,
        liveRegion: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Align(
              alignment: Alignment.topCenter,
              child: FractionallySizedBox(
                heightFactor: .56,
                widthFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F9FD).withValues(alpha: .84),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A276A9F),
                        blurRadius: 24,
                        offset: Offset(0, 9),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Stack(
                      children: [
                        const Positioned(
                          top: -110,
                          right: -90,
                          child: _DecorativeCircle(size: 250, opacity: .1),
                        ),
                        const Positioned(
                          bottom: -155,
                          left: -105,
                          child: _DecorativeCircle(size: 270, opacity: .06),
                        ),
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
                            child: AnimatedBuilder(
                              animation: _controller,
                              builder: (context, child) {
                                final progress =
                                    reduceMotion ? .35 : _controller.value;
                                final wave =
                                    math.sin(progress * math.pi * 2);
                                final scale =
                                    reduceMotion ? 1.0 : 1 + wave * .018;
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Transform.scale(
                                      scale: scale,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 22,
                                          vertical: 19,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: .9,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(21),
                                          boxShadow: const [
                                            BoxShadow(
                                              color: Color(0x18276A9F),
                                              blurRadius: 26,
                                              offset: Offset(0, 9),
                                            ),
                                          ],
                                        ),
                                        child: Image.asset(
                                          'images/logo_long.png',
                                          width: 210,
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      widget.message,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Color(0xFF28475F),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _LoadingTrack(progress: progress),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DecorativeCircle extends StatelessWidget {
  const _DecorativeCircle({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.munichWaysBlue.withValues(alpha: opacity),
        ),
      );
}

class _LoadingTrack extends StatelessWidget {
  const _LoadingTrack({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 150,
        height: 5,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const indicatorWidth = 48.0;
              final travel = constraints.maxWidth + indicatorWidth;
              return ColoredBox(
                color: AppColors.munichWaysBlue.withValues(alpha: .18),
                child: Transform.translate(
                  offset: Offset(progress * travel - indicatorWidth, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      width: indicatorWidth,
                      decoration: BoxDecoration(
                        color: AppColors.munichWaysBlue,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
}

/// Small non-blocking status used when ratings are refreshed later.
class MapReloadingBanner extends StatelessWidget {
  const MapReloadingBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: IgnorePointer(
          child: Center(
            heightFactor: 1,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Material(
                color: const Color(0xF7FFFFFF),
                elevation: 5,
                shadowColor: const Color(0x33276A9F),
                borderRadius: BorderRadius.circular(18),
                child: Semantics(
                  label: message,
                  liveRegion: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 13,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: AppColors.munichWaysBlue,
                          ),
                        ),
                        const SizedBox(width: 13),
                        Flexible(
                          child: Text(
                            message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF28475F),
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
