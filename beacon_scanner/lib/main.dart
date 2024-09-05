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
      String mac = beacon.macAddress ?? '';
      double distance = beacon.accuracy;

      if (_detectedBeacons.containsKey(mac)) {
        _detectedBeacons[mac]!.distance = distance;
      } else {
        DetectedBeacon newDetectedBeacon = DetectedBeacon(distance: distance);
        _detectedBeacons[mac] = newDetectedBeacon;
      }
    }
  }

  void _updateNearestBeacon() {
    setState(() {
      _nearestBeaconMac = _detectedBeacons.entries.reduce((current, next) =>
        current.value.distance < next.value.distance ? current : next
      ).key;
    });

    DetectedBeacon nearestBeacon = _detectedBeacons[_nearestBeaconMac]!;

    if (nearestBeacon.isCheck == false) {
      nearestBeacon.isCheck = true;
      _checkAttendance(_nearestBeaconMac, nearestBeacon);
    }
  }

  Future<void> _checkAttendance(String checkedMac, DetectedBeacon checkedBeacon) async {
    try {
      for (var currCheckCycle = 0; currCheckCycle < numOfCheckCycles; currCheckCycle++) {
        for (var currCheck = 0; currCheck < numOfChecks; currCheck++) {
          _checkBeacon(currCheck + 1, checkedMac, checkedBeacon);

          if (currCheck < numOfChecks - 1) {
            await Future.delayed(const Duration(seconds: timeStep));
          }
        }

        final (student, classroom, attendance) = await _recordAttendance(checkedMac);
        _logAttendance(student, classroom, attendance);

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

  void _checkBeacon(int step, String checkedMac, DetectedBeacon checkedBeacon) {
    _checkBeaconDistance(checkedBeacon);
    _checkNearestBeacon(checkedMac, checkedBeacon);
    _logCheck(step, checkedMac);
  }

  void _checkBeaconDistance(DetectedBeacon checkedBeacon) {
    if (checkedBeacon.distance < maxDistance) {
      checkedBeacon.lastTimeWhenInScope = DateTime.now();
    } else {
      DateTime now = DateTime.now();
      Duration period = now.difference(checkedBeacon.lastTimeWhenInScope);

      if (period.inSeconds > timeStep) {
        throw Exception('CHECKS TERMINATED: Checked beacon is out of scope for long time');
      }
    }
  }

  void _checkNearestBeacon(String checkedMac, DetectedBeacon checkedBeacon) {
    if (checkedMac == _nearestBeaconMac) {
      checkedBeacon.lastTimeWhenNearest = DateTime.now();
    } else {
      DateTime now = DateTime.now();
      Duration period = now.difference(checkedBeacon.lastTimeWhenNearest);

      if (period.inSeconds > timeStep) {
        throw Exception('CHECKS TERMINATED: Checked beacon is not nearest for long time');
      }
    }
  }

  void _logCheck(int step, String checkedMac) {
    String record = 'CHECK $step/$numOfChecks $checkedMac';
    if (kDebugMode) {
      print('\x1B[33m$record\x1B[33m');
    }

    setState(() => _checksLog = [..._checksLog, record]);
  }

  void _logAttendance(Student student, Classroom classroom, Attendance attendance) {
    String record = 'ATTENDANCE ${student.sm_number}, ${classroom.label}, ${attendance.date_time}';
    if (kDebugMode) {
      print('\x1B[33m$record\x1B[33m');
    }

    setState(() => _attendanceLog = [..._attendanceLog, record]);
  }

  Future<(Student, Classroom, Attendance)> _recordAttendance(String mac) async {
    String sm_number = await Future.delayed(
      const Duration(milliseconds: 250),
      () => 'kvrabec',
    );

    Student student = await Db.getStudentBySmNumber(sm_number);
    TargetBeacon targetBeacon = await Db.getTargetBeaconByMac(mac);
    Classroom classroom = await Db.getClassroomByTargetBeaconId(targetBeacon.id!);

    await Db.postAttendance(
      Attendance(
        student_id: student.id!,
        classroom_id: classroom.id!,
        date_time: DateTime.now().toString(),
      )
    );

    List<Attendance> attendances = await Db.getAttendancesByStudentId(student.id!);

    return (student, classroom, attendances.last);
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
