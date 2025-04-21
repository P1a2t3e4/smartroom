import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smartroom/services/conflict_service.dart';
import 'package:smartroom/services/user_service.dart';

class ConflictReportingScreen extends StatefulWidget {
  const ConflictReportingScreen({super.key});

  @override
  _ConflictReportingScreenState createState() => _ConflictReportingScreenState();
}

class _ConflictReportingScreenState extends State<ConflictReportingScreen> {
  final TextEditingController _raNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedConflictType;
  bool _isSubmitting = false;
  String? _roomNumber;
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _loadUserRoomNumber();
  }

  Future<void> _loadUserRoomNumber() async {
    try {
      // Using the getUserRoomNumber method instead of getCurrentUserData
      final roomNumber = await _userService.getUserRoomNumber();
      if (roomNumber != null) {
        setState(() {
          _roomNumber = roomNumber;
        });
      }
    } catch (e) {
      print('Error loading user room number: $e');
    }
  }

  Future<void> submitConflictReport() async {
    String raName = _raNameController.text.trim();
    String description = _descriptionController.text.trim();

    if (raName.isEmpty || description.isEmpty || _selectedConflictType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required!")),
      );
      return;
    }

    if (_roomNumber == null || _roomNumber!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Your room number could not be determined. Please contact support.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("You must be logged in to submit a report");
      }

      // Create complaint data
      final complaintData = {
        'reporterId': user.uid,
        'raName': raName,
        'conflictType': _selectedConflictType,
        'description': description,
        'roomNumber': _roomNumber,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending', // Important: Set initial status as pending
      };

      // Submit the complaint directly to Firestore
      await FirebaseFirestore.instance
          .collection('conflict_reports')
          .add(complaintData);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Conflict reported successfully!")),
      );

      // Clear fields
      _raNameController.clear();
      _descriptionController.clear();
      setState(() => _selectedConflictType = null);
    } catch (error) {
      print("Error reporting conflict: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error submitting report: ${error.toString()}")),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Conflict', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue[800],
        elevation: 4,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Display room number info
            if (_roomNumber != null)
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 4,
                color: Colors.blue[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(Icons.room, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      Text(
                        'Room: $_roomNumber',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            _buildTextField("RA Name", "Enter the RA's name", _raNameController),
            const SizedBox(height: 20),
            _buildDropdownField(),
            const SizedBox(height: 20),
            _buildTextField("Description", "Describe the conflict in detail", _descriptionController, maxLines: 4),
            const SizedBox(height: 30),
            Center(
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : submitConflictReport,
                icon: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Icon(Icons.send),
                label: const Text('Submit Report'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildTextField(String label, String hint, TextEditingController controller, {int maxLines = 1}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue)),
              ),
              maxLines: maxLines,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 4,
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Type of Conflict', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
            const SizedBox(height: 8),
            DropdownButtonFormField(
              value: _selectedConflictType,
              items: ['Cleanliness', 'Noise', 'Rule Violations']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedConflictType = value as String?),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blue)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue[900]!, Colors.blue[600]!], begin: Alignment.centerLeft, end: Alignment.centerRight),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: const Text(
        'Thank you for helping us improve!',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500, fontSize: 16),
        textAlign: TextAlign.center,
      ),
    );
  }
}