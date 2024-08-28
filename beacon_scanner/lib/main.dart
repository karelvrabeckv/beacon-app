import 'dart:async';

import 'package:beacon_scanner/constants.dart';
import 'package:beacon_scanner/db.dart';
import 'package:beacon_scanner/detected_beacon.dart';

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
  List<Region> _targetBeacons = [];
  Map<String, DetectedBeacon> _detectedBeacons = {};

  String _nearestBeaconMac = '';

  List<String> _presenceLog = [];

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _getTargetBeacons();
      await _startScanning();
    } on Exception catch (e) {
      if (kDebugMode) {
        print('\x1B[31m$e\x1B[31m');
      }
    }
  }

  Future<void> _getTargetBeacons() async {
    await Db.connect();
    await Db.postBeacons();

    final beacons = await Db.getBeacons();
    if (beacons.isEmpty) {
      throw Exception('NO TARGET BEACONS');
    }
    
    for (final beacon in beacons) {
      var targetBeacon = Region(
        identifier: beacon.id.toString(),
        proximityUUID: beacon.uuid,
        major: beacon.major,
        minor: beacon.minor,
      );
      _targetBeacons.add(targetBeacon);
    }
  }

  Future<void> _startScanning() async {
    await Permission.bluetoothConnect.request();
    await Permission.bluetoothScan.request();
    await Permission.location.request();

    flutterBeacon
      .ranging(_targetBeacons)
      .listen((result) {
        if (result.beacons.isNotEmpty) {
          _updateDetectedBeacons(result.beacons);
          _updateNearestBeacon();

          if (kDebugMode) {
            print('\x1B[32mBEACONS UPDATED\x1B[0m ${DateTime.now()}');
          }
        }
    });
  }

  void _updateDetectedBeacons(List<Beacon> beacons) {
    for (final beacon in beacons) {
      String macAddress = beacon.macAddress ?? '';
      double distance = beacon.accuracy;
      
      if (_detectedBeacons.containsKey(macAddress)) {
        _detectedBeacons[macAddress]!.distance = distance;
      } else {
        DetectedBeacon newDetectedBeacon = DetectedBeacon(distance: distance);
        _detectedBeacons[macAddress] = newDetectedBeacon;
      }
    }
  }

  void _updateNearestBeacon() {
    String previousMacAddress = _nearestBeaconMac;

    setState(() {
      _nearestBeaconMac = _detectedBeacons.entries.reduce((current, next) =>
        current.value.distance < next.value.distance ? current : next
      ).key;
    });

    String currentMacAddress = _nearestBeaconMac;

    if (previousMacAddress != currentMacAddress) {
      DetectedBeacon nearestBeacon = _detectedBeacons[_nearestBeaconMac]!;

      if (nearestBeacon.isCheck == false) {
        nearestBeacon.isCheck = true;
        _checkPresence(_nearestBeaconMac, nearestBeacon);
      }
    }
  }

  Future<void> _checkPresence(String checkedMacAddress, DetectedBeacon checkedBeacon) async {
    try {
      for (var i = 0; i < 5; i++) {
        _checkBeacon(i + 1, checkedMacAddress, checkedBeacon);
        await Future.delayed(const Duration(seconds: timeStep));
      }
    } on Exception catch (e) {
      if (kDebugMode) {
        print('\x1B[31m$e\x1B[31m');
      }
    } finally {
      checkedBeacon.isCheck = false;
    }
  }

  void _checkBeacon(int step, String checkedMacAddress, DetectedBeacon checkedBeacon) {
    _checkBeaconDistance(checkedBeacon);
    _checkNearestBeacon(checkedMacAddress, checkedBeacon);
    _logPresence(step, checkedMacAddress);
  }

  void _checkBeaconDistance(DetectedBeacon checkedBeacon) {
    if (checkedBeacon.distance < maxDistance) {
      checkedBeacon.lastTimeWhenInScope = DateTime.now();
    } else {
      DateTime now = DateTime.now();
      Duration period = now.difference(checkedBeacon.lastTimeWhenInScope);
      int periodInSeconds = period.inSeconds % 60;

      if (periodInSeconds > timeStep) {
        throw Exception('CHECKS TERMINATED: Checked beacon is out of scope for long time');
      }
    }
  }

  void _checkNearestBeacon(String checkedMacAddress, DetectedBeacon checkedBeacon) {
    if (checkedMacAddress == _nearestBeaconMac) {
      checkedBeacon.lastTimeWhenNearest = DateTime.now();
    } else {
      DateTime now = DateTime.now();
      Duration period = now.difference(checkedBeacon.lastTimeWhenNearest);
      int periodInSeconds = period.inSeconds % 60;

      if (periodInSeconds > timeStep) {
        throw Exception('CHECKS TERMINATED: Checked beacon is not nearest for long time');
      }
    }
  }

  void _logPresence(int step, String checkedMacAddress) {
    String record = 'PRESENCE $step/5 $checkedMacAddress';
    if (kDebugMode) {
      print('\x1B[33m$record\x1B[33m');
    }

    setState(() => _presenceLog = [..._presenceLog, record]);
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
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('All beacons:'),
            ),
            for (final beacon in _detectedBeacons.entries)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Text('${beacon.key} ${beacon.value.distance}m'),
                )
              ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('The nearest beacon:'),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Text(_nearestBeaconMac.toString()),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _presenceLog.length,
                itemBuilder: (BuildContext context, int index) {
                  return Center(child: Text(_presenceLog[index]));
                }
              ),
            ),
          ],
        ),
      ),
    );
  }
}
