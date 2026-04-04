// Location: lib/widgets/doodle_background.dart

import 'package:flutter/material.dart';

class CodeDoodleBackground extends StatelessWidget {
  final List<IconData> icons;
  const CodeDoodleBackground({super.key, required this.icons});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ShaderMask(
        shaderCallback: (Rect bounds) => const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFF90CAFF), Color(0xFF0D2137)],
        ).createShader(bounds),
        blendMode: BlendMode.srcATop,
        child: Opacity(
          opacity: 0.1, 
          child: GridView.builder(
            padding: const EdgeInsets.all(15),
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5, mainAxisSpacing: 30, crossAxisSpacing: 30,
            ),
            itemCount: 100,
            itemBuilder: (context, index) => Transform.rotate(
              angle: (index % 2 == 0) ? 0.2 : -0.2,
              child: Icon(icons[index % icons.length], size: 26, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}