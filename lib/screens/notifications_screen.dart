import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  Widget build(BuildContext context) {
    final currentUser = _auth.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view notifications')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_as_unread),
            onPressed: _markAllAsRead,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('notifications')
            .where('userId', isEqualTo: currentUser.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No notifications yet'));
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index].data() as Map<String, dynamic>;
              final isRead = notification['read'] ?? false;

              return ListTile(
                leading: _getNotificationIcon(notification['type']),
                title: Text(
                  notification['title'],
                  style: TextStyle(
                    fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  ),
                ),
                subtitle: Text(notification['body']),
                trailing: Text(
                  _formatTimestamp(notification['timestamp']),
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () => _handleNotificationTap(
                  notifications[index].id,
                  notification,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _getNotificationIcon(String type) {
    switch (type) {
      case 'chat_message':
        return const Icon(Icons.chat);
      case 'new_complaint':
        return const Icon(Icons.warning);
      case 'duty_roster':
        return const Icon(Icons.assignment);
      case 'complaint_status':
        return const Icon(Icons.check_circle);
      default:
        return const Icon(Icons.notifications);
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _handleNotificationTap(String id, Map<String, dynamic> notification) async {
    // Mark as read
    await _firestore.collection('notifications').doc(id).update({'read': true});

    // Handle navigation based on type
    switch (notification['type']) {
      case 'chat_message':
      // Navigate to chat
        break;
      case 'new_complaint':
      // Navigate to complaints
        break;
      case 'duty_roster':
      // Navigate to duty roster
        break;
      case 'complaint_status':
      // Navigate to specific complaint
        break;
    }
  }

  Future<void> _markAllAsRead() async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    final query = await _firestore.collection('notifications')
        .where('userId', isEqualTo: currentUser.uid)
        .where('read', isEqualTo: false)
        .get();

    final batch = _firestore.batch();
    for (var doc in query.docs) {
      batch.update(doc.reference, {'read': true});
    }

    await batch.commit();
  }
}
