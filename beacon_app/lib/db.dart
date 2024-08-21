import 'package:beacon_app/beacon.dart';

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
          'CREATE TABLE beacon(uuid TEXT PRIMARY KEY, major INTEGER, minor INTEGER)',
        );
      },
    );
  }

  static Future<List<Beacon>> getBeacons() async {
    if (db == null) {
      throw Exception('ERROR: There is no DB');
    }

    final List<Map<String, Object?>> beaconMaps = await db!.query('beacon');

    return [
      for (final {'uuid': uuid as String, 'major': major as int, 'minor': minor as int} in beaconMaps)
        Beacon(uuid: uuid, major: major, minor: minor)
    ];
  }

  static Future<void> postBeacon(Beacon beacon) async {
    if (db == null) {
      throw Exception('ERROR: There is no DB');
    }

    await db!.insert(
      'beacon',
      beacon.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> postBeacons() async {
    await postBeacon(Beacon(uuid: 'ffffffff-1070-1234-5678-123456789123', major: 1000, minor: 1138));
    await postBeacon(Beacon(uuid: 'a92ee200-5501-11e4-916c-0800200c9a66', major: 12061, minor: 28012));
  }

  static Future<void> putBeacon(Beacon beacon) async {
    if (db == null) {
      throw Exception('ERROR: There is no DB');
    }

    await db!.update(
      'beacon',
      beacon.toMap(),
      where: 'uuid = ?',
      whereArgs: [beacon.uuid],
    );
  }

  static Future<void> deleteBeacon(String uuid) async {
    if (db == null) {
      throw Exception('ERROR: There is no DB');
    }

    await db!.delete(
      'beacon',
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  }
}
