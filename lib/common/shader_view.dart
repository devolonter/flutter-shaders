import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

class ShaderPainter extends CustomPainter {
  late final Paint _paint;

  ShaderPainter({
    required FragmentShader shader,
    Listenable? repaint,
  }) : super(repaint: repaint) {
    _paint = Paint()..shader = shader;
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, _paint);
  }

  @override
  bool shouldRepaint(ShaderPainter oldDelegate) => false;
}

class ShaderView extends StatefulWidget {
  final String shaderName;
  final int? timeUniform;

  const ShaderView({Key? key, required this.shaderName, this.timeUniform})
      : super(key: key);

  @override
  State<ShaderView> createState() => _ShaderViewState();
}

class _ShaderViewState extends State<ShaderView>
    with SingleTickerProviderStateMixin {
  late final Future<FragmentProgram> _loader;

  FragmentShader? _shader;
  ValueNotifier<double>? _time;
  Ticker? _ticker;

  @override
  void initState() {
    super.initState();
    _loader = FragmentProgram.fromAsset("shaders/${widget.shaderName}.frag");

    if (widget.timeUniform != null) {
      _time = ValueNotifier(0.0);
      _ticker = createTicker((elapsed) {
        final double elapsedSeconds = elapsed.inMilliseconds / 1000;
        _shader?.setFloat(0, elapsedSeconds);
        _time?.value = elapsedSeconds;
      });
      _ticker!.start();
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FragmentProgram>(
      future: _loader,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          _shader = snapshot.data!.fragmentShader();

          return CustomPaint(
              painter: ShaderPainter(shader: _shader!, repaint: _time));
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
