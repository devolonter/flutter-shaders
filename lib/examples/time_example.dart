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
    return const ShaderView(
        shaderName: 'time',
        timeUniform: 0,
    );
  }
}
