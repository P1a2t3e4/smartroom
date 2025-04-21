import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
// Import your AuthService
import 'package:smartroom/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final Function({required String userType}) onLoginSuccess;

  const LoginScreen({Key? key, required this.onLoginSuccess}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AuthService _authService = AuthService(); // Initialize AuthService

  bool _isLoading = false;
  bool _rememberMe = false;
  bool _isPasswordVisible = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Check if user is already signed in
    if (_auth.currentUser != null) {
      _checkUserTypeAndNavigate();
    }
  }

  Future<void> _checkUserTypeAndNavigate() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Force token refresh
        await user.getIdToken(true);

        // Fetch user data
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data() as Map<String, dynamic>;
          final userType = userData['userType'] ?? 'Student';

          // Call onLoginSuccess with the userType
          widget.onLoginSuccess(userType: userType);
        } else {
          setState(() {
            _errorMessage = 'User profile not found. Please contact support.';
          });
          await _auth.signOut();
        }
      }
    } catch (e) {
      print('Error checking user type: $e');
      setState(() {
        _errorMessage = 'Authentication error. Please try again.';
      });
    }
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter both email and password.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Use AuthService for login
      User? user = await _authService.signInWithEmailPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (user != null) {
        // Get the user document
        DocumentSnapshot userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          // Get user type from Firestore
          final userData = userDoc.data() as Map<String, dynamic>;
          final userType = userData['userType'] ?? 'Student';

          // Call onLoginSuccess with the userType
          widget.onLoginSuccess(userType: userType);
        } else {
          throw Exception('User data not found');
        }
      }
    } on AuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
      print('Login error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Rest of your build method remains the same
    return Scaffold(
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
                      // App Logo/Icon
                      Icon(
                        Icons.apartment_rounded,
                        size: 70,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(height: 16),
                      // App Title
                      Text(
                        'Residence Management',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Email Field
                      _buildEmailField(),
                      const SizedBox(height: 16),
                      // Password Field
                      _buildPasswordField(),
                      const SizedBox(height: 8),
                      // Error Message
                      if (_errorMessage != null) ...[
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Remember Me Checkbox
                      _buildRememberMeCheckbox(),
                      const SizedBox(height: 24),
                      // Login Button
                      _buildLoginButton(),
                      const SizedBox(height: 16),
                      // Sign Up Link
                      _buildSignUpLink(),
                      const SizedBox(height: 16),
                      // Forgot Password Link
                      _buildForgotPasswordLink(),
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

  // Rest of your widget methods remain the same...
  Widget _buildEmailField() {
    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        labelText: 'Email',
        prefixIcon: const Icon(Icons.email, color: Colors.blue),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      obscureText: !_isPasswordVisible,
      decoration: InputDecoration(
        labelText: 'Password',
        prefixIcon: const Icon(Icons.lock, color: Colors.blue),
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.blue,
          ),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildRememberMeCheckbox() {
    return Row(
      children: [
        Checkbox(
          value: _rememberMe,
          onChanged: (value) {
            setState(() {
              _rememberMe = value ?? false;
            });
          },
          activeColor: Colors.blue.shade700,
        ),
        const Text('Remember me'),
      ],
    );
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ElevatedButton(
        onPressed: _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue.shade700,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Log In',
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildSignUpLink() {
    return TextButton(
      onPressed: () {
        Navigator.pushNamed(context, '/signUp');
      },
      child: Text(
        'Don\'t have an account? Sign Up',
        style: TextStyle(color: Colors.blue.shade700),
      ),
    );
  }

  Widget _buildForgotPasswordLink() {
    return TextButton(
      onPressed: () {
        // Navigate to forgot password screen
      },
      child: Text(
        'Forgot Password?',
        style: TextStyle(color: Colors.blue.shade700),
      ),
    );
  }
}