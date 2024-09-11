import 'package:beacon_scanner/auth.dart';
import 'package:beacon_scanner/pages/beacon_scanner_page.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

import 'package:iconly/iconly.dart';

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
        child: Center(
          child: Column(
            children: <Widget>[
              const Spacer(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 512),
                child: Image.asset('assets/beacon.jpg'),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'IoT Beacon Scanner',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                'Find beacons at SMI right now',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                ),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
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
                icon: const Icon(IconlyLight.login),
                label: Text(
                  'Continue with Google',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
