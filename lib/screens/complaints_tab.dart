import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/user_service.dart';
import 'group_chat_screen.dart';

class ComplaintsTab extends StatefulWidget {
  const ComplaintsTab({super.key});

  @override
  State<ComplaintsTab> createState() => _ComplaintsTabState();
}

class _ComplaintsTabState extends State<ComplaintsTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  List<Map<String, dynamic>> _complaints = [];
  int _unreadCount = 0;
  final UserService _userService = UserService();

  @override
  void initState() {
    super.initState();
    _fetchComplaints();
  }

  Future<void> _fetchComplaints() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        print('User not authenticated');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Get RA's assigned rooms
      final List<String> assignedRooms = await _userService.getAssignedRooms();
      print('RA assigned rooms: $assignedRooms'); // Debug log

      if (assignedRooms.isEmpty) {
        print('No rooms assigned to this RA');
        setState(() {
          _complaints = [];
          _unreadCount = 0;
          _isLoading = false;
        });
        return;
      }

      // Debug: Print all conflict reports before filtering
      final allReports = await _firestore.collection('conflict_reports').get();
      print('All conflict reports in DB:');
      for (var doc in allReports.docs) {
        print('${doc.id}: ${doc.data()}');
      }

      // Fetch all complaints from assigned rooms
      final snapshot = await _firestore
          .collection('conflict_reports')
          .where('roomNumber', whereIn: assignedRooms)
          .orderBy('timestamp', descending: true)
          .get();

      print('Filtered reports count: ${snapshot.docs.length}'); // Debug log

      final List<Map<String, dynamic>> complaints = [];
      int unreadCount = 0;

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String reporterId = data['reporterId'] as String? ?? '';

        // Get reporter info
        final reporterDoc = await _firestore
            .collection('users')
            .doc(reporterId)
            .get();

        String reporterName = 'Unknown';
        if (reporterDoc.exists) {
          final reporterData = reporterDoc.data();
          if (reporterData != null && reporterData.containsKey('fullName')) {
            reporterName = reporterData['fullName'] as String? ?? 'Unknown';
          }
        }

        final complaint = {
          'id': doc.id,
          'roomNumber': data['roomNumber'] as String? ?? '',
          'reporterName': reporterName,
          'reporterId': reporterId,
          'conflictType': data['conflictType'] as String? ?? '',
          'description': data['description'] as String? ?? '',
          'timestamp': data['timestamp'] as Timestamp? ?? Timestamp.now(),
          'status': data['status'] as String? ?? 'pending',
          'raName': data['raName'] as String? ?? '',
        };

        complaints.add(complaint);

        if (data['status'] == 'pending') {
          unreadCount++;
        }
      }

      setState(() {
        _complaints = complaints;
        _unreadCount = unreadCount;
        _isLoading = false;
      });
    } catch (e) {
      print('Error fetching complaints: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(String complaintId, String status) async {
    try {
      await _firestore
          .collection('conflict_reports')
          .doc(complaintId)
          .update({'status': status});

      _fetchComplaints();
    } catch (e) {
      print('Error updating complaint status: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Complaints'),
        actions: [
          if (_unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: CircleAvatar(
                backgroundColor: Colors.red,
                radius: 12,
                child: Text(
                  _unreadCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchComplaints,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_complaints.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No complaints found',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _complaints.length,
      itemBuilder: (context, index) {
        final complaint = _complaints[index];
        return _buildComplaintCard(complaint, context);
      },
    );
  }

  Widget _buildComplaintCard(Map<String, dynamic> complaint, BuildContext context) {
    final timestamp = complaint['timestamp'] as Timestamp;
    final date = DateFormat('MMM d, yyyy - h:mm a').format(timestamp.toDate());
    final bool isPending = complaint['status'] == 'pending';
    final String roomNumber = complaint['roomNumber'] as String? ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showComplaintDetails(complaint, context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: isPending ? Colors.red.shade100 : Colors.blue.shade100,
                    child: Icon(
                      isPending ? Icons.warning : Icons.check_circle,
                      color: isPending ? Colors.red : Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Room $roomNumber',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Reported by: ${complaint['reporterName']}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(complaint['status'] as String).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getStatusColor(complaint['status'] as String)),
                    ),
                    child: Text(
                      (complaint['status'] as String).toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(complaint['status'] as String),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  complaint['conflictType'] as String,
                  style: TextStyle(
                    color: Colors.blue.shade800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                complaint['description'] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    date,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                    ),
                  ),

                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComplaintDetails(Map<String, dynamic> complaint, BuildContext context) {
    final timestamp = complaint['timestamp'] as Timestamp;
    final date = DateFormat('MMMM d, yyyy - h:mm a').format(timestamp.toDate());
    final bool isPending = complaint['status'] == 'pending';
    final String roomNumber = complaint['roomNumber'] as String? ?? 'Unknown';
    final String status = complaint['status'] as String;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: isPending ? Colors.red.shade100 : Colors.blue.shade100,
                    child: Icon(
                      isPending ? Icons.warning : Icons.check_circle,
                      color: isPending ? Colors.red : Colors.blue,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Room $roomNumber',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Reported by: ${complaint['reporterName']}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(date, style: TextStyle(color: Colors.grey.shade700)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.category, size: 16, color: Colors.blue.shade800),
                        const SizedBox(width: 4),
                        Text(
                          complaint['conflictType'] as String,
                          style: TextStyle(
                            color: Colors.blue.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getStatusColor(status)),
                    ),
                    child: Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: _getStatusColor(status),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Description',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(complaint['description'] as String),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildActionButtons(complaint, context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> complaint, BuildContext context) {
    final String status = complaint['status'] as String;
    final String id = complaint['id'] as String;

    if (status == 'resolved') {
      return Expanded(
        child: ElevatedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.check_circle),
          label: const Text('Done'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              if (status == 'pending') {
                _updateStatus(id, 'viewed');
              } else {
                _updateStatus(id, 'resolved');
              }
              Navigator.pop(context);
            },
            icon: Icon(
              status == 'pending' ? Icons.visibility : Icons.check_circle,
              color: status == 'pending' ? Colors.blue : Colors.green,
            ),
            label: Text(
              status == 'pending' ? 'Mark as Viewed' : 'Mark as Resolved',
              style: TextStyle(
                color: status == 'pending' ? Colors.blue : Colors.green,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: status == 'pending' ? Colors.blue : Colors.green,
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        if (status == 'pending') const SizedBox(width: 12),
        if (status == 'pending')
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                _updateStatus(id, 'resolved');
                Navigator.pop(context);
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Resolve Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.red;
      case 'viewed':
        return Colors.orange;
      case 'resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}