import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class GroupChatScreen extends StatefulWidget {
  final String roomId;
  final String hostelName;
  final String roomNumber;

  const GroupChatScreen({
    Key? key,
    required this.roomId,
    required this.hostelName,
    required this.roomNumber,
  }) : super(key: key);

  @override
  _GroupChatScreenState createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  String? _error;
  bool _isGroupActive = false;
  Map<String, dynamic>? _raDetails;
  String? _roomId;
  StreamSubscription<DocumentSnapshot>? _roomSubscription;
  StreamSubscription<DocumentSnapshot>? _groupChatSubscription;
  bool _showRoomInfo = false;
  List<Map<String, dynamic>> _roomMembers = [];
  bool _isCurrentUserRA = false;
  String? _previousRaId;
  bool _forceRefresh = false;

  @override
  void initState() {
    super.initState();
    _roomId = widget.roomId;
    print("GroupChatScreen initialized with roomId: $_roomId");
    _initializeChat();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _roomSubscription?.cancel();
    _groupChatSubscription?.cancel();
    super.dispose();
  }

  void _setupRoomListener() {
    if (_roomId == null || _roomId!.isEmpty) {
      print("Cannot setup room listener: roomId is null or empty");
      return;
    }

    _roomSubscription?.cancel();

    _roomSubscription = _firestore
        .collection('rooms')
        .doc(_roomId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final String? newRaId = data['ra_id'] as String?;
        final List<String> residents = List<String>.from(data['residents'] ?? []);

        print("Room listener triggered. RA ID: $newRaId, Residents count: ${residents.length}");

        if (newRaId != _previousRaId) {
          _previousRaId = newRaId;
          debugPrint('RA assignment changed in room document, refreshing chat data');

          setState(() {
            _forceRefresh = true;
          });

          await _initializeChat();

          // Force refresh when RA is changed
          if (newRaId != null) {
            await _refreshWhenRAAssigned();
          }
        }

        // Force reload of members when room data changes
        _fetchAllRoommates(data);
      }
    }, onError: (error) {
      print("Error in room listener: $error");
    });
  }

  Future<void> _fetchAllRoommates(Map<String, dynamic> roomData) async {
    try {
      // Get resident IDs from room document
      final List<String> roommateIds = List<String>.from(roomData['residents'] ?? []);
      final String? raId = roomData['ra_id'] as String?;

      // Make sure RA is included in the list
      if (raId != null && !roommateIds.contains(raId)) {
        roommateIds.add(raId);
      }

      print("Roommate IDs from room document: $roommateIds, RA ID: $raId");

      if (roommateIds.isEmpty) return;

      if (_roomId != null) {
        // First get the current group chat document
        final groupChatDoc = await _firestore.collection('groupChats').doc(_roomId).get();
        if (groupChatDoc.exists) {
          final groupChatData = groupChatDoc.data() as Map<String, dynamic>;
          final List<String> existingMembers = List<String>.from(groupChatData['members'] ?? []);

          // Combine existing members with new roommates
          final Set<String> allMembers = {...existingMembers, ...roommateIds};

          // Make sure RA is included in the members list
          if (raId != null && !allMembers.contains(raId)) {
            allMembers.add(raId);
          }

          print("Updating group chat with all members: ${allMembers.toList()}");

          // Update with complete member list
          await _firestore.collection('groupChats').doc(_roomId).update({
            'members': allMembers.toList(),
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching roommates: $e');
    }
  }

  void _setupGroupChatListener() {
    if (_roomId == null || _roomId!.isEmpty) {
      print("Cannot setup group chat listener: roomId is null or empty");
      return;
    }

    _groupChatSubscription?.cancel();

    _groupChatSubscription = _firestore
        .collection('groupChats')
        .doc(_roomId)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final String? raId = data['ra_id'] as String?;
        final bool isActive = data['isActive'] ?? false;

        print("Group chat listener: RA ID = $raId, Is Active = $isActive");

        if (raId != null && (_raDetails == null || _raDetails!['uid'] != raId)) {
          await _fetchRADetails(raId);
        }

        if (isActive != _isGroupActive) {
          setState(() {
            _isGroupActive = isActive;
          });
        }

        final String currentUserId = _auth.currentUser?.uid ?? '';
        setState(() {
          _isCurrentUserRA = raId == currentUserId;
        });

        _loadGroupMembers(data);

        bool raJoinedNotificationSent = data['raJoinedNotificationSent'] ?? false;
        if (raId != null && !raJoinedNotificationSent && _raDetails != null) {
          await _sendRAJoinNotification();

          await _firestore.collection('groupChats').doc(_roomId).update({
            'raJoinedNotificationSent': true,
            'isActive': true,
          });

          setState(() {
            _isGroupActive = true;
          });
        }
      }
    }, onError: (error) {
      print("Error in group chat listener: $error");
    });
  }

  Future<void> _loadGroupMembers(Map<String, dynamic> groupChatData) async {
    try {
      final List<String> memberIds = List<String>.from(groupChatData['members'] ?? []);
      final String? raId = groupChatData['ra_id'] as String?;

      // Make sure the RA ID is included in the members list we're processing
      if (raId != null && !memberIds.contains(raId)) {
        memberIds.add(raId);  // Explicitly add RA ID if it's missing
      }

      print("Loading members from group chat data. Total members: ${memberIds.length}");
      print("Member IDs with RA included: $memberIds");

      List<Map<String, dynamic>> members = [];

      for (String memberId in memberIds) {
        final userDoc = await _firestore.collection('users').doc(memberId).get();
        if (userDoc.exists) {
          members.add({
            'uid': memberId,
            'fullName': userDoc.data()?['fullName'] ?? 'Unknown',
            'email': userDoc.data()?['email'] ?? '',
            'phoneNumber': userDoc.data()?['phoneNumber'] ?? '',
            'isRA': raId == memberId,
          });
        }
      }

      // Double check if RA is in the list - if not, try to add them separately
      if (raId != null && !members.any((member) => member['uid'] == raId)) {
        final raDoc = await _firestore.collection('users').doc(raId).get();
        if (raDoc.exists) {
          members.add({
            'uid': raId,
            'fullName': raDoc.data()?['fullName'] ?? 'Unknown RA',
            'email': raDoc.data()?['email'] ?? '',
            'phoneNumber': raDoc.data()?['phoneNumber'] ?? '',
            'isRA': true,
          });
        }
      }

      setState(() {
        _roomMembers = members;
      });

      print("Loaded ${members.length} members successfully");

      // Update the database to ensure consistency
      if (raId != null) {
        await _firestore.collection('groupChats').doc(_roomId).update({
          'members': FieldValue.arrayUnion([raId]),
        });
      }
    } catch (e) {
      debugPrint('Error loading group members: $e');
    }
  }

  Future<void> _fetchRADetails(String raId) async {
    try {
      print("Fetching RA details for ID: $raId");

      if (raId.isEmpty) {
        print("Error: RA ID is empty");
        setState(() {
          _raDetails = null;
        });
        return;
      }

      final raDoc = await _firestore.collection('users').doc(raId).get();

      if (raDoc.exists) {
        final raData = raDoc.data() as Map<String, dynamic>;
        print("RA document data: $raData");

        setState(() {
          _raDetails = {
            'uid': raId,
            'fullName': raData['fullName'] ?? 'Unknown RA',
            'email': raData['email'] ?? '',
            'phoneNumber': raData['phoneNumber'] ?? '',
          };
        });
        print("RA details retrieved: ${_raDetails!['fullName']}");
      } else {
        print("ERROR: RA document does not exist for ID: $raId");
        setState(() {
          _raDetails = null;
        });
      }
    } catch (e) {
      print('Error fetching RA details: $e');
      setState(() {
        _raDetails = null;
      });
    }
  }

  Future<void> _refreshWhenRAAssigned() async {
    if (_roomId == null) return;

    try {
      final groupChatDoc = await _firestore.collection('groupChats').doc(_roomId).get();
      if (groupChatDoc.exists) {
        final groupChatData = groupChatDoc.data() as Map<String, dynamic>;
        final String? raId = groupChatData['ra_id'] as String?;

        if (raId != null) {
          // Force update the members list to include the RA
          await _firestore.collection('groupChats').doc(_roomId).update({
            'members': FieldValue.arrayUnion([raId]),
          });

          // Reload the members list
          _loadGroupMembers(groupChatData);
        }
      }
    } catch (e) {
      debugPrint('Error refreshing when RA assigned: $e');
    }
  }

  Future<void> _removeMember(String memberId) async {
    if (_roomId == null || !_isCurrentUserRA) return;

    try {
      String memberName = "A member";
      for (var member in _roomMembers) {
        if (member['uid'] == memberId) {
          memberName = member['fullName'];
          break;
        }
      }

      await _firestore.collection('groupChats').doc(_roomId).update({
        'members': FieldValue.arrayRemove([memberId]),
      });

      await _firestore
          .collection('groupChats')
          .doc(_roomId)
          .collection('messages')
          .add({
        'senderId': 'system',
        'senderName': 'System',
        'message': '$memberName has been removed from the group by RA.',
        'timestamp': FieldValue.serverTimestamp(),
        'isSystemMessage': true,
      });

    } catch (e) {
      debugPrint('Error removing member: $e');
    }
  }

  Future<void> _initializeChat() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      if (_roomId == null || _roomId!.isEmpty) {
        setState(() {
          _error = 'Invalid room ID';
          _isLoading = false;
        });
        return;
      }

      print("Initializing chat for room: $_roomId");

      final roomDoc = await _firestore.collection('rooms').doc(_roomId).get();
      String? raId;
      List<String> residents = [];

      if (roomDoc.exists) {
        final roomData = roomDoc.data() as Map<String, dynamic>;
        raId = roomData['ra_id'] as String?;
        residents = List<String>.from(roomData['residents'] ?? []);

        print("Room data retrieved - RA ID: $raId, Residents count: ${residents.length}");

        final String currentUserId = _auth.currentUser?.uid ?? '';
        if (currentUserId.isNotEmpty && !residents.contains(currentUserId)) {
          residents.add(currentUserId);
        }
      } else {
        print("Room document does not exist!");
      }

      final chatDoc = await _firestore.collection('groupChats').doc(_roomId).get();
      final WriteBatch chatBatch = _firestore.batch();

      List<String> allMembers = [...residents];
      if (raId != null && !allMembers.contains(raId)) {
        allMembers.add(raId);
      }

      bool raJustAssigned = false;

      if (!chatDoc.exists) {
        // Make absolutely sure the RA is included in allMembers
        if (raId != null && !allMembers.contains(raId)) {
          allMembers.add(raId);
        }

        print("Creating new group chat document with members: $allMembers");
        chatBatch.set(_firestore.collection('groupChats').doc(_roomId), {
          'hostelName': widget.hostelName,
          'roomNumber': widget.roomNumber,
          'ra_id': raId,
          'members': allMembers,  // This should now include the RA
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': raId != null && raId.isNotEmpty,
          'raJoinedNotificationSent': false,
        });

        setState(() {
          _isGroupActive = raId != null && raId.isNotEmpty;
        });

        if (raId != null && raId.isNotEmpty) {
          raJustAssigned = true;
        }
      } else {
        print("Updating existing group chat");
        final chatData = chatDoc.data() as Map<String, dynamic>;
        final String? existingRaId = chatData['ra_id'] as String?;
        final List<String> existingMembers = List<String>.from(chatData['members'] ?? []);

        // Add RA to members explicitly in the update case too
        if (raId != null && !existingMembers.contains(raId)) {
          existingMembers.add(raId);
        }

        // Combine existing members with new members
        final Set<String> updatedMembers = {...existingMembers, ...allMembers};

        Map<String, dynamic> updateData = {
          'members': updatedMembers.toList(),  // Use the complete list instead of arrayUnion
          'lastUpdated': FieldValue.serverTimestamp(),
        };

        if ((existingRaId == null && raId != null) ||
            (existingRaId != null && raId != null && existingRaId != raId) ||
            _forceRefresh) {
          updateData['ra_id'] = raId;
          updateData['isActive'] = true;
          updateData['raJoinedNotificationSent'] = false;
          raJustAssigned = true;
          print("RA has been newly assigned or changed. RA ID: $raId");
        }

        chatBatch.update(_firestore.collection('groupChats').doc(_roomId), updateData);

        setState(() {
          _isGroupActive = updateData['isActive'] ?? chatData['isActive'] ?? false;
          _forceRefresh = false;
        });
      }

      await chatBatch.commit();
      debugPrint('Chat batch committed successfully');

      if (raId != null && raId.isNotEmpty) {
        await _fetchRADetails(raId);
        print("RA details after fetching: ${_raDetails != null ? _raDetails!['fullName'] : 'null'}");
      }

      if (raJustAssigned && raId != null && _raDetails != null) {
        await _sendRAJoinNotification();

        await _firestore.collection('groupChats').doc(_roomId).update({
          'raJoinedNotificationSent': true,
          'isActive': true,
        });

        setState(() {
          _isGroupActive = true;
        });

        debugPrint('RA join notification sent and chat activated');
      }

      _setupRoomListener();
      _setupGroupChatListener();

      // Force refresh when initializing chat
      if (raId != null) {
        await _refreshWhenRAAssigned();
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error initializing chat: $e');
      setState(() {
        _error = 'Error initializing chat: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _sendRAJoinNotification() async {
    if (_roomId == null || _raDetails == null) {
      print("Cannot send RA join notification: roomId is null or RA details are missing");
      return;
    }

    try {
      print("Sending RA join notification for: ${_raDetails!['fullName']}");

      await _firestore
          .collection('groupChats')
          .doc(_roomId)
          .collection('messages')
          .add({
        'senderId': 'system',
        'senderName': 'System',
        'message': '${_raDetails!['fullName']} (RA) has joined the chat. You can now send messages to the group.',
        'timestamp': FieldValue.serverTimestamp(),
        'isSystemMessage': true,
      });

      debugPrint('RA join notification sent');
    } catch (e) {
      debugPrint('Error sending RA join notification: $e');
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || !_isGroupActive) return;

    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('No authenticated user');
        return;
      }

      final userData = await _firestore.collection('users').doc(user.uid).get();
      final String senderName = userData.exists
          ? (userData.data()?['fullName'] ?? user.email ?? 'Unknown')
          : (user.email ?? 'Unknown');

      await _firestore
          .collection('groupChats')
          .doc(_roomId)
          .collection('messages')
          .add({
        'message': message,
        'senderId': user.uid,
        'senderName': senderName,
        'timestamp': FieldValue.serverTimestamp(),
        'isSystemMessage': false,
      });

      _messageController.clear();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final DateTime dateTime = timestamp.toDate();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String timeStr = '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';

    if (messageDate == today) {
      return timeStr;
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, $timeStr';
    } else {
      return '${dateTime.month}/${dateTime.day}, $timeStr';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue[800],
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.hostelName} - Room ${widget.roomNumber}'),
            if (_raDetails != null)
              Text(
                'RA: ${_raDetails!['fullName']}',
                style: const TextStyle(fontSize: 12),
              ),
            if (_raDetails == null)
              Text(
                'No RA assigned yet',
                style: const TextStyle(fontSize: 12, color: Colors.yellow),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showRoomInfo ? Icons.info : Icons.info_outline,
              color: _showRoomInfo ? Colors.amber : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _showRoomInfo = !_showRoomInfo;
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _forceRefresh = true;
              });
              _initializeChat();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : Column(
        children: [
          if (_showRoomInfo)
            _buildRoomInfoPanel(),
          if (!_isGroupActive)
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.amber[100],
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _raDetails == null
                          ? 'This chat will be activated once an RA is assigned and joins.'
                          : 'This chat will be activated once an RA joins.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _buildMessagesList(),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildRoomInfoPanel() {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Room Information',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue[800],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  setState(() {
                    _showRoomInfo = false;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InfoRow(
                  label: 'Hostel',
                  value: widget.hostelName,
                  icon: Icons.apartment,
                ),
              ),
              Expanded(
                child: InfoRow(
                  label: 'Room Number',
                  value: widget.roomNumber,
                  icon: Icons.door_front_door,
                ),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Members (${_roomMembers.length})',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: Colors.blue[800],
                ),
              ),
              if (_raDetails == null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Text(
                    'No RA assigned yet',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.amber[800],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 80,
            child: _roomMembers.isEmpty
                ? const Center(
              child: Text(
                'Loading members...',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            )
                : ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _roomMembers.length,
              itemBuilder: (context, index) {
                final member = _roomMembers[index];
                return Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.all(8),
                  width: 120,
                  decoration: BoxDecoration(
                    color: member['isRA'] ? Colors.blue[50] : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                member['isRA'] ? Icons.security : Icons.person,
                                color: member['isRA'] ? Colors.blue : Colors.grey,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              if (member['isRA'])
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'RA',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (_isCurrentUserRA && !member['isRA'])
                            GestureDetector(
                              onTap: () => _removeMember(member['uid']),
                              child: Icon(
                                Icons.close,
                                size: 14,
                                color: Colors.red[300],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        member['fullName'] ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (member['email'] != null && member['email'].isNotEmpty)
                        Text(
                          member['email'],
                          style: const TextStyle(fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('groupChats')
          .doc(_roomId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_raDetails == null
                    ? 'Waiting for an RA to be assigned to this group.'
                    : 'No messages yet. Be the first to chat!'),
                if (_raDetails == null)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Icon(
                      Icons.hourglass_empty,
                      size: 48,
                      color: Colors.grey[400],
                    ),
                  ),
              ],
            ),
          );
        }

        final messages = snapshot.data!.docs;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });

        return ListView.builder(
          controller: _scrollController,
          itemCount: messages.length,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          itemBuilder: (context, index) {
            final messageData = messages[index].data() as Map<String, dynamic>;
            final isCurrentUser = messageData['senderId'] == _auth.currentUser?.uid;
            final isSystemMessage = messageData['isSystemMessage'] == true;
            final timestamp = messageData['timestamp'] as Timestamp?;
            final timeString = timestamp != null
                ? _formatTimestamp(timestamp)
                : '';

            if (isSystemMessage) {
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),

                  ),
                  child: Text(
                    messageData['message'] ?? '',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              );
            }

            return Align(
              alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: isCurrentUser ? Colors.blue[400] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isCurrentUser)
                      Text(
                        messageData['senderName'] ?? 'Unknown',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isCurrentUser ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    Text(
                      messageData['message'] ?? '',
                      style: TextStyle(
                        color: isCurrentUser ? Colors.white : Colors.black87,
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        timeString,
                        style: TextStyle(
                          fontSize: 10,
                          color: isCurrentUser ? Colors.white70 : Colors.black54,
                        ),
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

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: _isGroupActive,
              decoration: InputDecoration(
                hintText: _isGroupActive
                    ? 'Type a message...'
                    : _raDetails == null
                    ? 'Waiting for an RA to be assigned...'
                    : 'Chat will be enabled when an RA joins',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.grey[200],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                suffixIcon: !_isGroupActive
                    ? Icon(Icons.lock, color: Colors.grey)
                    : null,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _isGroupActive ? _sendMessage : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(14),
              disabledBackgroundColor: Colors.grey[400],
              disabledForegroundColor: Colors.white70,
            ),
            child: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const InfoRow({
    Key? key,
    required this.label,
    required this.value,
    this.icon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
        ],
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }
}