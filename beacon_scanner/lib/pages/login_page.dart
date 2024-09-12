import 'package:beacon_scanner/auth.dart';
import 'package:beacon_scanner/constants.dart';
import 'package:beacon_scanner/pages/beacon_scanner_page.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

import 'package:icons_plus/icons_plus.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
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
                      const SizedBox(height: 30 * gap),
                      Image.asset('assets/beacon.jpg'),
                      Padding(
                        padding: const EdgeInsets.all(2 * gap),
                        child: Text(
                          'IoT Beacon Scanner',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ),
                      Text(
                        'Find beacons at SMI right now',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 2 * gap),
                    ],
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(4 * gap),
              child: FilledButton.tonalIcon(
                icon: const Icon(BoxIcons.bx_log_in),
                label: Text('Continue with Google'),
                onPressed: () async {
                  try {
                    final user = await Auth.loginWithGoogle();
              
                    if (user != null) {
                      Navigator.of(context).pushReplacement(MaterialPageRoute(
                        builder: (context) => const BeaconScannerPage(),
                      ));
                    }
                  } on FirebaseAuthException catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(e.message ?? 'Something went wrong')
                    ));
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(e.toString())
                    ));
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
