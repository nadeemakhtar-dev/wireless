import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:wireless/services/ConnectionManager.dart';

import 'CharacteristicTile.dart';

class ServiceCard extends StatelessWidget {
  const ServiceCard({required this.deviceId, required this.service, required this.ble});
  final String deviceId;
  final DiscoveredService service;
  final ConnectionManager ble;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service: ${service.serviceId}', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...service.characteristics.map((c) => CharacteristicTile(deviceId: deviceId, serviceId: service.serviceId, ch: c, ble: ble)),
          ],
        ),
      ),
    );
  }
}