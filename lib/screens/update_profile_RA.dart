import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isLoading = true;
  bool _isSaving = false;
  String _profileImageUrl = '';
  File? _selectedImage;
  String _userType = '';
  String _email = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = _auth.currentUser;
      if (user != null) {
        final doc = await _firestore.collection('users').doc(user.uid).get();

        if (doc.exists) {
          // Safely get data with null checks to handle missing fields
          final data = doc.data() as Map<String, dynamic>? ?? {};

          setState(() {
            _nameController.text = data['fullName'] ?? '';
            _profileImageUrl = data['profileImageUrl'] ?? '';
            _userType = data['userType'] ?? '';
            _email = user.email ?? '';
          });
        } else {
          // Document doesn't exist, create it
          await _firestore.collection('users').doc(user.uid).set({
            'fullName': user.displayName ?? '',
            'profileImageUrl': '',
            'userType': 'user',
            'email': user.email ?? ''
          });

          setState(() {
            _nameController.text = user.displayName ?? '';
            _email = user.email ?? '';
          });
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load profile: $e';
      });
      debugPrint('Error loading profile: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to pick image: $e';
      });
      debugPrint('Error picking image: $e');
    }
  }

  Future<String?> _processImage() async {
    // In a real implementation, you would:
    // 1. Upload the image to a storage service
    // 2. Get the URL for the uploaded image
    // 3. Return that URL

    // For now, we'll just indicate that an image was selected
    if (_selectedImage != null) {
      // Placeholder - you should implement proper image upload
      return "image_selected_but_not_uploaded";
    }
    return _profileImageUrl;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'User not authenticated';
        });
        return;
      }

      // Process image if selected (placeholder for actual image upload)
      String? imageUrl = _profileImageUrl;
      if (_selectedImage != null) {
        imageUrl = await _processImage();
      }

      // Update profile in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'fullName': _nameController.text.trim(),
        'profileImageUrl': imageUrl ?? '',
      });

      setState(() {
        _profileImageUrl = imageUrl ?? '';
        _selectedImage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _error = 'Failed to update profile: $e';
      });
      debugPrint('Error updating profile: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Text(
                  'My Profile',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 30),
                _buildProfileImage(),
                const SizedBox(height: 24),
                _buildEditNameSection(),
                const SizedBox(height: 16),
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                _buildSaveButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage() {
    return GestureDetector(
      onTap: _pickImage,
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.blue.shade400,
                width: 2,
              ),
              image: _selectedImage != null
                  ? DecorationImage(
                image: FileImage(_selectedImage!),
                fit: BoxFit.cover,
              )
                  : _profileImageUrl.isNotEmpty
                  ? DecorationImage(
                image: NetworkImage(_profileImageUrl),
                fit: BoxFit.cover,
              )
                  : null,
            ),
            child: _selectedImage == null && _profileImageUrl.isEmpty
                ? Center(
              child: Text(
                _nameController.text.isNotEmpty
                    ? _nameController.text[0].toUpperCase()
                    : 'U',
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            )
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditNameSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Edit Profile',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                hintText: 'Enter your full name',
                prefixIcon: const Icon(Icons.person),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isSaving
            ? const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : const Text(
          'Save Profile',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}