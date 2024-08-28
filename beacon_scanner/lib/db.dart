import 'package:beacon_scanner/target_beacon.dart';

import 'package:flutter/widgets.dart';

import 'package:path/path.dart';

import 'package:sqflite/sqflite.dart';

class Db {
  static Database? db;

  static Future<void> connect() async {
    WidgetsFlutterBinding.ensureInitialized();

    db = await openDatabase(
      join(await getDatabasesPath(), 'beacons.db'),
      version: 1,
      onCreate: (database, version) {
        return database.execute(
          'CREATE TABLE target_beacon(id INTEGER PRIMARY KEY, uuid TEXT, major INTEGER, minor INTEGER)',
        );
      },
    );

    if (db == null) {
      throw Exception('\x1B[31mERROR: Connection failed\x1B[31m');
    }
  }

  static Future<List<TargetBeacon>> getBeacons() async {
    if (db == null) {
      throw Exception('\x1B[31mERROR: There is no DB\x1B[31m');
    }

    final List<Map<String, Object?>> beaconMaps = await db!.query('target_beacon');

    return [
      for (final {
        'id': id as int,
        'uuid': uuid as String,
        'major': major as int,
        'minor': minor as int
      } in beaconMaps)
        TargetBeacon(id: id, uuid: uuid, major: major, minor: minor)
    ];
  }

  static Future<void> postBeacon(TargetBeacon beacon) async {
    if (db == null) {
      throw Exception('\x1B[31mERROR: There is no DB\x1B[31m');
    }

    await db!.insert(
      'target_beacon',
      beacon.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> postBeacons() async {
    await postBeacon(TargetBeacon(id: 0, uuid: 'ffffffff-1070-1234-5678-123456789123', major: 1000, minor: 1138));
    await postBeacon(TargetBeacon(id: 1, uuid: 'a92ee200-5501-11e4-916c-0800200c9a66', major: 12061, minor: 28012));
    await postBeacon(TargetBeacon(id: 2, uuid: 'a92ee200-5501-11e4-916c-0800200c9a66', major: 12939, minor: 48773));
  }

  static Future<void> putBeacon(TargetBeacon beacon) async {
    if (db == null) {
      throw Exception('\x1B[31mERROR: There is no DB\x1B[31m');
    }

    await db!.update(
      'target_beacon',
      beacon.toMap(),
      where: 'id = ?',
      whereArgs: [beacon.id],
    );
  }

  static Future<void> deleteBeacon(String id) async {
    if (db == null) {
      throw Exception('\x1B[31mERROR: There is no DB\x1B[31m');
    }

    await db!.delete(
      'target_beacon',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
