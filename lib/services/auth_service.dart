import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign in with email and password
  Future<User?> signInWithEmailPassword(String email, String password) async {
    try {
      debugPrint('Attempting login with email: $email');

      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Force token refresh
      await result.user?.getIdTokenResult(true);

      debugPrint('Login successful for uid: ${result.user?.uid}');

      // Verify user document exists
      if (result.user != null) {
        final userDoc = await _firestore.collection('users').doc(result.user!.uid).get();
        if (!userDoc.exists) {
          debugPrint('User document not found in Firestore - creating one');
          // Create a basic user document if it doesn't exist
          await _createBasicUserDocument(result.user!);
        }
      }

      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
      throw AuthException(_parseAuthError(e));
    } catch (e) {
      debugPrint('Unexpected error during login: $e');
      throw AuthException('Login failed: ${e.toString()}');
    }
  }

  // Create a basic user document if missing
  Future<void> _createBasicUserDocument(User user) async {
    try {
      await _firestore.collection('users').doc(user.uid).set({
        'email': user.email,
        'uid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error creating basic user document: $e');
    }
  }

  // Sign up with email and password
  Future<User?> signUpWithEmailPassword(
      String email, String password, Map<String, dynamic> userData) async {
    try {
      debugPrint('Attempting signup with email: $email');

      // Create the user account in Firebase Auth
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user == null) {
        throw AuthException('Failed to create user account');
      }

      // Add the user ID to the userData map
      userData['uid'] = result.user!.uid;
      userData['email'] = email;
      userData['createdAt'] = FieldValue.serverTimestamp();

      // Add claims to user data
      if (!userData.containsKey('claims')) {
        userData['claims'] = {
          'userType': userData['userType'] ?? 'Student',
          'hostelName': userData['hostelName'] ?? '',
        };
      }

      // Create the user document in Firestore
      await _firestore.collection('users').doc(result.user!.uid).set(userData);
      debugPrint('User document created for uid: ${result.user?.uid}');

      // Force token refresh to get updated claims
      await result.user?.getIdTokenResult(true);

      // Handle room assignment for user
      final userType = userData['userType'];
      if (userType == 'RA') {
        await _handleRARoomAssignment(result.user!, userData);
      } else {
        await _handleStudentRoomAssignment(result.user!, userData);
      }

      return result.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error during signup: ${e.code} - ${e.message}');
      throw AuthException(_parseAuthError(e));
    } catch (e) {
      debugPrint('Unexpected error during signup: $e');
      throw AuthException('Registration failed: ${e.toString()}');
    }
  }

  Future<void> _handleRARoomAssignment(User user, Map<String, dynamic> userData) async {
    try {
      final hostelName = userData['hostelName'];
      final assignedRooms = List<String>.from(userData['assignedRooms'] ?? []);

      if (hostelName == null || assignedRooms.isEmpty) {
        debugPrint('Missing required fields for RA room assignment');
        return;
      }

      debugPrint('Handling room assignment for RA with ${assignedRooms.length} rooms');

      final batch = _firestore.batch();
      for (final room in assignedRooms) {
        final roomId = '$hostelName-$room';
        final roomRef = _firestore.collection('rooms').doc(roomId);
        final chatRef = _firestore.collection('groupChats').doc(roomId);

        // Check if room exists first
        final roomDoc = await roomRef.get();
        if (roomDoc.exists) {
          batch.update(roomRef, {
            'ra_id': user.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          batch.set(roomRef, {
            'hostelName': hostelName,
            'roomNumber': room,
            'ra_id': user.uid,
            'updatedAt': FieldValue.serverTimestamp(),
            'students': [],
          });
        }

        // Check if chat exists
        final chatDoc = await chatRef.get();
        if (chatDoc.exists) {
          batch.update(chatRef, {
            'admin_id': user.uid,
            'members': FieldValue.arrayUnion([user.uid]),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          batch.set(chatRef, {
            'hostelName': hostelName,
            'roomNumber': room,
            'admin_id': user.uid,
            'members': [user.uid],
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
      debugPrint('Successfully processed RA room assignments');
    } catch (e) {
      debugPrint('Error in RA room assignment: $e');
    }
  }

  Future<void> _handleStudentRoomAssignment(User user, Map<String, dynamic> userData) async {
    try {
      final hostelName = userData['hostelName'];
      final roomNumber = userData['roomNumber'];

      if (hostelName == null || roomNumber == null) {
        debugPrint('Missing required fields for student room assignment');
        return;
      }

      final roomId = '$hostelName-$roomNumber';
      final roomRef = _firestore.collection('rooms').doc(roomId);
      final chatRef = _firestore.collection('groupChats').doc(roomId);

      // Check if room exists
      final roomDoc = await roomRef.get();
      if (roomDoc.exists) {
        await roomRef.update({
          'students': FieldValue.arrayUnion([user.uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await roomRef.set({
          'hostelName': hostelName,
          'roomNumber': roomNumber,
          'students': [user.uid],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Check if chat exists
      final chatDoc = await chatRef.get();
      if (chatDoc.exists) {
        await chatRef.update({
          'members': FieldValue.arrayUnion([user.uid]),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        await chatRef.set({
          'hostelName': hostelName,
          'roomNumber': roomNumber,
          'members': [user.uid],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('Successfully processed student room assignment');
    } catch (e) {
      debugPrint('Error in student room assignment: $e');
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      debugPrint('User signed out');
    } catch (e) {
      debugPrint('Error signing out: $e');
      throw AuthException('Sign out failed: ${e.toString()}');
    }
  }

  // Get current user
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Get user type (Student or RA)
  Future<String> getUserType() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return '';

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) return '';

      return doc.data()?['userType'] ?? '';
    } catch (e) {
      debugPrint('Error getting user type: $e');
      return '';
    }
  }

  // Get user details from Firestore
  Future<Map<String, dynamic>> getUserDetails() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw AuthException('No user is currently signed in');
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        throw AuthException('User document does not exist');
      }

      return doc.data() ?? {};
    } catch (e) {
      debugPrint('Error getting user details: $e');
      throw AuthException('Failed to get user details: ${e.toString()}');
    }
  }

  // Parse Firebase Auth errors into user-friendly messages
  String _parseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'email-already-in-use':
        return 'Email is already in use by another account';
      case 'weak-password':
        return 'Password is too weak';
      case 'invalid-email':
        return 'Email address is invalid';
      case 'user-disabled':
        return 'This user account has been disabled';
      case 'too-many-requests':
        return 'Too many requests. Try again later.';
      case 'operation-not-allowed':
        return 'Operation not allowed';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return e.message ?? 'An unknown error occurred';
    }
  }

  // Check if user is RA for a specific room
  Future<bool> isRaForRoom(String hostelName, String roomNumber) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final roomId = '$hostelName-$roomNumber';
      final roomDoc = await _firestore.collection('rooms').doc(roomId).get();

      if (!roomDoc.exists) return false;

      return roomDoc.data()?['ra_id'] == user.uid;
    } catch (e) {
      debugPrint('Error checking if user is RA for room: $e');
      return false;
    }
  }

  // Get assigned rooms for RA
  Future<List<String>> getAssignedRooms() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) return [];

      final userType = userDoc.data()?['userType'];
      if (userType != 'RA') return [];

      return List<String>.from(userDoc.data()?['assignedRooms'] ?? []);
    } catch (e) {
      debugPrint('Error getting assigned rooms: $e');
      return [];
    }
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_parseAuthError(e));
    } catch (e) {
      throw AuthException('Password reset failed: ${e.toString()}');
    }
  }
}