import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthServices {
  //Firebase authentication instance
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //function to handle farmer signup
  Future<String?> signup({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      //create a user in firebase authentication with email and password
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password.trim(),
          );

      //save additional farmer data in firestore (name, role, email)
      await _firestore.collection("farmers").doc(userCredential.user!.uid).set({
        "name": name.trim(),
        "email": email.trim(),
        "role": role.trim(), //role determines if user is admin or farmer
      });
      return null; //success: no error message
    } catch (e) {
      return friendlyError(e); //error: simple message for the farmer
    }
  }

  //function to handle user login
  Future<String?> login({
    required String email,
    required String password,
    //required String role,
  }) async {
    try {
      //sign in user using firebase authentication with email and password
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      //fetching user's role from firestore to determine access level
      DocumentSnapshot userDoc = await _firestore
          .collection("farmers")
          .doc(userCredential.user!.uid)
          .get();

      //account exists in auth but has no profile/role in firestore
      final data = userDoc.data() as Map<String, dynamic>?;
      final role = data?['role'];
      if (role is! String) {
        await _auth.signOut();
        return "Your account profile was not found. Please contact support.";
      }
      return role; //retutn the user's role (admin/farmer)
    } catch (e) {
      return friendlyError(e); //error: simple message for the farmer
    }
  }

  //send a password reset link to the user's email
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null; //success
    } catch (e) {
      return friendlyError(e);
    }
  }

  /// Turns Firebase error codes into short, plain-language messages.
  static String friendlyError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
        case 'INVALID_LOGIN_CREDENTIALS':
          return "Wrong email or password. Please try again.";
        case 'invalid-email':
          return "Please enter a valid email address, e.g. name@gmail.com";
        case 'email-already-in-use':
          return "An account with this email already exists. Please log in instead.";
        case 'weak-password':
          return "Your password is too short. Use at least 6 characters.";
        case 'user-disabled':
          return "This account has been disabled. Please contact support.";
        case 'too-many-requests':
          return "Too many attempts. Please wait a few minutes and try again.";
        case 'network-request-failed':
          return "No internet connection. Please check your network and try again.";
      }
      return e.message ?? "Something went wrong. Please try again.";
    }
    if (e is FirebaseException && e.code == 'unavailable') {
      return "No internet connection. Please check your network and try again.";
    }
    return "Something went wrong. Please try again.";
  }

  //for user Logout
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
