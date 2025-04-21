import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _roomController = TextEditingController();
  final TextEditingController _hostelController = TextEditingController();
  final TextEditingController _assignedRoomsController = TextEditingController();

  bool _isLoading = false;
  String _userType = 'Student';
  List<String> _userTypes = ['Student', 'RA'];
  String? _passwordError;
  String? _emailError;
  String? _assignedRoomsError;
  bool _isPasswordVisible = false;

  final List<String> _hostels = [
    "Efua Sutherland Hall",
    "Ephraim Amu Hall",
    "Oteng Korankye Hall",
    "Walter Sisulu Hall",
    "Wangari Maathai Hall",
    "Kofi Tawiah Hall",
    "Hostel 2C",
    "Hostel 2D",
    "Hostel 2E",
  ];

  bool _validatePassword(String password) {
    if (password.length < 8) return false;
    final hasUpperCase = RegExp(r'[A-Z]').hasMatch(password);
    final hasLowerCase = RegExp(r'[a-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasSpecialChar = RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
    return hasUpperCase && hasLowerCase && hasNumber && hasSpecialChar;
  }

  bool _validateEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@ashesi\.edu\.gh$').hasMatch(email);
  }

  Future<Map<String, String>> _checkRoomAvailability(List<String> roomNumbers, String hostelName) async {
    Map<String, String> unavailableRooms = {};
    try {
      for (String roomNumber in roomNumbers) {
        final String roomId = '$hostelName-$roomNumber';
        final roomDoc = await _firestore.collection('rooms').doc(roomId).get();

        if (roomDoc.exists) {
          final data = roomDoc.data();
          final String? raId = data?['ra_id'] as String?;

          if (raId != null && raId.isNotEmpty) {
            try {
              final raDoc = await _firestore.collection('users').doc(raId).get();
              final raName = raDoc.exists ? (raDoc.data()?['fullName'] ?? 'another RA') : 'another RA';
              unavailableRooms[roomNumber] = raName;
            } catch (e) {
              debugPrint('Error fetching RA info: $e');
              unavailableRooms[roomNumber] = 'another RA';
            }
          }
        }
      }
      return unavailableRooms;
    } catch (e) {
      debugPrint('Error in _checkRoomAvailability: $e');
      throw e;
    }
  }

  // Updated custom claims handling - now directly updates claims in Firestore
  Future<void> _storeUserClaims(String uid, Map<String, dynamic> claims) async {
    try {
      // Store the claims in the user document
      await _firestore.collection('users').doc(uid).update({
        'claims': claims,
      });

      debugPrint('User claims stored in Firestore');
    } catch (e) {
      debugPrint('Error storing user claims: $e');
      rethrow;
    }
  }

  Future<void> _signUp() async {
    setState(() {
      _passwordError = null;
      _emailError = null;
      _assignedRoomsError = null;
      _isLoading = true;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final fullName = _nameController.text.trim();
    final roomNumber = _roomController.text.trim();
    final hostelName = _hostelController.text.trim();

    // Validate all required fields
    if (fullName.isEmpty || roomNumber.isEmpty || hostelName.isEmpty) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required.")),
      );
      return;
    }

    // Validate email format
    if (!_validateEmail(email)) {
      setState(() {
        _emailError = "Please enter a valid @ashesi.edu.gh email";
        _isLoading = false;
      });
      return;
    }

    // Validate password strength
    if (!_validatePassword(password)) {
      setState(() {
        _passwordError = "Password must be 8+ chars with uppercase, lowercase, number & special char";
        _isLoading = false;
      });
      return;
    }

    List<String> assignedRooms = [];
    if (_userType == 'RA') {
      final assignedRoomsText = _assignedRoomsController.text.trim();
      if (assignedRoomsText.isEmpty) {
        setState(() {
          _assignedRoomsError = "RAs must list their assigned rooms";
          _isLoading = false;
        });
        return;
      }

      assignedRooms = assignedRoomsText
          .split(',')
          .map((room) => room.trim())
          .where((room) => room.isNotEmpty)
          .toList();

      try {
        final unavailableRooms = await _checkRoomAvailability(assignedRooms, hostelName);
        if (unavailableRooms.isNotEmpty) {
          setState(() => _isLoading = false);
          _showUnavailableRoomsDialog(unavailableRooms);
          return;
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error checking room availability: ${e.toString()}")),
        );
        return;
      }
    }

    User? userCredential;

    try {
      // Check if email is already registered
      try {
        final methods = await _auth.fetchSignInMethodsForEmail(email);
        if (methods.isNotEmpty) {
          setState(() {
            _emailError = "Email already registered";
            _isLoading = false;
          });
          return;
        }
      } catch (e) {
        debugPrint('Error checking email: $e');
        // Continue with registration attempt even if this check fails
      }

      // Create user in Firebase Auth
      final authResult = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      userCredential = authResult.user;
      if (userCredential == null) {
        throw Exception("Failed to create user account");
      }

      final userId = userCredential.uid;
      debugPrint('Created auth user with ID: $userId');

      // Prepare user data with correct fields
      final userData = {
        'uid': userId,
        'fullName': fullName,
        'email': email,
        'roomNumber': roomNumber,
        'hostelName': hostelName,
        'userType': _userType,
        'createdAt': FieldValue.serverTimestamp(),
        'claims': {
          'userType': _userType,
          'hostelName': hostelName,
        }
      };

      // Add assigned rooms for RA users
      if (_userType == 'RA') {
        userData['assignedRooms'] = assignedRooms;
      }

      // Write to Firestore - ensure this happens before room processing
      await _firestore.collection('users').doc(userId).set(userData);
      debugPrint('User document created in Firestore');

      // Process room assignments after user creation
      if (_userType == 'RA') {
        await _processRARoomAssignments(userId, hostelName, assignedRooms);
      } else {
        await _processStudentRoomAssignment(userId, hostelName, roomNumber);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Sign-up successful!")),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      // If we created a user but then something failed, delete the user to avoid orphaned auth records
      if (userCredential != null) {
        try {
          await userCredential.delete();
          debugPrint('Deleted user after failed signup');
        } catch (deleteError) {
          debugPrint('Error deleting user after failed signup: $deleteError');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_getAuthErrorMessage(e))),
      );
    } catch (e) {
      // Clean up user if created but later steps failed
      if (userCredential != null) {
        try {
          await userCredential.delete();
          debugPrint('Deleted user after exception');
        } catch (deleteError) {
          debugPrint('Error deleting user after exception: $deleteError');
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processRARoomAssignments(String userId, String hostelName, List<String> assignedRooms) async {
    try {
      final batch = _firestore.batch();
      debugPrint('Processing RA room assignments for user $userId with ${assignedRooms.length} rooms');

      for (final room in assignedRooms) {
        final roomId = '$hostelName-$room';
        final roomRef = _firestore.collection('rooms').doc(roomId);
        final chatRef = _firestore.collection('groupChats').doc(roomId);

        // Check if room already exists
        final roomDoc = await roomRef.get();
        if (roomDoc.exists) {
          // Update existing room
          batch.update(roomRef, {
            'ra_id': userId,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Create new room
          batch.set(roomRef, {
            'hostelName': hostelName,
            'roomNumber': room,
            'ra_id': userId,
            'updatedAt': FieldValue.serverTimestamp(),
            'students': [],
          });
        }

        // Check if chat already exists
        final chatDoc = await chatRef.get();
        if (chatDoc.exists) {
          // Update existing chat
          batch.update(chatRef, {
            'admin_id': userId,
            'members': FieldValue.arrayUnion([userId]),
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        } else {
          // Create new chat
          batch.set(chatRef, {
            'hostelName': hostelName,
            'roomNumber': room,
            'admin_id': userId,
            'members': [userId],
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      await batch.commit();
      debugPrint('Successfully processed RA room assignments');
    } catch (e) {
      debugPrint('Error processing RA room assignments: $e');
      throw e; // Re-throw to handle in the calling function
    }
  }

  Future<void> _processStudentRoomAssignment(String userId, String hostelName, String roomNumber) async {
    try {
      final roomId = '$hostelName-$roomNumber';
      final roomRef = _firestore.collection('rooms').doc(roomId);
      final chatRef = _firestore.collection('groupChats').doc(roomId);

      // Check if room exists and update or create
      final roomDoc = await roomRef.get();
      if (roomDoc.exists) {
        await roomRef.update({
          'students': FieldValue.arrayUnion([userId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        await roomRef.set({
          'hostelName': hostelName,
          'roomNumber': roomNumber,
          'students': [userId],
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Check if chat exists and update or create
      final chatDoc = await chatRef.get();
      if (chatDoc.exists) {
        await chatRef.update({
          'members': FieldValue.arrayUnion([userId]),
          'lastUpdated': FieldValue.serverTimestamp(),
        });
      } else {
        await chatRef.set({
          'hostelName': hostelName,
          'roomNumber': roomNumber,
          'members': [userId],
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      debugPrint('Successfully processed student room assignment');
    } catch (e) {
      debugPrint('Error processing student room assignment: $e');
      throw e; // Re-throw to handle in the calling function
    }
  }

  void _showUnavailableRoomsDialog(Map<String, String> unavailableRooms) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Room Assignment Conflict'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('The following rooms are already assigned to other RAs:'),
                const SizedBox(height: 12),
                ...unavailableRooms.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text('• Room ${entry.key} is assigned to ${entry.value}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                )),
                const SizedBox(height: 8),
                Text('Please choose different rooms or contact administration.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  String _getAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return "Email already registered. Please try logging in or use a different email.";
      case 'weak-password':
        return "Password too weak. Please use a stronger password.";
      case 'invalid-email':
        return "Invalid email format.";
      case 'operation-not-allowed':
        return "Email/password accounts are not enabled.";
      default:
        return "Authentication failed: ${e.message ?? e.code}";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up'),
        backgroundColor: Colors.blue.shade800,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.lightBlue.shade200, Colors.blue.shade800],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                elevation: 10,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 10),
                      _buildTextField(_nameController, "Full Name", Icons.person),
                      const SizedBox(height: 16),
                      _buildEmailField(),
                      const SizedBox(height: 16),
                      _buildPasswordField(),
                      const SizedBox(height: 16),
                      _buildHostelAutocomplete(),
                      const SizedBox(height: 16),
                      _buildTextField(_roomController, "Room Number", Icons.home),
                      const SizedBox(height: 16),
                      _buildUserTypeDropdown(),
                      if (_userType == 'RA') ...[
                        const SizedBox(height: 16),
                        _buildAssignedRoomsField(),
                      ],
                      const SizedBox(height: 24),
                      _buildSignUpButton(),
                      const SizedBox(height: 16),
                      _buildLoginLink(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHostelAutocomplete() {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue value) {
        if (value.text.isEmpty) return const Iterable<String>.empty();
        return _hostels.where((hostel) =>
            hostel.toLowerCase().contains(value.text.toLowerCase()));
      },
      onSelected: (String selection) => _hostelController.text = selection,
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        _hostelController.text = _hostelController.text.isEmpty ? controller.text : _hostelController.text;
        controller.text = _hostelController.text;

        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: "Hostel Name",
            prefixIcon: const Icon(Icons.apartment, color: Colors.blue),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear, color: Colors.grey),
              onPressed: () {
                controller.clear();
                _hostelController.clear();
              },
            )
                : null,
          ),
          onChanged: (value) => _hostelController.text = value,
        );
      },
    );
  }

  Widget _buildUserTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _userType,
      decoration: InputDecoration(
        labelText: 'User Type',
        prefixIcon: const Icon(Icons.person_outline, color: Colors.blue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: _userTypes.map((type) =>
          DropdownMenuItem(
            value: type,
            child: Text(type),
          )).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          setState(() => _userType = newValue);
        }
      },
    );
  }

  Widget _buildAssignedRoomsField() {
    return TextField(
      controller: _assignedRoomsController,
      decoration: InputDecoration(
        labelText: "Assigned Rooms (comma-separated)",
        prefixIcon: const Icon(Icons.meeting_room, color: Colors.blue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        helperText: "Enter room numbers separated by commas",
        errorText: _assignedRoomsError,
      ),
      onChanged: (value) {
        setState(() => _assignedRoomsError = null);
      },
    );
  }

  Widget _buildSignUpButton() {
    return _isLoading
        ? const CircularProgressIndicator()
        : ElevatedButton(
      onPressed: _signUp,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
        backgroundColor: Colors.blue.shade700,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: const Text('Sign Up', style: TextStyle(fontSize: 16)),
    );
  }

  Widget _buildLoginLink() {
    return TextButton(
      onPressed: () => Navigator.pop(context),
      child: Text(
        'Already have an account? Login',
        style: TextStyle(color: Colors.blue.shade700),
      ),
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String label,
      IconData icon, {
        bool isPassword = false,
        String? helperText,
      }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        prefixIcon: Icon(icon, color: Colors.blue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      decoration: InputDecoration(
        labelText: "Email",
        prefixIcon: const Icon(Icons.email, color: Colors.blue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        errorText: _emailError,
        suffixIcon: _emailController.text.isNotEmpty
            ? IconButton(
          icon: const Icon(Icons.clear, color: Colors.grey),
          onPressed: () {
            _emailController.clear();
            setState(() => _emailError = null);
          },
        )
            : null,
      ),
      keyboardType: TextInputType.emailAddress,
      onChanged: (value) => setState(() => _emailError = null),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      decoration: InputDecoration(
        labelText: "Password",
        prefixIcon: const Icon(Icons.lock, color: Colors.blue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        errorText: _passwordError,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_passwordController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey),
                onPressed: () {
                  _passwordController.clear();
                  setState(() => _passwordError = null);
                },
              ),
            IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.blue,
              ),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
          ],
        ),
        helperText: "Must include uppercase, lowercase, number & special character",
      ),
      onChanged: (value) => setState(() => _passwordError = null),
    );
  }
}