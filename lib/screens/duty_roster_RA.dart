import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'duty_roster.dart';

class RADutyOverviewPage extends StatefulWidget {
  const RADutyOverviewPage({Key? key}) : super(key: key);

  @override
  State<RADutyOverviewPage> createState() => RADutyOverviewPageState();
}

class RADutyOverviewPageState extends State<RADutyOverviewPage> {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;

  List<String> assignedRooms = [];
  bool isLoading = true;
  String? errorMessage;
  String? hostelName;

  @override
  void initState() {
    super.initState();
    loadAssignedRooms();
  }

  Future<void> loadAssignedRooms() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final user = auth.currentUser;
      if (user == null) {
        setState(() => errorMessage = "Please login to view duties");
        return;
      }

      final userDoc = await firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        setState(() => errorMessage = "User profile not found");
        return;
      }

      final userData = userDoc.data() as Map<String, dynamic>;
      hostelName = userData['hostelName'];
      assignedRooms = List<String>.from(userData['assignedRooms'] ?? []);

      if (assignedRooms.isEmpty) {
        setState(() => errorMessage = "No rooms assigned to you");
      }
    } catch (e) {
      setState(() => errorMessage = "Error loading data: ${e.toString()}");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
              const SizedBox(height: 16),
              Text(
                "Loading your duties...",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Duty Roster Overview"),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.blue[700]!, Colors.blue[500]!],
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue[50]!, Colors.white],
          ),
        ),
        child: errorMessage != null
            ? _buildErrorState()
            : assignedRooms.isEmpty
            ? _buildEmptyState()
            : _buildRoomList(),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 60,
              color: Colors.red[400],
            ),
            const SizedBox(height: 20),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text("Try Again"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
              ),
              onPressed: loadAssignedRooms,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 60,
            color: Colors.blue[300],
          ),
          const SizedBox(height: 20),
          Text(
            "No rooms assigned",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Check back later or contact your supervisor",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Your Assigned Rooms",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.blue[800],
            ),
          ),
        ),
        if (hostelName != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Chip(
              label: Text(
                hostelName!,
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Colors.blue,
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: assignedRooms.length,
            itemBuilder: (context, index) {
              final roomNumber = assignedRooms[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DutyRosterPage(
                          roomNumber: roomNumber,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.meeting_room,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Room $roomNumber",
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (hostelName != null)
                                Text(
                                  hostelName!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: Colors.grey[500],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}