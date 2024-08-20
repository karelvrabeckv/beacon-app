import 'dart:async';

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
  var targetedBeacon;
  List<Region> regions = [];

  @override
  void initState() {
    super.initState();

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

  void _addBeacon(Beacon beacon) {
    setState(() {
      targetedBeacon = beacon;
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

    var region = Region(
      identifier: 'IOTS_TG_DC8E5D2',
      proximityUUID: 'ffffffff-1070-1234-5678-123456789123',
      major: 1000,
      minor: 1138,
    );

    regions.add(region);

    if (regions.isNotEmpty) {
      flutterBeacon.ranging(regions).listen((result) {
        if (result.beacons.isNotEmpty) {
          for (var beacon in result.beacons) {
            _addBeacon(beacon);
          }

          if (kDebugMode) {
            print('\x1B[32m''BEACON FOUND''\x1B[0m');
            print(''
              'proximityUUID: ${targetedBeacon.proximityUUID}, '
              'macAddress: ${targetedBeacon.macAddress}, '
              'major: ${targetedBeacon.major}, '
              'minor: ${targetedBeacon.minor}, '
              'rssi: ${targetedBeacon.rssi}, '
              'txPower: ${targetedBeacon.txPower}, '
              'accuracy: ${targetedBeacon.accuracy}, '
              'proximity: ${targetedBeacon.proximity}'
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
            Text('proximityUUID', style: Theme.of(context).textTheme.headlineMedium),
            Text('${targetedBeacon?.proximityUUID}'),
            const SizedBox(height: 12),
            Text('macAddress', style: Theme.of(context).textTheme.headlineMedium),
            Text('${targetedBeacon?.macAddress}'),
            const SizedBox(height: 12),
            Text('major', style: Theme.of(context).textTheme.headlineMedium),
            Text('${targetedBeacon?.major}'),
            const SizedBox(height: 12),
            Text('minor', style: Theme.of(context).textTheme.headlineMedium),
            Text('${targetedBeacon?.minor}'),
            const SizedBox(height: 12),
            Text('rssi', style: Theme.of(context).textTheme.headlineMedium),
            Text('${targetedBeacon?.rssi}'),
            const SizedBox(height: 12),
            Text('txPower', style: Theme.of(context).textTheme.headlineMedium),
            Text('${targetedBeacon?.txPower}'),
            const SizedBox(height: 12),
            Text('accuracy', style: Theme.of(context).textTheme.headlineMedium),
            Text('${targetedBeacon?.accuracy}'),
            const SizedBox(height: 12),
            Text('proximity', style: Theme.of(context).textTheme.headlineMedium),
            Text('${targetedBeacon?.proximity}'),
          ],
        ),
      ),
    );
  }
}
