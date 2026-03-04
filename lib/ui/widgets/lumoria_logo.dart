import 'package:flutter/material.dart';

class LumoriaLogo extends StatelessWidget {
  final double iconSize;
  final double fontSize;
  final bool showText;

  const LumoriaLogo({
    super.key,
    this.iconSize = 28.0,
    this.fontSize = 20.0,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Vector Icon
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFF00E5FF),
                  Color(0xFF2979FF),
                  Color(0xFFD500F9)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Icon(Icons.description_rounded,
                  size: iconSize, color: Colors.white),
            ),
            Positioned(
              bottom: -(iconSize * 0.1),
              right: -(iconSize * 0.1),
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFFD500F9)],
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                ).createShader(bounds),
                child: Icon(Icons.auto_awesome,
                    size: iconSize * 0.5, color: Colors.white),
              ),
            ),
          ],
        ),
        if (showText) ...[
          SizedBox(width: iconSize * 0.3),
          Text(
            'Lumoria',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: theme.colorScheme.onSurface,
              fontFamily: 'Inter',
            ),
          ),
          SizedBox(width: fontSize * 0.25),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: fontSize * 0.3,
              vertical: fontSize * 0.15,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2979FF), Color(0xFFD500F9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(fontSize * 0.3),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD500F9).withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              'PDF',
              style: TextStyle(
                fontSize: fontSize * 0.45,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: Colors.white,
                fontFamily: 'Inter',
                height: 1.1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
