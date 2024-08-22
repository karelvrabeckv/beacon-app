import 'dart:async';

import 'package:beacon_app/db.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_beacon/flutter_beacon.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(const BeaconScanner());
}

class BeaconScanner extends StatelessWidget {
  const BeaconScanner({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Beacon Scanner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const BeaconScannerPage(),
    );
  }
}

class BeaconScannerPage extends StatefulWidget {
  const BeaconScannerPage({super.key});

  @override
  State<BeaconScannerPage> createState() => _BeaconScannerPageState();
}

class _BeaconScannerPageState extends State<BeaconScannerPage> {
  List<Region> targetBeacons = [];
  var targetBeacon = const Beacon(
    proximityUUID: "",
    major: 0,
    minor: 0,
    accuracy: 0.0
  );

  @override
  void initState() {
    super.initState();

    _getTargetBeacons();
    _startScanning();
  }

  Future<void> _getTargetBeacons() async {
    try {
      await Db.connect();
      await Db.postBeacons();

      final beacons = await Db.getBeacons();

      for (var i = 0; i < beacons.length; i++) {
        var targetBeacon = Region(
          identifier: 'iBeacon_$i',
          proximityUUID: beacons[i].uuid,
          major: beacons[i].major,
          minor: beacons[i].minor,
        );
        targetBeacons.add(targetBeacon);
      }
    } on Exception catch (e) {
      if (kDebugMode) {
        print('\x1B[31m$e\x1B[31m');
      }
      return;
    }
  }

  Future<void> _startScanning() async {
    try {
      await Permission.location.request();
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();
    } on Exception catch (e) {
      if (kDebugMode) {
        print('\x1B[31m$e\x1B[31m');
      }
      return;
    }

    if (targetBeacons.isNotEmpty) {
      flutterBeacon
        .ranging(targetBeacons)
        .listen((result) {
          if (result.beacons.isNotEmpty) {
            _addBeacon(result.beacons[0]);

            if (kDebugMode) {
              print('\x1B[32mBEACONS FOUND\x1B[0m');
              print(
                'macAddress: ${targetBeacon.macAddress}, '
                'accuracy: ${targetBeacon.accuracy}, '
              );
            }
          } else {
            if (kDebugMode) {
              print('\x1B[31mBEACONS NOT FOUND\x1B[31m');
            }
          }
      });
    }
  }

  void _addBeacon(Beacon beacon) {
    setState(() {
      targetBeacon = beacon;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Beacons'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('macAddress'),
            Text(targetBeacon.macAddress.toString()),
            const SizedBox(height: 12),
            const Text('accuracy'),
            Text(targetBeacon.accuracy.toString()),
          ],
        ),
      ),
    );
  }
}
