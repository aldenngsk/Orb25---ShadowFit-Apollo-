import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:typed_data';

class FirebaseService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // Initialize Firebase
  static Future<void> initializeFirebase() async {
    await Firebase.initializeApp();
  }

  // Authentication Methods
  static Future<UserCredential> signUpWithEmailAndPassword(
      String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  static Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> signOut() async {
    await _auth.signOut();
  }

  // Firestore Methods
  static Future<void> addUserData(String userId, Map<String, dynamic> userData) async {
    try {
      // Use update with merge to prevent overwriting other fields
      await _firestore.collection('users').doc(userId).set(userData, SetOptions(merge: true));
    } catch (e) {
      print("Error saving user data: $e");
      // Retry once after a short delay
      await Future.delayed(Duration(milliseconds: 500));
      try {
        await _firestore.collection('users').doc(userId).set(userData, SetOptions(merge: true));
      } catch (retryError) {
        print("Error retrying save user data: $retryError");
        rethrow;
      }
    }
  }

  static Future<void> updateUserData(String userId, Map<String, dynamic> userData) async {
    try {
      await _firestore.collection('users').doc(userId).update(userData);
    } catch (e) {
      print("Error updating user data: $e");
      // Retry once after a short delay
      await Future.delayed(Duration(milliseconds: 500));
      try {
        await _firestore.collection('users').doc(userId).update(userData);
      } catch (retryError) {
        print("Error retrying update user data: $retryError");
        rethrow;
      }
    }
  }

  static Future<DocumentSnapshot> getUserData(String userId) async {
    try {
      return await _firestore.collection('users').doc(userId).get();
    } catch (e) {
      print("Error getting user data: $e");
      // Retry once after a short delay
      await Future.delayed(Duration(milliseconds: 500));
      try {
        return await _firestore.collection('users').doc(userId).get();
      } catch (retryError) {
        print("Error retrying get user data: $retryError");
        rethrow;
      }
    }
  }

  // Get a live stream of the user's document
  static Stream<DocumentSnapshot> userDocStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots();
  }

  // Storage Methods
  static Future<String> uploadImage(String path, List<int> imageBytes) async {
    try {
      final ref = _storage.ref().child(path);
      await ref.putData(Uint8List.fromList(imageBytes));
      return await ref.getDownloadURL();
    } catch (e) {
      rethrow;
    }
  }

  // Get current user
  static User? get currentUser => _auth.currentUser;
} 