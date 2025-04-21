import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UpdateProfileScreen extends StatefulWidget {
  const UpdateProfileScreen({super.key});

  @override
  State createState() => _UpdateProfileScreenState();
}

class _UpdateProfileScreenState extends State<UpdateProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
  final _formKey = GlobalKey<FormState>();
  File? _imageFile;
  String? _currentName;
  bool _isLoading = false;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    final user = _auth.currentUser;
    if (user != null) {
      // Get user data from Firestore
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userData.exists) {
        setState(() {
          _currentName = userData.data()?['name'] ?? user.displayName ?? 'Student';
          _nameController.text = _currentName!;
        });

        // Check if there's a stored image path
        final imagePath = userData.data()?['profilePicturePath'];
        if (imagePath != null) {
          final file = File(imagePath);
          if (await file.exists()) {
            setState(() {
              _imageFile = file;
            });
          }
        }
      }
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 400,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _takePicture() async {
    final pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 400,
    );

    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<String> _saveImageLocally(File imageFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final user = _auth.currentUser;
    final imagePath = '${directory.path}/profile_${user?.uid ?? 'user'}.jpg';
    await imageFile.copy(imagePath);
    return imagePath;
  }

  Future<void> _saveProfileToFirestore(String? imagePath) async {
    final user = _auth.currentUser;
    if (user != null) {
      final updateData = <String, dynamic>{
        'name': _nameController.text,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (imagePath != null) {
        updateData['profilePicturePath'] = imagePath;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updateData);

      // Update display name in Firebase Auth
      await user.updateDisplayName(_nameController.text);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Profile updated successfully!"),
          backgroundColor: Colors.green,
        ),
      );

      // Notify the app that profile has been updated
      // You would implement a state management solution here
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? imagePath;
      if (_imageFile != null) {
        imagePath = await _saveImageLocally(_imageFile!);
      }

      await _saveProfileToFirestore(imagePath);

      if (!mounted) return;
      Navigator.pop(context, true); // Return true to indicate profile updated
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error updating profile: $e"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Update Profile"),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).primaryColor,
                          width: 3,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 65,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: _imageFile != null
                            ? FileImage(_imageFile!)
                            : null,
                        child: _imageFile == null
                            ? Icon(
                          Icons.person,
                          size: 65,
                          color: Colors.grey[800],
                        )
                            : null,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                        ),
                        onSelected: (value) {
                          if (value == 'gallery') {
                            _pickImage();
                          } else if (value == 'camera') {
                            _takePicture();
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'gallery',
                            child: Row(
                              children: [
                                Icon(Icons.photo_library),
                                SizedBox(width: 10),
                                Text('Gallery'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'camera',
                            child: Row(
                              children: [
                                Icon(Icons.camera_alt),
                                SizedBox(width: 10),
                                Text('Camera'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter your full name',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Theme.of(context).primaryColor,
                        width: 2,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _updateProfile,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "SAVE CHANGES",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}