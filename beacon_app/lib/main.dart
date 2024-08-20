import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_beacon/flutter_beacon.dart' as fb;

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
      home: const BeaconScannerPage(title: 'Beacon Scanner'),
    );
  }
}

class BeaconScannerPage extends StatefulWidget {
  const BeaconScannerPage({super.key, required this.title});

  final String title;

  @override
  State<BeaconScannerPage> createState() => _BeaconScannerPageState();
}

class _BeaconScannerPageState extends State<BeaconScannerPage> {
  StreamSubscription? _beaconStream;
  List<fb.Beacon> beacons = [];
  List<fb.Region> regions = [];

  @override
  void initState() {
    super.initState();

    Future<void> scanning = initBeaconScanning();
    scanning
      .then((value) {
        if (kDebugMode) {
          print('----------------------------------------');
          print('\nSCANNING SUCCESSFULLY INITIATED!!!\n');
          print('----------------------------------------');
        }
      })
      .catchError((error) {
        if (kDebugMode) {
          print('----------------------------------------');
          print('\nERROR OCCURED WHILE SCANNING!!!\n');
          print('----------------------------------------');
        }
      });
  }

  void _addBeacon(fb.Beacon beacon) {
    beacons.add(beacon);
  }

  Future<void> initBeaconScanning() async {
    try {
      await fb.flutterBeacon.initializeScanning;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print(e);
      }
      return;
    }

    var region = fb.Region(
      identifier: 'IOTS_TG_DC8E5D2',
      proximityUUID: 'ffffffff-1070-1234-5678-123456789123',
      major: 1000,
      minor: 1138,
    );

    regions.add(region);
  
    if (kDebugMode) {
      print('----------------------------------------');
      print(regions);
      print('----------------------------------------');
    }

    if (regions.isNotEmpty) {
      _beaconStream = fb.flutterBeacon.ranging(regions).listen((result) {
        if (result.beacons.isNotEmpty) {
          if (kDebugMode) {
            print('----------------------------------------');
            print('BEACONS FOUND!!!');
            print('----------------------------------------');
          }

          for (var beacon in result.beacons) {
            _addBeacon(beacon);
          }
        } else {
            if (kDebugMode) {
              print('----------------------------------------');
              print('NOTHING FOUND SO FAR!!!');
              print('----------------------------------------');
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
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              'Some text',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
