import 'dart:ui';

import 'package:flutter/material.dart';

class ShaderPainter extends CustomPainter {
  final FragmentShader shader;
  final Paint _paint;

  ShaderPainter({
    required this.shader,
  }): _paint = Paint()..shader = shader;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, _paint);
  }

  @override
  bool shouldRepaint(ShaderPainter oldDelegate) => false;
}

class ShaderView extends StatefulWidget {
  const ShaderView({Key? key, required this.shaderName}) : super(key: key);

  final String shaderName;

  @override
  State<ShaderView> createState() => _ShaderViewState();
}

class _ShaderViewState extends State<ShaderView> {
  late Future<FragmentProgram> loader;

  @override
  void initState() {
    super.initState();
    loader = FragmentProgram.fromAsset("shaders/${widget.shaderName}.frag");
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
