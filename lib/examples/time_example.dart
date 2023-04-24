import 'package:flutter/material.dart';
import 'package:flutter_shaders/common/shader_view.dart';

class TimeExample extends StatelessWidget {
  const TimeExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.0
      ),
      itemCount: 10,
      padding: EdgeInsets.zero,
      itemBuilder: (context, index) {
        return ShaderView(
            shaderName: 'time',
            onShaderLoaded: (setUniform) {
              setUniform('uShift', -index / 10.0);
            }
        );
      },
    );
  }
}
