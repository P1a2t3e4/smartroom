import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart'; // Add this import for debugPrint

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user's data
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    User? user = _auth.currentUser;
    if (user == null) return null;

    DocumentSnapshot userDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      return userDoc.data() as Map<String, dynamic>;
    } else {
      return null;
    }
  }

  // Get the current user's room number
  Future<String?> getUserRoomNumber() async {
    User? user = _auth.currentUser;
    if (user == null) return null;

    DocumentSnapshot userDoc = await _firestore
        .collection('users')
        .doc(user.uid)
        .get();

    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;
      return userData['roomNumber'] as String?;
    } else {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getRoommates(String roomNumber) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('roomNumber', isEqualTo: roomNumber)
          .get();

      return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error getting roommates: $e');
      return [];
    }
  }

  // Get rooms assigned to the current RA
  Future<List<String>> getAssignedRooms() async {
    User? user = _auth.currentUser;
    if (user == null) return [];

    try {
      // First get the user document to check their role
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return [];

      final userData = userDoc.data() as Map<String, dynamic>;
      String userType = userData['userType'] ?? '';

      if (userType != 'RA') {
        print('User is not an RA: $userType');
        return [];
      }

      // Get the hostel name where this RA works
      String? hostelName = userData['hostelName'] as String?;
      if (hostelName == null || hostelName.isEmpty) {
        print('RA has no assigned hostel');
        return [];
      }

      // Get all rooms in this hostel that are assigned to this RA
      final roomsSnapshot = await _firestore
          .collection('rooms')
          .where('hostelName', isEqualTo: hostelName)
          .where('assignedRA', isEqualTo: user.uid)
          .get();

      List<String> rooms = [];
      for (var doc in roomsSnapshot.docs) {
        final roomData = doc.data();
        final roomNumber = roomData['roomNumber'] as String?;
        if (roomNumber != null && roomNumber.isNotEmpty) {
          rooms.add(roomNumber);
        }
      }

      // If no rooms found through direct assignment, default to all rooms in the hostel
      if (rooms.isEmpty) {
        final allRoomsSnapshot = await _firestore
            .collection('rooms')
            .where('hostelName', isEqualTo: hostelName)
            .get();

        for (var doc in allRoomsSnapshot.docs) {
          final roomData = doc.data();
          final roomNumber = roomData['roomNumber'] as String?;
          if (roomNumber != null && roomNumber.isNotEmpty) {
            rooms.add(roomNumber);
          }
        }
      }

      print('Assigned rooms for RA: $rooms');
      return rooms;
    } catch (e) {
      print('Error getting assigned rooms: $e');
      return [];
    }
  }

  // New method to get room details
  Future<Map<String, dynamic>> getRoomDetails(String roomNumber) async {
    try {
      // Get the room document from Firestore
      final roomDoc = await _firestore
          .collection('rooms')
          .where('roomNumber', isEqualTo: roomNumber)
          .limit(1)
          .get();

      Map<String, dynamic> roomDetails = {};

      if (roomDoc.docs.isNotEmpty) {
        roomDetails = roomDoc.docs.first.data();
      } else {
        debugPrint('Room not found: $roomNumber');
      }



      // Get all students in this room
      final studentsSnapshot = await _firestore
          .collection('users')
          .where('roomNumber', isEqualTo: roomNumber)
          .get();

      List<Map<String, dynamic>> students = studentsSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      // Add the students list to room details
      roomDetails['students'] = students;
      roomDetails['studentCount'] = students.length;

      return roomDetails;
    } catch (e) {
      debugPrint('Error getting room details: $e');
      return {'error': e.toString()};
    }
  }
}