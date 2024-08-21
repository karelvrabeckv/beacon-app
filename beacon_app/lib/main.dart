import 'dart:async';

import 'package:beacon_app/db.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  var targetBeacon = const Beacon(proximityUUID: "", major: 0, minor: 0, accuracy: 0.0);

  @override
  void initState() {
    super.initState();

    _getTargetBeacons();

    Future<void> scanning = initBeaconScanning();
    scanning
      .then((value) {
        if (kDebugMode) {
          print('\x1B[32m''SCANNING SUCCESSFULLY INITIATED''\x1B[32m');
        }
      })
      .catchError((error) {
        if (kDebugMode) {
          print('\x1B[31m''ERROR OCCURED WHILE SCANNING''\x1B[31m');
        }
      });
  }

  Future<void> _getTargetBeacons() async {
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
  }

  void _addBeacon(Beacon beacon) {
    setState(() {
      targetBeacon = beacon;
    });
  }

  Future<void> initBeaconScanning() async {
    try {
      await Permission.location.request();
      await Permission.bluetoothScan.request();
      await Permission.bluetoothConnect.request();

      await flutterBeacon.initializeScanning;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('\x1B[31m''$e''\x1B[31m');
      }
      return;
    }

    if (targetBeacons.isNotEmpty) {
      flutterBeacon.ranging(targetBeacons).listen((result) {
        if (result.beacons.isNotEmpty) {
          for (var beacon in result.beacons) {
            _addBeacon(beacon);
          }

          if (kDebugMode) {
            print('\x1B[32m''BEACON FOUND''\x1B[0m');
            print(''
              'proximityUUID: ${targetBeacon.proximityUUID}, '
              'macAddress: ${targetBeacon.macAddress}, '
              'major: ${targetBeacon.major}, '
              'minor: ${targetBeacon.minor}, '
              'rssi: ${targetBeacon.rssi}, '
              'txPower: ${targetBeacon.txPower}, '
              'accuracy: ${targetBeacon.accuracy}, '
              'proximity: ${targetBeacon.proximity}'
            '');
          }
        } else {
            if (kDebugMode) {
              print('\x1B[31m''BEACONS NOT FOUND''\x1B[31m');
            }
        }
      });
    }
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
            const Text('proximityUUID'),
            Text(targetBeacon.proximityUUID),
            const SizedBox(height: 12),
            const Text('macAddress'),
            Text(targetBeacon.macAddress.toString()),
            const SizedBox(height: 12),
            const Text('major'),
            Text(targetBeacon.major.toString()),
            const SizedBox(height: 12),
            const Text('minor'),
            Text(targetBeacon.minor.toString()),
            const SizedBox(height: 12),
            const Text('rssi'),
            Text(targetBeacon.rssi.toString()),
            const SizedBox(height: 12),
            const Text('txPower'),
            Text(targetBeacon.txPower.toString()),
            const SizedBox(height: 12),
            const Text('accuracy'),
            Text(targetBeacon.accuracy.toString()),
            const SizedBox(height: 12),
            const Text('proximity'),
            Text(targetBeacon.proximity.toString()),
          ],
        ),
      ),
    );
  }
}
