import 'package:flutter/material.dart';

class DeviceDetailPage extends StatelessWidget {
  final String deviceId;
  const DeviceDetailPage({super.key, required this.deviceId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Device $deviceId')),
      body: Center(child: Text('Device Detail: $deviceId')),
    );
  }
}
