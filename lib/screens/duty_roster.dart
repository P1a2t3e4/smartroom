import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class DutyRosterPage extends StatefulWidget {
  final String? roomNumber; // Add this to accept room number parameter

  const DutyRosterPage({Key? key, this.roomNumber}) : super(key: key);

  @override
  State<DutyRosterPage> createState() => _DutyRosterPageState();
}

class _DutyRosterPageState extends State<DutyRosterPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _roommates = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _roomId;
  String? _userType;
  String? _hostelName;
  String? _roomNumber;

  @override
  void initState() {
    super.initState();
    _initializeRosterPage();
  }

  Future<void> _initializeRosterPage() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) {
        setState(() => _errorMessage = "Please login to view duties");
        return;
      }

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        setState(() => _errorMessage = "User profile not found");
        return;
      }

      _userData = userDoc.data();
      _userType = _userData?['userType'];
      _hostelName = _userData?['hostelName'];

      // Use the passed roomNumber if available, otherwise use the RA's own room
      _roomNumber = widget.roomNumber ?? _userData?['roomNumber'];

      if (_hostelName == null || _roomNumber == null) {
        setState(() => _errorMessage = "Room information missing");
        return;
      }

      _roomId = '$_hostelName-$_roomNumber';
      await _loadRoommates(_hostelName!, _roomNumber!);
    } catch (e) {
      setState(() => _errorMessage = "Error loading data: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadRoommates(String hostelName, String roomNumber) async {
    try {
      final query = _firestore.collection('users')
          .where('hostelName', isEqualTo: hostelName)
          .where('roomNumber', isEqualTo: roomNumber)
          .where('userType', isEqualTo: 'Student');

      final snapshot = await query.get();

      setState(() {
        _roommates = snapshot.docs
            .where((doc) => doc.id != _auth.currentUser?.uid)
            .map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            ...data,
            'id': doc.id,
            'fullName': data['fullName'] ?? 'Roommate',
          };
        }).toList();
      });
    } catch (e) {
      debugPrint("Error loading roommates: $e");
      setState(() => _errorMessage = "Error loading roommates");
    }
  }

  Stream<QuerySnapshot> _getDutiesStream() {
    if (_roomId == null) return const Stream.empty();
    return _firestore.collection('dutyRoster')
        .where('roomId', isEqualTo: _roomId)
        .orderBy('dueDate', descending: false)
        .snapshots();
  }

  Future<void> _createNewDuty() async {
    if (_userType != 'Student') {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Only students can create duties")));
      return;
    }

    final titleController = TextEditingController();
    Set<String> selectedUsers = {};
    String scheduleType = 'Weekly';
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                  minWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              "New Duty Assignment",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            TextField(
                              controller: titleController,
                              decoration: InputDecoration(
                                labelText: "Duty Title",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                filled: true,
                                fillColor: Colors.grey[100],
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              "Assign to:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: Column(
                                children: [
                                  CheckboxListTile(
                                    title: const Text("Assign to me"),
                                    value: selectedUsers.contains(_auth.currentUser?.uid),
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          selectedUsers.add(_auth.currentUser!.uid);
                                        } else {
                                          selectedUsers.remove(_auth.currentUser!.uid);
                                        }
                                      });
                                    },
                                    controlAffinity: ListTileControlAffinity.leading,
                                  ),
                                  ..._roommates.map((roommate) => CheckboxListTile(
                                    title: Text(roommate['fullName'] ?? 'Roommate'),
                                    value: selectedUsers.contains(roommate['id']),
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          selectedUsers.add(roommate['id']);
                                        } else {
                                          selectedUsers.remove(roommate['id']);
                                        }
                                      });
                                    },
                                    controlAffinity: ListTileControlAffinity.leading,
                                  )),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              "Schedule:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: DropdownButton<String>(
                                value: scheduleType,
                                isExpanded: true,
                                underline: const SizedBox(),
                                icon: const Icon(Icons.arrow_drop_down),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                ),
                                items: ['One-time', 'Daily', 'Weekly', 'Monthly']
                                    .map((type) => DropdownMenuItem(
                                  value: type,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text(type),
                                  ),
                                ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() => scheduleType = value!);
                                },
                              ),
                            ),
                            const SizedBox(height: 24),
                            ListTile(
                              title: const Text("Due Date"),
                              subtitle: Text(DateFormat.yMd().format(selectedDate)),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: () async {
                                final pickedDate = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (pickedDate != null) {
                                  setState(() => selectedDate = pickedDate);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[700],
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                            child: const Text("CANCEL"),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () async {
                              if (titleController.text.isEmpty || selectedUsers.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text("Please fill all required fields")));
                                return;
                              }

                              await _saveDuty(
                                titleController.text,
                                selectedUsers.toList(),
                                scheduleType,
                                selectedDate,
                              );
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text("CREATE DUTY"),
                          ),
                        ],
                      ),
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



  Future<void> _saveDuty(
      String title,
      List<String> assignedTo,
      String scheduleType,
      DateTime dueDate,
      ) async {
    try {
      final batch = _firestore.batch();
      final currentUser = _auth.currentUser;

      // Create a map of user IDs to their names for reference
      Map<String, String> userNames = {};
      for (var roommate in _roommates) {
        userNames[roommate['id']] = roommate['fullName'] ?? 'Roommate';
      }

      // Add current user to the map
      userNames[currentUser?.uid ?? ''] = _userData?['fullName'] ?? 'You';

      for (final userId in assignedTo) {
        final isCurrentUser = userId == currentUser?.uid;
        final userName = isCurrentUser ? "You" : userNames[userId] ?? 'Roommate';

        // Create duty in dutyRoster collection
        final dutyDocRef = _firestore.collection('dutyRoster').doc();
        batch.set(dutyDocRef, {
          'title': title,
          'roomId': _roomId,
          'hostelName': _hostelName,
          'roomNumber': _roomNumber,
          'createdBy': currentUser?.uid,
          'createdByName': _userData?['fullName'] ?? 'Unknown',
          'assignedTo': userId,
          'assignedUserName': userName,
          'dueDate': Timestamp.fromDate(dueDate),
          'createdAt': FieldValue.serverTimestamp(),
          'isCompleted': false,
          'scheduleType': scheduleType.toLowerCase(),
          'isCurrentUser': isCurrentUser,
        });

        // Create corresponding task in tasks collection with proper status
        final taskDocRef = _firestore.collection('tasks').doc();
        batch.set(taskDocRef, {
          'assignedTo': userId,
          'assignedToName': userNames[userId] ?? 'Roommate',
          'taskDescription': "Duty: $title",
          'roomNumber': _roomNumber,
          'hostelName': _hostelName,
          'status': "Upcoming", // Start as Upcoming
          'priority': "Medium", // Default priority
          'dueDate': Timestamp.fromDate(dueDate),
          'createdAt': FieldValue.serverTimestamp(),
          'completedAt': null,
          'reminderSent': false,
          'sourceType': 'duty',
          'sourceId': dutyDocRef.id, // Reference to the duty for syncing status
          'createdBy': currentUser?.uid,
          'createdByName': _userData?['fullName'] ?? 'Unknown',
          'scheduleType': scheduleType.toLowerCase(),
        });
      }

      await batch.commit();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Duties created successfully and added to tasks")));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error creating duties: ${e.toString()}")));
    }
  }

  Widget _buildDutyCard(DocumentSnapshot duty) {
    final data = duty.data() as Map<String, dynamic>;
    final isCompleted = data['isCompleted'] ?? false;
    final dueDate = (data['dueDate'] as Timestamp?)?.toDate();
    final isOverdue = dueDate != null && dueDate.isBefore(DateTime.now()) && !isCompleted;
    final assignedToMe = data['isCurrentUser'] == true;
    final scheduleType = data['scheduleType'] ?? 'one-time';

    return Card(
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isCompleted ? Icons.check_circle : Icons.pending_actions,
                  color: isCompleted ? Colors.green : isOverdue ? Colors.red : Colors.blue,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    data['title'] ?? "Untitled Duty",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (assignedToMe && scheduleType != 'one-time')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      scheduleType == 'weekly'
                          ? 'Weekly'
                          : scheduleType == 'monthly'
                          ? 'Monthly'
                          : 'Daily',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(assignedToMe ? "You" : data['assignedUserName'] ?? "Roommate"),
                  avatar: const Icon(Icons.person, size: 18),
                  backgroundColor: Colors.grey[100],
                ),
                if (dueDate != null)
                  Chip(
                    label: Text(DateFormat.MMMd().add_jm().format(dueDate)),
                    avatar: const Icon(Icons.calendar_today, size: 18),
                    backgroundColor: Colors.grey[100],
                  ),
                if (isCompleted)
                  Chip(
                    label: const Text("Completed"),
                    avatar: const Icon(Icons.check, size: 18, color: Colors.green),
                    backgroundColor: Colors.green[50],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _toggleCompletion(duty),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isCompleted ? Colors.green : Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(isCompleted ? "Completed" : "Mark Complete"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleCompletion(DocumentSnapshot duty) async {
    try {
      final data = duty.data() as Map<String, dynamic>;
      final isCompleted = data['isCompleted'] ?? false;
      final assignedTo = data['assignedTo'] as String?;
      final newIsCompleted = !isCompleted;

      if (assignedTo == null) return;

      // Start a batch write
      final batch = _firestore.batch();

      // Update the duty status
      batch.update(_firestore.collection('dutyRoster').doc(duty.id), {
        'isCompleted': newIsCompleted,
        'completedAt': newIsCompleted ? FieldValue.serverTimestamp() : null,
      });

      // Find and update corresponding task
      final tasksSnapshot = await _firestore.collection('tasks')
          .where('sourceType', isEqualTo: 'duty')
          .where('sourceId', isEqualTo: duty.id)
          .get();

      for (var taskDoc in tasksSnapshot.docs) {
        batch.update(_firestore.collection('tasks').doc(taskDoc.id), {
          'status': newIsCompleted ? 'Completed' : 'Upcoming',
          'completedAt': newIsCompleted ? FieldValue.serverTimestamp() : null,
        });
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newIsCompleted
                ? "Duty marked as completed"
                : "Duty marked as incomplete"),
            backgroundColor: newIsCompleted ? Colors.green : Colors.blue,
          )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating duty: ${e.toString()}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Duty Roster",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeRosterPage,
          ),
        ],
      ),
      floatingActionButton: _userType == 'Student'
          ? FloatingActionButton(
        onPressed: _createNewDuty,
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // Fixed header section
            if (_userData != null)
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.home_work, color: Colors.blue),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Room ${_userData?['roomNumber']}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          "${_roommates.length + 1} roommates",
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 16,
                  ),
                ),
              ),
            // Scrollable content section
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getDutiesStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        "Error: ${snapshot.error}",
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.assignment, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text(
                            "No duties assigned yet",
                            style: TextStyle(fontSize: 16),
                          ),
                          if (_userType == 'Student') ...[
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _createNewDuty,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text("Create First Duty"),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  // Use ListView.builder within a SingleChildScrollView for proper scrolling
                  return SingleChildScrollView(
                    child: ListView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 80), // Add padding at bottom for FAB
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        return _buildDutyCard(snapshot.data!.docs[index]);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}