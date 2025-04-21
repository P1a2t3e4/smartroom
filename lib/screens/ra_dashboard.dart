import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'complaints_tab.dart';
import 'duty_roster.dart';
import 'duty_roster_RA.dart';
import 'update_profile_RA.dart';
import '../services/user_service.dart';
import 'assigned_rooms_page.dart';


void main() {
  runApp(const RADashboard());
}

class RADashboard extends StatefulWidget {
  const RADashboard({super.key});

  @override
  State<RADashboard> createState() => _RADashboardState();
}

class _RADashboardState extends State<RADashboard> {
  int _currentIndex = 0;
  String _userType = '';
  Map<String, dynamic> _userData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          _userData = doc.data() ?? {};
          _userType = _userData['userType'] ?? '';
          _isLoading = false;
        });
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        primaryColor: Colors.indigo.shade600,
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.indigo,
          accentColor: Colors.teal,
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(8),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade600,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('RA Dashboard'),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        drawer: NavigationDrawer(
          userData: _userData,
          onPageSelected: (index) => setState(() => _currentIndex = index),
          currentIndex: _currentIndex,
          onAssignedRoomsSelected: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AssignedRoomsPage(),
              ),
            );
          },
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildCurrentScreen(),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: Colors.indigo.shade600,
          unselectedItemColor: Colors.grey.shade600,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.report_problem), label: 'Complaints'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment), label: 'Duties'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentScreen() {
    final user = FirebaseAuth.instance.currentUser;
    final isRA = user != null && _userType == 'RA';

    switch (_currentIndex) {
      case 0: return DashboardHomeTab(userData: _userData);
      case 1: return const ComplaintsTab();
      case 2:
        return isRA
            ? const RADutyOverviewPage()
            : const DutyRosterPage();
      case 3: return const ProfileTab();
      default: return DashboardHomeTab(userData: _userData);
    }
  }
}

class DashboardHomeTab extends StatelessWidget {
  final Map<String, dynamic> userData;

  const DashboardHomeTab({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final String fullName = userData['fullName'] ?? 'RA Account';
    final String hostelName = userData['hostelName'] ?? 'Not assigned';
    final int assignedRooms = userData['assignedRooms']?.length ?? 0;
    final int totalStudents = userData['totalStudentsAssigned'] ?? 0;
    final int pendingComplaints = userData['pendingComplaints'] ?? 0;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _buildWelcomeCard(context, fullName, hostelName),
        ),
        SliverToBoxAdapter(
          child: _buildQuickStatsCards(context, assignedRooms, totalStudents, pendingComplaints),
        ),
        SliverToBoxAdapter(
          child: _buildActionsSection(context),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard(BuildContext context, String fullName, String hostelName) {
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.indigo.shade800, Colors.blue.shade600],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.shade600,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : 'R',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo[800],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$greeting,',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.apartment, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  hostelName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting(int hour) {
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _buildQuickStatsCards(BuildContext context, int assignedRooms, int totalStudents, int pendingComplaints) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'At a Glance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  context,
                  'Rooms',
                  assignedRooms.toString(),
                  Icons.meeting_room,
                  Colors.teal,
                      () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AssignedRoomsPage(),
                      ),
                    );
                  },
                ),
              ),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Students',
                  totalStudents.toString(),
                  Icons.people,
                  Colors.amber.shade700,
                      () {},
                ),
              ),
              Expanded(
                child: _buildStatCard(
                  context,
                  'Complaints',
                  pendingComplaints.toString(),
                  Icons.report_problem,
                  Colors.red.shade400,
                      () {
                    Navigator.of(context).pushNamed('/complaints');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      BuildContext context,
      String label,
      String value,
      IconData icon,
      Color color,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildActionButton(
                context,
                Icons.apartment,
                'Rooms',
                Colors.teal,
                    () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AssignedRoomsPage(),
                    ),
                  );
                },
              ),


            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context,
      IconData icon,
      String label,
      Color color,
      VoidCallback onTap,
      ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

class NavigationDrawer extends StatelessWidget {
  final Function(int) onPageSelected;
  final VoidCallback onAssignedRoomsSelected;
  final int currentIndex;
  final Map<String, dynamic> userData;

  const NavigationDrawer({
    super.key,
    required this.onPageSelected,
    required this.currentIndex,
    required this.userData,
    required this.onAssignedRoomsSelected,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String fullName = userData['fullName'] ?? 'RA Account';
    final String hostelName = userData['hostelName'] ?? 'Hostel';
    final String email = user?.email ?? '';

    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.grey.shade50, Colors.white],
            stops: const [0.3, 1.0],
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.only(top: 50, bottom: 20),
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.indigo.shade800, Colors.blue.shade600],
                ),
              ),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Text(
                        (fullName.isNotEmpty ? fullName[0] : 'R').toUpperCase(),
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    fullName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          "Resident Assistant",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          hostelName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.email, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        email,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildDrawerItem(context, Icons.dashboard, 'Dashboard', 0),
                  _buildDrawerItem(context, Icons.meeting_room, 'Room Chat', -1,
                      onTap: onAssignedRoomsSelected),
                  _buildDrawerItem(context, Icons.report_problem, 'Complaints', 1),
                  _buildDrawerItem(context, Icons.assignment, 'Duty Roster', 2),
                  _buildDrawerItem(context, Icons.person, 'My Profile', 3),
                  const Divider(thickness: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Log Out', style: TextStyle(color: Colors.red)),
                    onTap: () => _confirmLogout(context),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: const Text(
                'Dormitory Management System v1.0',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
      BuildContext context,
      IconData icon,
      String title,
      int index,
      {VoidCallback? onTap}
      ) {
    final isSelected = currentIndex == index && index >= 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? Colors.indigo.shade50 : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.indigo.shade600 : Colors.grey.shade700,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.indigo.shade600 : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap ?? () {
          onPageSelected(index);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Log Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil('/', (route) => false);
    }
  }
}