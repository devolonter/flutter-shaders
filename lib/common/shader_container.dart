import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

typedef UniformSetter = void Function(String uniformName, dynamic value);
typedef _PaintCallback = void Function(Canvas canvas, Size size);

class ShaderContainer extends StatefulWidget {
  final String shader;
  final String timeUniform;
  final String sizeUniform;
  final Function(UniformSetter)? onShaderLoaded;
  final bool debug;
  final bool active;
  final Widget? child;

  const ShaderContainer(
      {Key? key,
      required this.shader,
      this.timeUniform = 'uTime',
      this.sizeUniform = 'uSize',
      this.debug = false,
      this.active = true,
      this.onShaderLoaded,
      this.child})
      : super(key: key);

  @override
  State<ShaderContainer> createState() => _ShaderContainerState();
}

class _ShaderContainerState extends State<ShaderContainer>
    with SingleTickerProviderStateMixin {
  Future<FragmentShader>? _loader;
  final Map<String, _Uniform> _uniforms = {};

  FragmentShader? _shader;
  ValueNotifier<double>? _time;
  Ticker? _ticker;

  String? _shaderPath;

  @override
  void initState() {
    super.initState();
    _loader = _loadShader();
  }

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ShaderContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _updateTickerState();
    }

    if (!widget.debug) {
      return;
    }

    if (oldWidget.shader != widget.shader) {
      _shaderPath = null;
    }
    _loader = _loadShader();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FragmentShader>(
      future: _loader,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return CustomPaint(
              painter: _ShaderPainter(
                  shader: snapshot.data!,
                  repaint: _time,
                  onPaint: _getPaintCallback()),
              child: widget.child);
        } else {
          if (snapshot.hasError) {
            throw snapshot.error!;
          }

          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  Future<void> _detectShaderPath() async {
    final List<String> shaderNames = [
      widget.shader,
      'shaders/${widget.shader}.frag',
      '${widget.shader}.frag',
    ];

    for (final shaderName in shaderNames) {
      try {
        await rootBundle.load(shaderName);
        _shaderPath = shaderName;
        break;
      } catch (e) {
        continue;
      }
    }

    if (_shaderPath == null) {
      throw Exception('Shader "${widget.shader}" not found');
    }
  }

  Future<FragmentShader> _loadShader() async {
    if (_shaderPath == null) {
      await _detectShaderPath();
    }

    try {
      final FragmentProgram program =
          await FragmentProgram.fromAsset(_shaderPath!);
      await _getUniforms();
      final timeUniform = _uniforms[widget.timeUniform];

      if (timeUniform != null && _ticker == null) {
        _createTicker(timeUniform);
      }

      _shader = program.fragmentShader();
      final Iterable<_Uniform> images = _uniforms.values
          .where((uniform) => uniform.type == _UniformType.image);

      if (images.isNotEmpty) {
        await _setupSamplers(images);
      }

      widget.onShaderLoaded?.call(_setUniform);
      return _shader!;
    } catch (e) {
      rethrow;
    }
  }

  _setUniform(uniformName, value) {
    final uniform = _uniforms[uniformName];
    if (uniform == null) {
      throw Exception('Uniform $uniformName not found');
    }

    if (uniform.type == _UniformType.image) {
      if (value is String) {
        _loadImage(value).then((image) {
          if (image == null) {
            throw Exception('Image $value not found');
          }
          _shader?.setImageSampler(uniform.index, image);
        });

        return;
      }
      _shader?.setImageSampler(uniform.index, value);
      return;
    }

    List<double> val = List.filled(uniform.size, 0, growable: false);

    if ((value.runtimeType == List<double>) && value.length == uniform.size) {
      for (int i = 0; i < val.length; i++) {
        _shader?.setFloat(uniform.index + i, value[i]);
      }

      return;
    }

    switch (uniform.size) {
      case 1:
        val[0] = value as double;
        break;
      case 2:
        switch (value.runtimeType) {
          case Offset:
            final offset = value as Offset;
            val[0] = offset.dx;
            val[1] = offset.dy;
            break;
          case Size:
            final size = value as Size;
            val[0] = size.width;
            val[1] = size.height;
            break;
          case Point:
            final point = value as Point;
            val[0] = point.x.toDouble();
            val[1] = point.y.toDouble();
            break;
        }
        break;
      case 3:
        switch (value.runtimeType) {
          case Color:
            final color = value as Color;
            val[0] = color.red / 255;
            val[1] = color.green / 255;
            val[2] = color.blue / 255;
            break;
          case int:
            final color = value as int;
            val[0] = (color >> 16 & 0xFF) / 255;
            val[1] = (color >> 8 & 0xFF) / 255;
            val[2] = (color & 0xFF) / 255;
            break;
        }
        break;
      case 4:
        switch (value.runtimeType) {
          case Color:
            final color = value as Color;
            val[0] = color.red / 255;
            val[1] = color.green / 255;
            val[2] = color.blue / 255;
            val[3] = color.alpha / 255;
            break;
          case int:
            final color = value as int;
            val[0] = (color >> 16 & 0xFF) / 255;
            val[1] = (color >> 8 & 0xFF) / 255;
            val[2] = (color & 0xFF) / 255;
            val[3] = (color >> 24 & 0xFF) / 255;
            break;
          case Rectangle:
            final rect = value as Rectangle;
            val[0] = rect.left.toDouble();
            val[1] = rect.top.toDouble();
            val[2] = rect.width.toDouble();
            val[3] = rect.height.toDouble();
            break;
        }
    }

    for (int i = 0; i < val.length; i++) {
      _shader?.setFloat(uniform.index + i, val[i]);
    }
  }

  Future<void> _setupSamplers(Iterable<_Uniform> images) async {
    final Uint8List whitePixel = Uint8List.fromList([255, 255, 255, 255]);
    final Completer<ui.Image> completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(whitePixel.buffer.asUint8List(), 1, 1,
        ui.PixelFormat.rgba8888, (ui.Image img) => completer.complete(img));
    final ui.Image whiteImage = await completer.future;

    for (final image in images) {
      _shader?.setImageSampler(image.index, whiteImage);
    }
  }

  void _createTicker(_Uniform timeUniform) {
    _time = ValueNotifier(0.0);
    _ticker = createTicker((elapsed) {
      final double elapsedSeconds = elapsed.inMilliseconds / 1000;
      _shader?.setFloat(timeUniform.index, elapsedSeconds);
      _time?.value = elapsedSeconds;
    });
    _updateTickerState();
    _ticker!.start();
  }

  Future<int?> _getUniforms() async {
    final Uint8List buffer =
        (await rootBundle.load(_shaderPath!)).buffer.asUint8List();
    final Map<int, int> uniformIndex = {};
    for (final _UniformType type in _UniformType.values) {
      uniformIndex[type.index] = 0;
    }

    int? timeUniform;

    _lookupBuffer(buffer, 0, (start, line) {
      final List<String> split = line.split(RegExp(r"\s+"));

      if (split.length >= 3 && split[0] == 'uniform') {
        if (_uniforms.containsKey(split[2])) {
          return false;
        }

        int? size;
        _UniformType type = _UniformType.float;

        switch (split[1]) {
          case 'float':
            size = 1;
            break;
          case 'vec2':
            size = 2;
            break;
          case 'vec3':
            size = 3;
            break;
          case 'vec4':
            size = 4;
            break;
          case 'shader':
            size = 1;
            type = _UniformType.image;
            break;
        }

        if (size != null) {
          _lookupBuffer(buffer, start, (_, line) {
            final List<String> s = line.split(RegExp(r"(\s+|[-*+/(),])"));

            for (var i = 0; i < s.length; i++) {
              if (s[i] == split[2]) {
                _uniforms[s[i]] =
                    _Uniform(uniformIndex[type.index]!, size!, type);
                uniformIndex[type.index] = uniformIndex[type.index]! + size;

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

  void _lookupBuffer(
      Uint8List buffer, int start, bool Function(int, String) callback) {
    final StringBuffer sb = StringBuffer();

    for (var i = start; i < buffer.length; i++) {
      if (buffer[i] >= 32 && buffer[i] <= 126 && buffer[i] != 59) {
        sb.write(String.fromCharCode(buffer[i]));
      } else if (buffer[i] == 59) {
        if (sb.length == 0) {
          continue;
        }

        if (callback(i, sb.toString().replaceAll('\\n', ''))) {
          return;
        }

        sb.clear();
      }
    }
  }

  Future<ui.Image?> _loadImage(String image) async {
    final Completer<ui.Image> completer = Completer<ui.Image>();
    final ByteData data = await rootBundle.load(image);
    ui.decodeImageFromList(Uint8List.view(data.buffer), (ui.Image img) {
      completer.complete(img);
    });
    return completer.future;
  }

  void _updateTickerState() {
    _ticker?.muted = !widget.active;
  }

  _PaintCallback? _getPaintCallback() {
    final _Uniform? sizeUniform = _uniforms[widget.sizeUniform];

    if (sizeUniform != null) {
      return (canvas, size) {
        _shader?.setFloat(sizeUniform.index, size.width);
        _shader?.setFloat(sizeUniform.index + 1, size.height);
      };
    } else {
      return null;
    }
  }
}

enum _UniformType { float, image }

class _Uniform {
  final int index;
  final int size;
  final _UniformType type;

  _Uniform(this.index, this.size, this.type);
}

class _ShaderPainter extends CustomPainter {
  late final Paint _paint;
  late final _PaintCallback? onPaint;

  _ShaderPainter({
    required FragmentShader shader,
    this.onPaint,
    Listenable? repaint,
  }) : super(repaint: repaint) {
    _paint = Paint()..shader = shader;
  }

  @override
  void paint(Canvas canvas, Size size) {
    onPaint?.call(canvas, size);
    canvas.drawRect(Offset.zero & size, _paint);
  }

  @override
  bool shouldRepaint(_ShaderPainter oldDelegate) => false;
}
