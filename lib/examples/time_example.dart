import 'package:flutter/material.dart';
import 'package:flutter_shaders/common/shader_view.dart';

class TimeExample extends StatefulWidget {
  const TimeExample({Key? key}) : super(key: key);

  @override
  State<TimeExample> createState() => _TimeExampleState();
}

class _TimeExampleState extends State<TimeExample> {

  @override
  void initState() {
    super.initState();
  }

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
              setUniform('uOffset', index / 10.0);
            }
          );
        },
    );
  }
}
