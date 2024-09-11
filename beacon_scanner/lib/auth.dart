import 'package:firebase_auth/firebase_auth.dart';

import 'package:google_sign_in/google_sign_in.dart';

class Auth {
  static User? user = null;

  static Future<User?> loginWithGoogle() async {
    final googleAccount = await GoogleSignIn().signIn();
    if (googleAccount == null) {
      return null;
    }
    
    final googleAuth = await googleAccount.authentication;
    
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    
    final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);

    user = userCredential.user;

    return user;
  }

  static Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();

    user = null;
  }
}
