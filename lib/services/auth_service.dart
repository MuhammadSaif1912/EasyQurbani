import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UserModel?> signUp({
    required String name,
    required String address,
    required String email,
    required String contact,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      UserModel user = UserModel(
        uid: userCredential.user!.uid,
        name: name,
        address: address,
        email: email,
        contact: contact,
      );
      await _firestore.collection('users').doc(user.uid).set({
        'name': name,
        'address': address,
        'email': email,
        'contact': contact,
      });
      return user;
    } catch (e) {
      print(e);
      return null;
    }
  }

  Future<UserModel?> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Refresh the token to ensure custom claims are available
      await userCredential.user!.reload();
      final updatedUser = _auth.currentUser;
      await updatedUser?.getIdToken(true); // Force token refresh

      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      // Check if the document exists
      if (!doc.exists) {
        print('User document does not exist');
        return null;
      }

      // Safely access fields with null checks and default values
      return UserModel(
        uid: userCredential.user!.uid,
        name: doc['name'] as String? ?? '',
        address: doc['address'] as String? ?? '',
        email: doc['email'] as String? ?? '',
        contact: doc['contact'] as String? ?? '',
      );
    } catch (e) {
      print(e);
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

Future<bool> isAdmin() async {
  try {
    final user = _auth.currentUser;
    if (user == null) return false;
    final idTokenResult = await user.getIdTokenResult(true);
    print('Admin claim: ${idTokenResult.claims?['isAdmin']}'); // Debug print
    return idTokenResult.claims?['isAdmin'] as bool? ?? false;
  } catch (e) {
    print('Error checking admin status: $e');
    return false;
  }
}
}