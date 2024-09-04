import 'dart:async';

import 'package:beacon_scanner/constants.dart';
import 'package:beacon_scanner/db.dart';
import 'package:beacon_scanner/detected_beacon.dart';
import 'package:beacon_scanner/models/attendance.dart';
import 'package:beacon_scanner/models/classroom.dart';
import 'package:beacon_scanner/models/student.dart';
import 'package:beacon_scanner/models/target_beacon.dart';

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

  List<String> _checksLog = [];
  List<String> _attendanceLog = [];

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await Db.connect();
      await Db.initialize();

      await _getTargetBeacons();
      await _startScanning();
    } on Exception catch (e) {
      if (kDebugMode) {
        print('\x1B[31m$e\x1B[31m');
      }
    }
  }

  Future<void> _getTargetBeacons() async {
    final beacons = await Db.getTargetBeacons();
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
        _checkAttendance(_nearestBeaconMac, nearestBeacon);
      }
    }
  }

  Future<void> _checkAttendance(String checkedMacAddress, DetectedBeacon checkedBeacon) async {
    try {
      for (var i = 0; i < numOfChecks; i++) {
        _checkBeacon(i + 1, checkedMacAddress, checkedBeacon);

        if (i < numOfChecks - 1) {
          await Future.delayed(const Duration(seconds: timeStep));
        }
      }

      List<Attendance> attendances = await _recordAttendance(checkedMacAddress);
      _logAttendance(attendances);
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
    _logCheck(step, checkedMacAddress);
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

  void _logCheck(int step, String checkedMacAddress) {
    String record = 'CHECK $step/5 $checkedMacAddress';
    if (kDebugMode) {
      print('\x1B[33m$record\x1B[33m');
    }

    setState(() => _checksLog = [..._checksLog, record]);
  }

  void _logAttendance(List<Attendance> attendances) {
    List<String> log = [];

    for (final attendance in attendances) {
      log.add(attendance.toString());
    }

    if (kDebugMode) {
      print('\x1B[33m$log\x1B[33m');
    }

    setState(() => _attendanceLog = [...log]);
  }

  Future<List<Attendance>> _recordAttendance(String macAddress) async {
    String sm_number = await Future.delayed(
      const Duration(milliseconds: 250),
      () => 'kvrabec',
    );

    Student student = await Db.getStudentBySmNumber(sm_number);
    TargetBeacon targetBeacon = await Db.getTargetBeaconByMacAddress(macAddress);
    Classroom classroom = await Db.getClassroomByTargetBeaconId(targetBeacon.id!);

    await Db.postAttendance(
      Attendance(
        student_id: student.id!,
        classroom_id: classroom.id!,
        date_time: DateTime.now().toString(),
      )
    );

    List<Attendance> attendances = await Db.getAttendanceByStudentId(student.id!);

    return attendances;
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
                itemCount: _checksLog.length,
                itemBuilder: (BuildContext context, int index) {
                  return Center(child: Text(_checksLog[index]));
                }
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _attendanceLog.length,
                itemBuilder: (BuildContext context, int index) {
                  return Center(child: Text(_attendanceLog[index]));
                }
              ),
            ),
          ],
        ),
      ),
    );
  }
}
