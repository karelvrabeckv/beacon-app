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
  Map<String, double> beaconsFound = {};
  MapEntry<String, double>? nearestBeacon;

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

      for (final beacon in beacons) {
        var targetBeacon = Region(
          identifier: beacon.id.toString(),
          proximityUUID: beacon.uuid,
          major: beacon.major,
          minor: beacon.minor,
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
            _updateBeaconsFound(result.beacons);
            _updateNearestBeacon();

            if (kDebugMode) {
              print('\x1B[32mBEACONS FOUND\x1B[0m ${DateTime.now()}');
              beaconsFound.forEach((key, value) => print('${key} ${value}m'));
            }
          }
      });
    }
  }

  void _updateBeaconsFound(List<Beacon> beacons) {
    for (final beacon in beacons) {
      beaconsFound[beacon.macAddress!] = beacon.accuracy;
    }
  }

  void _updateNearestBeacon() {
    var previousMacAddress = nearestBeacon?.key;

    setState(() {
      nearestBeacon = beaconsFound.entries.reduce((current, next) =>
        current.value < next.value ? current : next
      );
    });

    var currentMacAddress = nearestBeacon?.key;

    if (previousMacAddress != currentMacAddress) {
      // The nearest beacon has changed
      _checkPresence(currentMacAddress);
    }
  }

  Future<void> _checkPresence(String? checkedMacAddress) async {
    try {
      await Future.delayed(Duration(seconds: 5));
      _checkBeacon(1, checkedMacAddress);

      await Future.delayed(Duration(seconds: 5));
      _checkBeacon(2, checkedMacAddress);

      await Future.delayed(Duration(seconds: 5));
      _checkBeacon(3, checkedMacAddress);
    } on Exception catch (e) {
      print('\x1B[33m$e\x1B[33m');
    }
  }

  void _checkBeacon(int step, String? checkedMacAddress) {
    var currentMacAddress = nearestBeacon?.key;

    if (currentMacAddress != checkedMacAddress) {
      throw Exception('NEAREST BEACON CHANGED AGAIN');
    }
    
    print('\x1B[33mPRESENCE CHECKED $step/3\x1B[33m $checkedMacAddress');
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
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: const Text('All beacons:'),
            ),
            for (final key in beaconsFound.keys)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Text('${key} ${beaconsFound[key]}m'),
                )
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: const Text('The nearest beacon:'),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Text(
                  '${nearestBeacon?.key.toString() ?? ''}'
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
