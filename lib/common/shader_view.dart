import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

class Uniform {
  final int index;
  final int size;

  Uniform(this.index, this.size);
}

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
  final String timeUniform;
  final Function(Function(String uniformName, dynamic value))? onShaderLoaded;

  const ShaderView(
      {Key? key,
      required this.shaderName,
      this.timeUniform = 'uTime',
      this.onShaderLoaded})
      : super(key: key);

  @override
  State<ShaderView> createState() => _ShaderViewState();
}

class _ShaderViewState extends State<ShaderView>
    with SingleTickerProviderStateMixin {
  Future<FragmentShader>? _loader;
  final Map<String, Uniform> _uniforms = {};

  FragmentShader? _shader;
  ValueNotifier<double>? _time;
  Ticker? _ticker;

  ShaderPainter? _painter;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ShaderView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loader = _loadShader("shaders/${widget.shaderName}.frag");
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FragmentShader>(
      future: _loader,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return CustomPaint(
              painter: ShaderPainter(shader: snapshot.data!, repaint: _time));
        } else {
          if (snapshot.hasError) {
            print(snapshot.error);
          }

          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Future<FragmentShader> _loadShader(String shaderName) async {
    try {
      final FragmentProgram program =
          await FragmentProgram.fromAsset(shaderName);
      await _getUniforms(shaderName);
      final timeUniform = _uniforms[widget.timeUniform];

      if (timeUniform != null && _ticker == null) {
        _time = ValueNotifier(0.0);
        _ticker = createTicker((elapsed) {
          final double elapsedSeconds = elapsed.inMilliseconds / 1000;
          _shader?.setFloat(timeUniform.index, elapsedSeconds);
          _time?.value = elapsedSeconds;
        });
        _ticker!.start();
      }

      _shader = program.fragmentShader();

      widget.onShaderLoaded?.call((uniformName, value) {
        final uniform = _uniforms[uniformName];

        if (uniform != null) {
          switch (uniform.size) {
            case 1:
              _shader?.setFloat(uniform.index, value);
              break;
          }
        }
      });

      return _shader!;
    } catch (e) {
      rethrow;
    }
  }

  Future<int?> _getUniforms(String shaderName) async {
    final Uint8List buffer =
        (await rootBundle.load(shaderName)).buffer.asUint8List();
    int uniformIndex = 0;
    int? timeUniform;

    _lookupBuffer(buffer, 0, (start, split) {
      if (split.length == 3 && split[0] == 'uniform') {
        int? offset;

        switch (split[1]) {
          case 'float':
            offset = 1;
            break;
          case 'vec2':
            offset = 2;
            break;
          case 'vec3':
            offset = 3;
            break;
          case 'vec4':
            offset = 4;
            break;
        }

        if (offset != null) {
          _lookupBuffer(buffer, start, (_, s) {
            for (var i = 0; i < s.length; i++) {
              if (s[i] == split[2]) {
                _uniforms[s[i]] = Uniform(uniformIndex, offset!);
                uniformIndex += offset;
                return true;
              }
            }

            return false;
          });
        }
      }

      return false;
    });

    return timeUniform;
  }

  void _lookupBuffer(Uint8List buffer, int start,
      bool Function(int offset, List<String>) callback) {
    final StringBuffer sb = StringBuffer();

    for (var i = start; i < buffer.length; i++) {
      if (buffer[i] >= 32 && buffer[i] <= 126 && buffer[i] != 59) {
        sb.write(String.fromCharCode(buffer[i]));
      } else if (buffer[i] == 59) {
        if (sb.length == 0) {
          continue;
        }

        final List<String> split = sb.toString().split(RegExp(r"\s+"));
        sb.clear();

        if (callback(i, split)) {
          return;
        }
      }
    }
  }
}
