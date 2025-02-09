import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue[800],
        elevation: 4,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[50]!, Colors.blue[100]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildNotificationCard(
              title: 'New Task Assigned',
              message: 'Clean the common room',
              icon: Icons.assignment_turned_in,
              color: Colors.green[400],
            ),
            _buildNotificationCard(
              title: 'Feedback Reviewed',
              message: 'Your feedback has been reviewed',
              icon: Icons.feedback_outlined,
              color: Colors.blue[400],
            ),
            _buildNotificationCard(
              title: 'Conflict Resolved',
              message: 'Conflict report status: Resolved',
              icon: Icons.check_circle_outline,
              color: Colors.amber[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard({
    required String title,
    required String message,
    required IconData icon,
    required Color? color,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          child: Icon(
            icon,
            color: Colors.white,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          message,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          color: Colors.red[400],
          onPressed: () {
            // Add delete notification logic here
          },
        ),
      ),
    );
  }
}
