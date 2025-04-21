import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class GroupCreationScreen extends StatelessWidget {
  const GroupCreationScreen({super.key});

  Future<void> _createGroup(BuildContext context, String hostel, String roomNumber) async {
    final FirebaseFirestore _firestore = FirebaseFirestore.instance;
    final FirebaseAuth _auth = FirebaseAuth.instance;

    try {
      // Generate a unique group code
      String groupCode = "Room${DateTime.now().millisecondsSinceEpoch}";

      // Save group details in Firestore
      await _firestore.collection('groups').doc(groupCode).set({
        'groupCode': groupCode,
        'hostel': hostel,
        'roomNumber': roomNumber,
        'createdAt': DateTime.now(),
      });

      // Add the current user as a member of the group
      User? user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('groups').doc(groupCode).collection('members').doc(user.uid).set({
          'userId': user.uid,
          'userName': user.displayName ?? "Unknown User",
        });
      }

      // Show success dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Group Created"),
          content: Text("Your group code is: $groupCode"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("Close"),
            ),
          ],
        ),
      );
    } catch (e) {
      // Handle errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to create group: ${e.toString()}")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String? selectedHostel;
    final TextEditingController _roomNumberController = TextEditingController();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Group"),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
      ),
      body: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade100, Colors.blue.shade700],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Create a Group',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: "Select Hostel",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: "Hostel A",
                        child: Text("Hostel A"),
                      ),
                      DropdownMenuItem(
                        value: "Hostel B",
                        child: Text("Hostel B"),
                      ),
                      DropdownMenuItem(
                        value: "Hostel C",
                        child: Text("Hostel C"),
                      ),
                    ],
                    onChanged: (value) {
                      selectedHostel = value;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _roomNumberController,
                    decoration: InputDecoration(
                      labelText: 'Room Number',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton(
                      onPressed: () {
                        if (selectedHostel != null && _roomNumberController.text.isNotEmpty) {
                          _createGroup(context, selectedHostel!, _roomNumberController.text);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Please fill all fields!")),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                      ),
                      child: const Text(
                        "Create Group",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}