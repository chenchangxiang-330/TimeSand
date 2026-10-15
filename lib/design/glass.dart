import 'dart:ui';

import 'package:flutter/material.dart';

/// A bounded glass surface. Blur is opt-in and only used for navigation/hero.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = 28,
    this.blur = false,
    this.tint,
    super.key,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool blur;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final content = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tint ?? const Color(0xC7F6FBFF),
            tint ?? const Color(0x8CE9F4FC),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xCFFFFFFF), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x15234870),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: blur
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: content,
            )
          : content,
    );
  }
}

class ScenicBackground extends StatelessWidget {
  const ScenicBackground({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFA7CBE7), Color(0xFFF8E4CD), Color(0xFF3A92BA)],
            stops: [0, .55, 1],
          ),
        ),
      ),
      Positioned.fill(
        child: ExcludeSemantics(
          child: Image.asset(
            'assets/scenes/coastal-light.png',
            fit: BoxFit.cover,
            alignment: const Alignment(0, .1),
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, error, stackTrace) => const SizedBox.shrink(),
          ),
        ),
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x35FFFFFF), Color(0x08FFFFFF), Color(0x183B739B)],
          ),
        ),
      ),
      child,
    ],
  );
}

class GlassScaffold extends StatelessWidget {
  const GlassScaffold({
    required this.title,
    required this.body,
    this.actions,
    super.key,
  });
  final String title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => ScenicBackground(
    child: Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: actions,
      ),
      body: SafeArea(child: body),
    ),
  );
}
