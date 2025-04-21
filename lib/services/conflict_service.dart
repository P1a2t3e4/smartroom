import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ConflictService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Submits a conflict report and associates it with the logged-in user.
  static Future<void> submitConflictReport(
      String raName, String conflictType, String description) async {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in!");
    }

    try {
      // First, get the user's room number from their profile
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        throw Exception("User profile not found");
      }

      final userData = userDoc.data() as Map<String, dynamic>?;
      final String? roomNumber = userData?['roomNumber'] as String?;
      final String? hostelName = userData?['hostelName'] as String?;

      if (roomNumber == null || roomNumber.isEmpty) {
        throw Exception("Room number not found in user profile");
      }

      // Create and submit the conflict report with all required fields
      DocumentReference reportRef = await _firestore.collection("conflict_reports").add({
        "reporterId": user.uid,
        "raName": raName,
        "conflictType": conflictType,
        "description": description,
        "roomNumber": roomNumber,
        "hostelName": hostelName,
        "timestamp": FieldValue.serverTimestamp(),
        "status": "pending",
      });

      print("Conflict report submitted successfully with ID: ${reportRef.id}");
    } catch (e) {
      print("Error submitting report: $e");
      throw Exception("Failed to submit conflict report: $e");
    }
  }

  /// Retrieves conflict reports specific to the logged-in user.
  static Stream<QuerySnapshot> getUserConflictReports() {
    User? user = _auth.currentUser;
    if (user == null) {
      throw Exception("User not logged in!");
    }

    return _firestore
        .collection("conflict_reports")
        .where("reporterId", isEqualTo: user.uid)
        .orderBy("timestamp", descending: true)
        .snapshots();
  }

  /// Get conflict reports for an RA based on their assigned rooms
  static Stream<QuerySnapshot> getRaConflictReports(List<String> assignedRooms) {
    if (assignedRooms.isEmpty) {
      // Return empty stream if no rooms assigned
      return _firestore
          .collection("conflict_reports")
          .where("roomNumber", whereIn: ["none"])
          .snapshots();
    }

    return _firestore
        .collection("conflict_reports")
        .where("roomNumber", whereIn: assignedRooms)
        .orderBy("timestamp", descending: true)
        .snapshots();
  }
}