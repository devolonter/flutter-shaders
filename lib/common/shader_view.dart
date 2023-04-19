import 'dart:ui';

import 'package:flutter/material.dart';

class ShaderPainter extends CustomPainter {
  ShaderPainter({
    required this.shader,
  });

  final FragmentShader shader;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(ShaderPainter oldDelegate) => false;
}

class ShaderView extends StatefulWidget {
  const ShaderView({Key? key, required this.shader}) : super(key: key);

  final String shader;

  @override
  State<ShaderView> createState() => _ShaderViewState();
}

class _ShaderViewState extends State<ShaderView> {
  late Future<FragmentProgram> loader;

  @override
  void initState() {
    super.initState();
    loader = FragmentProgram.fromAsset("shaders/${widget.shader}.frag");
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FragmentProgram>(
      future: loader,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return CustomPaint(
            painter: ShaderPainter(shader: snapshot.data!.fragmentShader()),
          );
        } else {
          if (snapshot.hasError) {
            print(snapshot.error);
          }
          
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }
}
