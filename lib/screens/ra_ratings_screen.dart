import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RaRatingScreen extends StatefulWidget {
  const RaRatingScreen({super.key});

  @override
  _RaRatingScreenState createState() => _RaRatingScreenState();
}

class _RaRatingScreenState extends State<RaRatingScreen> {
  // Maps to store ratings for each category
  final Map<String, int> _ratings = {
    'overall': 0,
    'approachability': 0,
    'communityBuilding': 0,
    'support': 0,
    'conflictResolution': 0,
    'policyEnforcement': 0,
  };

  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  // Function to handle star selection for a specific category
  void _onStarTap(String category, int index) {
    setState(() {
      _ratings[category] = index + 1;
    });
  }

  // Function to submit rating to Firestore
  Future<void> _submitRating() async {
    if (_ratings['overall'] == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an overall rating!')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Updated to match your database structure
        await FirebaseFirestore.instance.collection('ratings').add({
          'userId': user.uid,
          'raId': 'RA_1234', // Replace with dynamic RA ID
          'rating': _ratings['overall'], // This is the single overall rating shown in your DB
          'comment': _commentController.text.trim(),
          'timestamp': FieldValue.serverTimestamp(),
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rating submitted successfully!')),
        );

        // Reset ratings and comment after submission
        setState(() {
          _ratings.updateAll((key, value) => 0);
          _commentController.clear();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting rating: $e')),
      );
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  // Widget to create star rating row for a category without a heading
  Widget _buildRatingCategory(String category, String description) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            spreadRadius: 1,
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Only show the description text
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black87.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () => _onStarTap(category, index),
                child: Icon(
                  index < _ratings[category]! ? Icons.star : Icons.star_border,
                  size: 26,
                  color: Colors.amber,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'RA Rating',
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.blue[600],
        elevation: 0,
      ),
      // Content area
      body: Column(
        children: [
          // Header section (fixed at top)
          Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 16),
            color: Colors.blue[50],
            child: Column(
              children: [
                Text(
                  'Rate Your RA',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Please rate your RA in the following categories:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.blue[900]!.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Scrollable content
          Expanded(
            child: Container(
              color: Colors.blue[50],
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80), // Added bottom padding
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _buildRatingCategory(
                      'overall',
                      'Your overall impression of your RA'
                  ),

                  _buildRatingCategory(
                      'approachability',
                      'The RA is friendly, responds quickly, and keeps residents informed'
                  ),

                  _buildRatingCategory(
                      'communityBuilding',
                      'The RA organizes fun activities and helps residents connect'
                  ),

                  _buildRatingCategory(
                      'support',
                      'The RA offers helpful advice and knows where to get assistance'
                  ),

                  _buildRatingCategory(
                      'conflictResolution',
                      'The RA handles disputes fairly and solves problems well'
                  ),

                  _buildRatingCategory(
                      'policyEnforcement',
                      'The RA explains rules clearly and ensures the hall is safe'
                  ),

                  // Comment Section
                  Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Additional Comments',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[600],
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _commentController,
                          decoration: InputDecoration(
                            hintText: 'Share your thoughts (optional)',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[200]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[200]!),
                            ),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),

                  // Submit Button - Now shown within the scrollable area
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitRating,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[600],
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 2,
                      ),
                      child: _isSubmitting
                          ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Text(
                        'Submit Rating',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  // Add extra padding at the bottom to ensure scrollability
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),

      // Bottom bar with feedback message
      bottomNavigationBar: Container(
        color: Colors.blue[600],
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: const Text(
          'We value your feedback!',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}