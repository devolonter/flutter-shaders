import 'package:flutter/material.dart';
import 'package:flutter_shaders/common/shader_container.dart';

class HelloExample extends StatelessWidget {
  const HelloExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const ShaderContainer(
        shaderName: 'hello'
    );
  }
}
