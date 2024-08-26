import 'dart:async';

import 'package:beacon_scanner/constants.dart';
import 'package:beacon_scanner/db.dart';

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
  Map<String, bool> beaconsChecks = {};
  MapEntry<String, double>? nearestBeacon;
  DateTime? nearestBeaconAge;
  List<String> presenceLog = [];

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  Future<void> _initialize() async {
    await _getTargetBeacons();
    await _startScanning();
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
            _updateBeaconsChecks(result.beacons);
            _updateNearestBeacon();

            if (kDebugMode) {
              print('\x1B[32mBEACONS FOUND\x1B[0m ${DateTime.now()}');
              beaconsFound.forEach((key, value) => print('$key ${value}m'));
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

  void _updateBeaconsChecks(List<Beacon> beacons) {
    for (final beacon in beacons) {
      if (!beaconsChecks.containsKey(beacon.macAddress!)) {
        beaconsChecks[beacon.macAddress!] = false;
      }
    }
  }

  void _updateNearestBeacon() {
    var previousMacAddress = nearestBeacon?.key;

    setState(() {
      nearestBeacon = beaconsFound.entries.reduce((current, next) =>
        current.value < next.value ? current : next
      );
    });

    var currentMacAddress = nearestBeacon!.key;

    if (previousMacAddress != currentMacAddress) {
      // The nearest beacon has changed
      _updateNearestBeaconAge();

      if (beaconsChecks[currentMacAddress] == false) {
        beaconsChecks[currentMacAddress] = true;
        _checkPresence(currentMacAddress);
      }
    }
  }

  void _updateNearestBeaconAge() {
    setState(() {
      nearestBeaconAge = DateTime.now();
    });
  }

  Future<void> _checkPresence(String checkedMacAddress) async {
    try {
      _checkBeacon(1, checkedMacAddress);
      await Future.delayed(const Duration(seconds: TIME_STEP));
      _checkBeacon(2, checkedMacAddress);
      await Future.delayed(const Duration(seconds: TIME_STEP));
      _checkBeacon(3, checkedMacAddress);
      await Future.delayed(const Duration(seconds: TIME_STEP));
      _checkBeacon(4, checkedMacAddress);
      await Future.delayed(const Duration(seconds: TIME_STEP));
      _checkBeacon(5, checkedMacAddress);
    } on Exception catch (e) {
      if (kDebugMode) {
        print('\x1B[33m$e\x1B[33m');
      }
    } finally {
      beaconsChecks[checkedMacAddress] = false;
    }
  }
  void _checkBeacon(int step, String checkedMacAddress) {
    _checkBeaconDistance(checkedMacAddress);
    _checkBeaconChange(checkedMacAddress);
    _logPresence(step, checkedMacAddress);
  }

  void _checkBeaconDistance(String checkedMacAddress) {
    var currentDistance = beaconsFound[checkedMacAddress]!;

    if (currentDistance > MAX_DISTANCE) {
      throw Exception('CHECKED BEACON OUT OF SCOPE');
    }
  }

  void _checkBeaconChange(String checkedMacAddress) {
    var currentMacAddress = nearestBeacon!.key;

    if (currentMacAddress != checkedMacAddress) {
      DateTime now = DateTime.now();
      Duration difference = now.difference(nearestBeaconAge!);
      int differenceInSeconds = difference.inSeconds % 60;

      if (differenceInSeconds > TIME_STEP) {
        throw Exception('NEAREST BEACON CHANGED');
      }
    }
  }

  void _logPresence(int step, String checkedMacAddress) {
    String record = 'PRESENCE $step/5 $checkedMacAddress';
    if (kDebugMode) {
      print('\x1B[33m$record/3\x1B[33m');
    }

    setState(() {
      presenceLog = [...presenceLog, record];
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
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('All beacons:'),
            ),
            for (final key in beaconsFound.keys)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Text('$key ${beaconsFound[key]}m'),
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
                child: Text(nearestBeacon?.key.toString() ?? ''),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: presenceLog.length,
                itemBuilder: (BuildContext context, int index) {
                  return Center(child: Text(presenceLog[index]));
                }
              ),
            ),
          ],
        ),
      ),
    );
  }
}
