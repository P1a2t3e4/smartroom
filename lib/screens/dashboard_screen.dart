import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'sign_up_screen.dart';
import 'package:path_provider/path_provider.dart';
import 'group_chat_screen.dart';
import 'tasks_screen.dart';
import 'duty_roster.dart';
import 'update_profile.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String userName = "Loading...";
  String userEmail = "Loading...";
  String? roomNumber;
  String? hostelName;
  String? roomId;
  String? profilePicturePath;
  int notifications = 3;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _fetchRoomInfo();
    _fetchProfilePicturePath();
  }

  void _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      user = _auth.currentUser;

      setState(() {
        userName = user?.displayName ?? "User";
        userEmail = user?.email ?? "No email";
      });
    }
  }

  void _fetchRoomInfo() async {
    User? user = _auth.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;

          setState(() {
            roomNumber = userData['roomNumber'];
            hostelName = userData['hostelName'];
            roomId = userData['roomId'];

            if (roomId == null && roomNumber != null && hostelName != null) {
              roomId = "${hostelName!.replaceAll(' ', '')}_$roomNumber";
              _firestore.collection('users').doc(user.uid).update({'roomId': roomId});
            }
          });
        }
      } catch (e) {
        print("Error fetching room info: $e");
      }
    }
  }

  void _fetchProfilePicturePath() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          profilePicturePath = userDoc['profilePicturePath'];
        });
      }
    }
  }

  Future<File?> _loadImageLocally() async {
    if (profilePicturePath != null) {
      final file = File(profilePicturePath!);
      if (await file.exists()) {
        return file;
      }
    }
    return null;
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo[800]!, Colors.blue[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: FutureBuilder<File?>(
                  future: _loadImageLocally(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const CircleAvatar(radius: 35, backgroundColor: Colors.white24);
                    } else if (snapshot.hasData && snapshot.data != null) {
                      return CircleAvatar(
                        radius: 35,
                        backgroundImage: FileImage(snapshot.data!),
                      );
                    } else {
                      return CircleAvatar(
                        radius: 35,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.person, size: 35, color: Colors.white.withOpacity(0.9)),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Welcome back,",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (roomNumber != null && hostelName != null)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.home,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$hostelName • Room $roomNumber',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildStatCard('Pending', '3 Tasks', Icons.pending_actions, () {
                // Navigate to tasks screen and manually select the first tab (pending tasks)
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TasksPage()),
                ).then((_) {
                  // If needed, you can add logic here when returning from TasksScreen
                });
              }),
              const SizedBox(width: 12),
              _buildStatCard('Completed', '12 Tasks', Icons.check_circle, () {
                // Navigate to tasks screen and manually select the completed tasks tab
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TasksPage()),
                ).then((_) {
                  // If needed, you can add logic here when returning from TasksScreen
                });
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
          ),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            children: [
              _buildActionButton(Icons.report_problem, 'Report Issue', Colors.red[700]!, () {
                Navigator.pushNamed(context, '/conflict');
              }),
              _buildActionButton(Icons.chat_bubble_outline, 'Room Chat', Colors.blue[700]!, () {
                _navigateToRoomChat();
              }),
              _buildActionButton(Icons.star_rate, 'Rate RA', Colors.amber[700]!, () {
                Navigator.pushNamed(context, '/ra_ratings');
              }),
              _buildActionButton(Icons.handshake, 'Agreement', Colors.green[700]!, () {
                Navigator.pushNamed(context, '/rm_agreement');
              }),
            ],
          ),
        ],
      ),
    );
  }

  void _navigateToRoomChat() {
    _fetchRoomInfo();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (roomNumber != null && roomNumber!.isNotEmpty &&
          hostelName != null && hostelName!.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupChatScreen(
              roomId: roomNumber!,
              hostelName: hostelName!,
              roomNumber: roomNumber!,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Room information not found or incomplete."),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });
  }

  Widget _buildActionButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, size: 28),
            color: Colors.indigo[800],
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: Icon(Icons.notifications_outlined, color: Colors.indigo[800], size: 28),
                onPressed: () {},
              ),
              if (notifications > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    child: Text(
                      notifications.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: Drawer(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo[900]!, Colors.blue[700]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo[800]!, Colors.blue[600]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: FutureBuilder<File?>(
                        future: _loadImageLocally(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const CircleAvatar(
                              radius: 35,
                              backgroundColor: Colors.white24,
                            );
                          } else if (snapshot.hasData && snapshot.data != null) {
                            return CircleAvatar(
                              radius: 35,
                              backgroundImage: FileImage(snapshot.data!),
                            );
                          } else {
                            return CircleAvatar(
                              radius: 35,
                              backgroundColor: Colors.white24,
                              child: Icon(Icons.person, size: 40, color: Colors.white),
                            );
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      userEmail,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              _buildDrawerItem(Icons.person, 'Update Profile', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UpdateProfileScreen()),
                ).then((value) {
                  if (value == true) {
                    setState(() {
                      _loadUserData();
                      _fetchProfilePicturePath();
                      _fetchRoomInfo();
                    });
                  }
                });
              }),
              _buildDrawerItem(Icons.report_problem_outlined, 'Report Conflict', () {
                Navigator.pushNamed(context, '/conflict');
              }),
              _buildDrawerItem(Icons.star_outline, 'Rate RA', () {
                Navigator.pushNamed(context, '/ra_ratings');
              }),
              _buildDrawerItem(Icons.article_outlined, 'Roommate Agreement', () {
                Navigator.pushNamed(context, '/rm_agreement');
              }),
              _buildDrawerItem(Icons.chat_bubble_outline, 'Group Chat', () {
                _navigateToRoomChat();
              }),
              _buildDrawerItem(Icons.task_alt, 'Tasks', () {
                Navigator.pushNamed(context, '/tasks');
              }),
              _buildDrawerItem(Icons.people_outline, 'Duty Roster', () {
                Navigator.pushNamed(context, '/duty_roster');
              }),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Divider(color: Colors.white38),
              ),
              _buildDrawerItem(Icons.logout, 'Log Out', () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacementNamed(context, '/');
              }),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            _buildQuickActions(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        hoverColor: Colors.white.withOpacity(0.1),
      ),
    );
  }
}