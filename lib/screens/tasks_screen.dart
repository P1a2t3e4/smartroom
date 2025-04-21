import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class TasksPage extends StatefulWidget {
  const TasksPage({Key? key}) : super(key: key);

  @override
  State<TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<TasksPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  late TabController _tabController; // Marked as late since we initialize it in initState
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _errorMessage;

  final List<String> _tabTitles = ["Upcoming", "Pending", "Completed"];

  @override
  void initState() {
    super.initState();
    // Initialize tab controller with proper length and vsync
    _tabController = TabController(
      length: _tabTitles.length,
      vsync: this,
    );
    _loadUserData();
  }

  @override
  void dispose() {
    // Always dispose controllers when done
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _errorMessage = "Please login to view tasks");
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        setState(() => _errorMessage = "User profile not found");
        return;
      }

      setState(() {
        _userData = userDoc.data();
      });
    } catch (e) {
      setState(() => _errorMessage = "Error loading user data: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Stream<QuerySnapshot> _getTasksStream(String status) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return const Stream.empty();

    return _firestore.collection('tasks')
        .where('assignedTo', isEqualTo: userId)
        .where('status', isEqualTo: status)
        .orderBy('dueDate', descending: false)
        .snapshots();
  }

  Future<void> _updateTaskStatus(String taskId, String newStatus, String? sourceType, String? sourceId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final batch = _firestore.batch();

    // Update task status
    final taskRef = _firestore.collection("tasks").doc(taskId);
    batch.update(taskRef, {
      "status": newStatus,
      "completedAt": newStatus == "Completed" ? FieldValue.serverTimestamp() : null,
    });

    // If this task came from a duty, also update the duty's status
    if (sourceType == 'duty' && sourceId != null) {
      final dutyRef = _firestore.collection("dutyRoster").doc(sourceId);
      final dutyDoc = await dutyRef.get();

      if (dutyDoc.exists) {
        batch.update(dutyRef, {
          "isCompleted": newStatus == "Completed",
          "completedAt": newStatus == "Completed" ? FieldValue.serverTimestamp() : null,
        });
      }
    }

    await batch.commit();
  }

  Future<void> _showAddTaskDialog(BuildContext context) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final descriptionController = TextEditingController();
    final roomController = TextEditingController();
    DateTime dueDate = DateTime.now().add(const Duration(days: 1));

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Add New Task"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: "Task Description",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: roomController,
                    decoration: const InputDecoration(
                      labelText: "Room Number (optional)",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: const Text("Due Date"),
                    subtitle: Text(DateFormat.yMd().format(dueDate)),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: dueDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (pickedDate != null) {
                        setState(() => dueDate = pickedDate);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (descriptionController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter a task description')),
                      );
                      return;
                    }

                    try {
                      final userDoc = await _firestore.collection('users').doc(user.uid).get();
                      final userData = userDoc.data();

                      await _firestore.collection("tasks").add({
                        "assignedTo": user.uid,
                        "assignedToName": user.displayName ?? userData?['fullName'] ?? 'User',
                        "taskDescription": descriptionController.text,
                        "roomNumber": roomController.text.isNotEmpty
                            ? roomController.text
                            : userData?['roomNumber'] ?? '',
                        "hostelName": userData?['hostelName'] ?? '',
                        "status": "Upcoming",
                        "dueDate": Timestamp.fromDate(dueDate),
                        "createdAt": Timestamp.now(),
                        "completedAt": null,
                        "reminderSent": false,
                        "sourceType": "manual",
                        "sourceId": null
                      });
                      Navigator.pop(context);

                      _tabController.animateTo(0); // Switch to Upcoming tab
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error creating task: $e')),
                      );
                    }
                  },
                  child: const Text("Add Task"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Center(child: Text(_errorMessage!)),
      );
    }

    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view tasks')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Tasks", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blueAccent,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: "Upcoming"),
            Tab(text: "Pending"),
            Tab(text: "Completed"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTaskList("Upcoming"),
          _buildTaskList("Pending"),
          _buildTaskList("Completed"),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTaskDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  Widget _buildTaskList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getTasksStream(status),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'No ${status.toLowerCase()} tasks',
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final task = snapshot.data!.docs[index];
            final data = task.data() as Map<String, dynamic>;
            final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
            final completedAt = (data['completedAt'] as Timestamp?)?.toDate();
            final isOverdue = dueDate != null &&
                dueDate.isBefore(DateTime.now()) &&
                status != 'Completed';

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            data['taskDescription'] ?? 'No description',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              decoration: status == 'Completed'
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                        if (data['sourceType'] == 'duty')
                          const Icon(Icons.assignment, size: 16, color: Colors.blue),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (data['roomNumber'] != null && data['roomNumber'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.room, size: 16),
                            const SizedBox(width: 4),
                            Text('Room ${data['roomNumber']}'),
                          ],
                        ),
                      ),
                    if (dueDate != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16),
                            const SizedBox(width: 4),
                            Text(DateFormat.yMd().add_jm().format(dueDate)),
                            if (isOverdue)
                              Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: Text(
                                  'Overdue',
                                  style: TextStyle(
                                    color: Colors.red[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    if (completedAt != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, size: 16, color: Colors.green),
                            const SizedBox(width: 4),
                            Text('Completed on ${DateFormat.yMd().format(completedAt)}'),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (status == 'Upcoming')
                          TextButton(
                            onPressed: () => _updateTaskStatus(
                              task.id,
                              'Pending',
                              data['sourceType'],
                              data['sourceId'],
                            ),
                            child: const Text('Start Task'),
                          ),
                        if (status == 'Pending')
                          TextButton(
                            onPressed: () => _updateTaskStatus(
                              task.id,
                              'Completed',
                              data['sourceType'],
                              data['sourceId'],
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.green,
                            ),
                            child: const Text('Mark Complete'),
                          ),
                        if (status == 'Completed')
                          TextButton(
                            onPressed: () => _updateTaskStatus(
                              task.id,
                              'Pending',
                              data['sourceType'],
                              data['sourceId'],
                            ),
                            child: const Text('Reopen Task'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}