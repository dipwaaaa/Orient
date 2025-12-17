import 'package:flutter/material.dart';

class AnimatedGradientBackground extends StatefulWidget {
  final Duration duration;
  final double radius;
  final List<Color> colors;
  final Widget? child;

  const AnimatedGradientBackground({
    super.key,
    this.duration = const Duration(seconds: 4),
    this.radius = 1.75,
    this.colors = const [
      Color(0xFFFF6A00),
      Color(0xFFFFE100),
    ],
    this.child,
  });

  @override
  State<AnimatedGradientBackground> createState() => _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState extends State<AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final value = _controller.value;
                final dx = 0.6 * (1 - 2 * value);
                final dy = 0.6 * (2 * value - 1);

                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(dx, dy),
                      radius: widget.radius,
                      colors: widget.colors,
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}