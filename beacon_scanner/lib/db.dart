import 'package:beacon_scanner/models/attendance.dart';
import 'package:beacon_scanner/models/classroom.dart';
import 'package:beacon_scanner/models/student.dart';
import 'package:beacon_scanner/models/target_beacon.dart';
import 'package:beacon_scanner/models/target_beacon_to_classroom.dart';

import 'package:flutter/widgets.dart';

import 'package:path/path.dart';

import 'package:sqflite/sqflite.dart';

class Db {
  static Database? db;

  static void _checkDatabase() {
    if (db == null) {
      throw Exception('ERROR: There is no DB');
    }
  }

  static Future<void> connect() async {
    WidgetsFlutterBinding.ensureInitialized();

    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'school.db');

    db = await openDatabase(path, version: 1);
    _checkDatabase();
  }

  static Future<void> initialize() async {
    _checkDatabase();

    await _dropTables();
    await _createTables();
    await _fillTablesWithData();
  }

  static Future<void> _dropTables() async {
    await db!.execute(
      'DROP TABLE IF EXISTS target_beacon'
    );
    await db!.execute(
      'DROP TABLE IF EXISTS classroom'
    );
    await db!.execute(
      'DROP TABLE IF EXISTS target_beacon_to_classroom'
    );
    await db!.execute(
      'DROP TABLE IF EXISTS student'
    );
    await db!.execute(
      'DROP TABLE IF EXISTS attendance'
    );
  }

  static Future<void> _createTables() async {
    await db!.execute(
      'CREATE TABLE target_beacon('
        'id INTEGER PRIMARY KEY AUTOINCREMENT,'
        'mac TEXT,'
        'uuid TEXT,'
        'major INTEGER,'
        'minor INTEGER'
      ')'
    );

    await db!.execute(
      'CREATE TABLE classroom('
        'id INTEGER PRIMARY KEY AUTOINCREMENT,'
        'label TEXT'
      ')'
    );

    await db!.execute(
      'CREATE TABLE target_beacon_to_classroom('
        'id INTEGER PRIMARY KEY AUTOINCREMENT,'
        'target_beacon_id INTEGER,'
        'classroom_id INTEGER,'
        'FOREIGN KEY (target_beacon_id) REFERENCES target_beacon (id),'
        'FOREIGN KEY (classroom_id) REFERENCES classroom (id)'
      ')'
    );

    await db!.execute(
      'CREATE TABLE student('
        'id INTEGER PRIMARY KEY AUTOINCREMENT,'
        'name TEXT,'
        'surname TEXT,'
        'sm_number TEXT'
      ')'
    );

    await db!.execute(
      'CREATE TABLE attendance('
        'id INTEGER PRIMARY KEY AUTOINCREMENT,'
        'student_id INTEGER,'
        'classroom_id INTEGER,'
        'date_time DATETIME,'
        'FOREIGN KEY (student_id) REFERENCES student (id),'
        'FOREIGN KEY (classroom_id) REFERENCES classroom (id)'
      ')'
    );
  }

  static Future<void> _fillTablesWithData() async {
    await postTargetBeacon(
      TargetBeacon(
        mac: 'C3:00:00:2A:A9:13',
        uuid: 'e2c56db5-dffb-48d2-b060-d0f5a71096e0',
        major: 1985,
        minor: 13,
      )
    );

    await postTargetBeacon(
      TargetBeacon(
        mac: 'C3:00:00:2A:A9:14',
        uuid: 'e2c56db5-dffb-48d2-b060-d0f5a71096e0',
        major: 1985,
        minor: 14,
      )
    );

    await postTargetBeacon(
      TargetBeacon(
        mac: 'C3:00:00:2A:A9:15',
        uuid: 'e2c56db5-dffb-48d2-b060-d0f5a71096e0',
        major: 1985,
        minor: 15,
      )
    );

    await postTargetBeacon(
      TargetBeacon(
        mac: 'C3:00:00:2A:A9:16',
        uuid: 'e2c56db5-dffb-48d2-b060-d0f5a71096e0',
        major: 1985,
        minor: 16,
      )
    );

    await postClassroom(
      Classroom(label: 'Creativity Lab')
    );

    await postClassroom(
      Classroom(label: '137')
    );

    await postClassroom(
      Classroom(label: '033')
    );

    await postClassroom(
      Classroom(label: '034')
    );

    await postTargetBeaconToClassroom(
      TargetBeaconToClassroom(target_beacon_id: 1, classroom_id: 1)
    );

    await postTargetBeaconToClassroom(
      TargetBeaconToClassroom(target_beacon_id: 2, classroom_id: 2)
    );

    await postTargetBeaconToClassroom(
      TargetBeaconToClassroom(target_beacon_id: 3, classroom_id: 3)
    );

    await postTargetBeaconToClassroom(
      TargetBeaconToClassroom(target_beacon_id: 4, classroom_id: 4)
    );

    await postStudent(
      Student(name: 'Karel', surname: 'Vrabec', sm_number: 'karelvrabeckv')
    );

    await postStudent(
      Student(name: 'Karel', surname: 'Vrabec', sm_number: 'kvrabec')
    );
  }

  static Future<List<TargetBeacon>> getTargetBeacons() async {
    _checkDatabase();

    final List<Map<String, Object?>> targetBeacons = await db!.query(
      'target_beacon'
    );

    return [
      for (final {
        'id': id as int,
        'mac': mac as String,
        'uuid': uuid as String,
        'major': major as int,
        'minor': minor as int,
      } in targetBeacons)
        TargetBeacon(id: id, mac: mac, uuid: uuid, major: major, minor: minor)
    ];
  }

  static Future<TargetBeacon> getTargetBeaconByMac(String mac) async {
    _checkDatabase();

    final List<Map<String, Object?>> targetBeacons = await db!.query(
      'target_beacon',
      where: 'mac = ?',
      whereArgs: [mac],
    );

    if (targetBeacons.isEmpty) {
      throw Exception('ERROR: Target beacon not found');
    }

    return TargetBeacon(
      id: targetBeacons[0]['id'] as int,
      mac: targetBeacons[0]['mac'] as String,
      uuid: targetBeacons[0]['uuid'] as String,
      major: targetBeacons[0]['major'] as int,
      minor: targetBeacons[0]['minor'] as int,
    );
  }

  static Future<void> postTargetBeacon(TargetBeacon beacon) async {
    _checkDatabase();

    await db!.insert(
      'target_beacon',
      beacon.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Classroom> getClassroomByTargetBeaconId(int targetBeaconId) async {
    _checkDatabase();

    final List<Map<String, Object?>> mapping = await db!.query(
      'target_beacon_to_classroom',
      where: 'target_beacon_id = ?',
      whereArgs: [targetBeaconId],
    );

    if (mapping.isEmpty) {
      throw Exception('ERROR: Mapping not found');
    }

    int classroomId = mapping[0]['classroom_id'] as int;

    final List<Map<String, Object?>> classrooms = await db!.query(
      'classroom',
      where: 'id = ?',
      whereArgs: [classroomId],
    );

    if (classrooms.isEmpty) {
      throw Exception('ERROR: Classroom not found');
    }

    return Classroom(
      id: classrooms[0]['id'] as int,
      label: classrooms[0]['label'] as String,
    );
  }

  static Future<void> postClassroom(Classroom classroom) async {
    _checkDatabase();

    await db!.insert(
      'classroom',
      classroom.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> postTargetBeaconToClassroom(TargetBeaconToClassroom targetBeaconToClassroom) async {
    _checkDatabase();

    await db!.insert(
      'target_beacon_to_classroom',
      targetBeaconToClassroom.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Student> getStudentBySmNumber(String smNumber) async {
    _checkDatabase();

    final List<Map<String, Object?>> students = await db!.query(
      'student',
      where: 'sm_number = ?',
      whereArgs: [smNumber],
    );

    if (students.isEmpty) {
      throw Exception('ERROR: Student not found');
    }

    return Student(
      id: students[0]['id'] as int,
      name: students[0]['name'] as String,
      surname: students[0]['surname'] as String,
      sm_number: students[0]['sm_number'] as String,
    );
  }

  static Future<void> postStudent(Student student) async {
    _checkDatabase();

    await db!.insert(
      'student',
      student.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Attendance>> getAttendancesByStudentId(int studentId) async {
    _checkDatabase();

    final List<Map<String, Object?>> attendances = await db!.query(
      'attendance',
      where: 'student_id = ?',
      whereArgs: [studentId],
    );

    return [
      for (final {
        'id': id as int,
        'student_id': student_id as int,
        'classroom_id': classroom_id as int,
        'date_time': date_time as String,
      } in attendances)
        Attendance(id: id, student_id: student_id, classroom_id: classroom_id, date_time: date_time)
    ];
  }

  static Future<void> postAttendance(Attendance attendance) async {
    _checkDatabase();

    await db!.insert(
      'attendance',
      attendance.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
