import 'dart:async';

import 'package:beacon_scanner/auth.dart';
import 'package:beacon_scanner/constants.dart';
import 'package:beacon_scanner/db.dart';
import 'package:beacon_scanner/db/firestore.dart';
import 'package:beacon_scanner/detected_beacon.dart';
import 'package:beacon_scanner/models/attendance.dart';
import 'package:beacon_scanner/models/classroom.dart';
import 'package:beacon_scanner/models/student.dart';
import 'package:beacon_scanner/models/target_beacon.dart';
import 'package:beacon_scanner/pages/login_page.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_beacon/flutter_beacon.dart';

import 'package:icons_plus/icons_plus.dart';
import 'package:intl/intl.dart';

import 'package:permission_handler/permission_handler.dart';

class BeaconScannerPage extends StatefulWidget {
  const BeaconScannerPage({super.key});

  @override
  State<BeaconScannerPage> createState() => _BeaconScannerPageState();
}

class _BeaconScannerPageState extends State<BeaconScannerPage> {
  Firestore _firestoreDB = Firestore();
  
  String _nearestBeaconMac = '';
  List<Region> _targetBeacons = [];
  Map<String, DetectedBeacon> _detectedBeacons = {};
  List<(String, String, String, String)> _attendanceLog = [];

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
    } catch (e) {
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
          _checkBeacon(checkedMac, checkedBeacon);
          checkedBeacon.incrementCurrCheck();

          if (currCheck < numOfChecks - 1) {
            await Future.delayed(const Duration(seconds: timeStep));
          }
        }

        final (student, classroom, attendance) = await _recordAttendance(checkedMac);
        _logAttendance(student, classroom, attendance);

        await Future.delayed(const Duration(seconds: timeStep));
        checkedBeacon.resetCurrCheck();
      }
    } catch (e) {
      if (kDebugMode) {
        print('\x1B[31m$e\x1B[31m');
      }
    } finally {
      checkedBeacon.resetCurrCheck();
      checkedBeacon.isCheck = false;
    }
  }

  void _checkBeacon(String checkedMac, DetectedBeacon checkedBeacon) {
    _checkBeaconDistance(checkedBeacon);
    _checkNearestBeacon(checkedMac, checkedBeacon);
  }

  void _checkBeaconDistance(DetectedBeacon checkedBeacon) {
    if (checkedBeacon.distance < maxDistance) {
      checkedBeacon.lastTimeWhenInScope = DateTime.now();
    } else {
      DateTime now = DateTime.now();
      Duration period = now.difference(checkedBeacon.lastTimeWhenInScope);

      if (period.inSeconds > timeStep) {
        checkedBeacon.resetCurrCheck();
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
        checkedBeacon.resetCurrCheck();
        throw Exception('CHECKS TERMINATED: Checked beacon is not nearest for long time');
      }
    }
  }

  void _logAttendance(Student student, Classroom classroom, Attendance attendance) {
    DateTime dateTime = DateTime.parse(attendance.date_time);
    DateFormat dateFormatter = DateFormat('dd. MM. yy');
    DateFormat timeFormatter = DateFormat('HH:mm');

    (String, String, String, String) record = (
      student.sm_number,
      classroom.label,
      dateFormatter.format(dateTime),
      timeFormatter.format(dateTime),
    );

    setState(() => _attendanceLog = [..._attendanceLog, record]);
  }

  Future<(Student, Classroom, Attendance)> _recordAttendance(String mac) async {
    String sm_number = (Auth.user?.email ?? '').split('@')[0];
    Student student = await Db.getStudentBySmNumber(sm_number);
    TargetBeacon targetBeacon = await Db.getTargetBeaconByMac(mac);
    Classroom classroom = await Db.getClassroomByTargetBeaconId(targetBeacon.id!);

    await _firestoreDB.addAttendance(
      Attendance(
        student_id: student.id!,
        classroom_id: classroom.id!,
        date_time: DateTime.now().toString(),
      )
    );

    List<Attendance> attendance = await _firestoreDB.getAttendanceByStudentId(student.id!);

    return (student, classroom, attendance.last);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: Column(
                    children: <Widget>[
                      const SizedBox(height: 3 * gap),
                      Padding(
                        padding: EdgeInsets.all(2 * gap),
                        child: Text(
                          'Beacons',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      _detectedBeacons.length == 0 ?
                        Text(
                          'There are no beacons.',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        )
                        :
                        Container(
                          child: Column(
                            children: [
                              for (final beacon in _detectedBeacons.entries)
                                Card(
                                  color: beacon.key == _nearestBeaconMac
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : Theme.of(context).colorScheme.surfaceContainerLow,
                                  elevation: 1.0,
                                  margin: EdgeInsets.symmetric(
                                    horizontal: 4 * gap,
                                    vertical: 1 * gap,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2 * gap),
                                    child: ListTile(
                                      leading: Container(
                                        child: Icon(
                                          BoxIcons.bx_bluetooth,
                                          color: Colors.black,
                                          size: 25.0,
                                        ),
                                      ),
                                      title: Container(
                                        padding: EdgeInsets.only(left: 2 * gap),
                                        decoration: new BoxDecoration(
                                            border: new Border(
                                                left: new BorderSide(
                                                  color: Colors.black,
                                                  width: 0.75,
                                                ),
                                            ),
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  'MAC: ',
                                                  style: TextStyle(fontWeight: FontWeight.w600)
                                                ),
                                                Text('${beacon.key}'),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  'Distance: ',
                                                  style: TextStyle(fontWeight: FontWeight.w600)
                                                ),
                                                Text('${beacon.value.distance}m'),
                                              ],
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  'Checks: ',
                                                  style: TextStyle(fontWeight: FontWeight.w600)
                                                ),
                                                Text('${beacon.value.currCheck}/${numOfChecks}'),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                )
                            ],
                          ),
                        ),
                      const SizedBox(height: 3 * gap),
                      Padding(
                        padding: EdgeInsets.all(2 * gap),
                        child: Text(
                          'Attendance',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      _attendanceLog.length == 0 ?
                        Text(
                          'There is no attendance.',
                          style: TextStyle(fontStyle: FontStyle.italic),
                        )
                        :
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4 * gap,
                            vertical: 1 * gap,
                          ),
                          child: Column(
                            children: [
                              for (final attendance in _attendanceLog)
                                Text.rich(
                                  TextSpan(
                                    style: TextStyle(fontStyle: FontStyle.italic),
                                    children: [
                                      TextSpan(text: 'Student '),
                                      TextSpan(
                                        text: '${attendance.$1} ',
                                        style: TextStyle(fontWeight: FontWeight.w600)
                                      ),
                                      TextSpan(text: 'attended '),
                                      TextSpan(
                                        text: '${attendance.$2} ',
                                        style: TextStyle(fontWeight: FontWeight.w600)
                                      ),
                                      TextSpan(text: 'on '),
                                      TextSpan(
                                        text: '${attendance.$3} ',
                                        style: TextStyle(fontWeight: FontWeight.w600)
                                      ),
                                      TextSpan(text: 'at '),
                                      TextSpan(
                                        text: '${attendance.$4}',
                                        style: TextStyle(fontWeight: FontWeight.w600)
                                      ),
                                      TextSpan(text: '.'),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 2 * gap),
                    ],
                  ),
                ),
              ),
            ),
            Divider(
              color: const Color.fromARGB(255, 246, 246, 248),
              height: 0.0,
            ),
            Container(
              padding: const EdgeInsets.all(4 * gap),
              child: Row(
                children: [
                  CircleAvatar(
                    foregroundImage: NetworkImage(Auth.user?.photoURL ?? ''),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2 * gap),
                    child: Text(Auth.user?.displayName ?? ''),
                  ),
                  Spacer(),
                  FilledButton.tonalIcon(
                    icon: const Icon(BoxIcons.bx_log_out),
                    label: Text('Logout'),
                    onPressed: () async {
                      await Auth.signOut();
                          
                      Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (context) => const LoginPage(),
                      ));
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
