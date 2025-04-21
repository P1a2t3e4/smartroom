import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../services/user_service.dart';



void main() {
  runApp(const MaterialApp(
    home: AssignedRoomsPage(),
  ));
}

class AssignedRoomsPage extends StatelessWidget {
  const AssignedRoomsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Room Chat', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: const AssignedRoomsTab(),
    );
  }
}

class AssignedRoomsTab extends StatelessWidget {
  const AssignedRoomsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: UserService().getAssignedRooms(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final assignedRooms = snapshot.data ?? [];

        if (assignedRooms.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.apartment, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text('No rooms assigned yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey)),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text('You are responsible for ${assignedRooms.length} rooms',
                  style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.0,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: assignedRooms.length,
                  itemBuilder: (context, index) {
                    final room = assignedRooms[index];
                    return RoomCard(roomNumber: room);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class RoomCard extends StatelessWidget {
  final String roomNumber;

  const RoomCard({super.key, required this.roomNumber});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: UserService().getRoomDetails(roomNumber),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final roomData = snapshot.data ?? {};
        final String roomId = roomData['id'] ?? '';
        final String hostelName = roomData['hostelName'] ?? 'Hostel';

        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RoomChatScreen(
                    roomId: roomId,
                    hostelName: hostelName,
                    roomNumber: roomNumber,
                  ),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.meeting_room, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Room $roomNumber',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.blue,
                            )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Divider(color: Colors.grey.shade300, height: 1),
                  const SizedBox(height: 6),
                  FutureBuilder<List<Map<String, dynamic>>>(
                    future: UserService().getRoommates(roomNumber),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const SizedBox(
                          height: 20,
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        );
                      }
                      final roommates = snapshot.data ?? [];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.people, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                '${roommates.length} ${roommates.length == 1 ? 'Resident' : 'Residents'}',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (roommates.isNotEmpty)
                            SizedBox(
                              height: 24,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: roommates.length,
                                itemBuilder: (context, index) {
                                  final roommate = roommates[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 6.0),
                                    child: Tooltip(
                                      message: roommate['fullName'],
                                      child: CircleAvatar(
                                        backgroundColor: roommate['isRA']
                                            ? Colors.blue.shade700
                                            : Colors.blue.shade200,
                                        radius: 10,
                                        child: Text(
                                          roommate['fullName'].isNotEmpty
                                              ? roommate['fullName'][0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                            color: roommate['isRA'] ? Colors.white : Colors.blue.shade800,
                                            fontSize: 8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.chat, size: 14),
                      label: const Text('Chat', style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RoomChatScreen(
                              roomId: roomId,
                              hostelName: hostelName,
                              roomNumber: roomNumber,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class RoomChatScreen extends StatefulWidget {
  final String roomId;
  final String hostelName;
  final String roomNumber;

  const RoomChatScreen({
    super.key,
    required this.roomId,
    required this.hostelName,
    required this.roomNumber,
  });

  @override
  State<RoomChatScreen> createState() => _RoomChatScreenState();
}

class _RoomChatScreenState extends State<RoomChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showRoomInfo = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final String fullName = userData['fullName'] ?? 'RA';
      final String message = _messageController.text.trim();

      await FirebaseFirestore.instance
          .collection('groupChats')
          .doc(widget.roomId)
          .collection('messages')
          .add({
        'message': message,
        'senderName': fullName,
        'senderId': user.uid,
        'senderRole': 'RA',
        'timestamp': FieldValue.serverTimestamp(),
      });

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.hostelName} - Room ${widget.roomNumber}'),
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: Icon(_showRoomInfo ? Icons.info : Icons.info_outline,
                color: _showRoomInfo ? Colors.amber : Colors.white),
            onPressed: () => setState(() => _showRoomInfo = !_showRoomInfo),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showRoomInfo) _buildRoomInfo(),
          Expanded(child: _buildChatMessages()),
          _buildMessageInput(),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _ensureRAInGroupChat();
  }

  Future<void> _ensureRAInGroupChat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('groupChats')
          .doc(widget.roomId)
          .update({
        'members': FieldValue.arrayUnion([user.uid]),
        'ra_id': user.uid,
        'isActive': true,
      });

      final groupChatDoc = await FirebaseFirestore.instance
          .collection('groupChats')
          .doc(widget.roomId)
          .get();

      bool raJoinedNotificationSent = groupChatDoc.data()?['raJoinedNotificationSent'] ?? false;

      if (!raJoinedNotificationSent) {
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final String fullName = userData['fullName'] ?? 'RA';

        await FirebaseFirestore.instance
            .collection('groupChats')
            .doc(widget.roomId)
            .collection('messages')
            .add({
          'senderId': 'system',
          'senderName': 'System',
          'message': '$fullName (RA) has joined the chat. You can now send messages to the group.',
          'timestamp': FieldValue.serverTimestamp(),
          'isSystemMessage': true,
        });

        await FirebaseFirestore.instance
            .collection('groupChats')
            .doc(widget.roomId)
            .update({
          'raJoinedNotificationSent': true,
        });
      }
    } catch (e) {
      debugPrint('Error ensuring RA in group chat: $e');
    }
  }

  Widget _buildRoomInfo() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: UserService().getRoommates(widget.roomNumber),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final roommates = snapshot.data ?? [];

        return Container(
          padding: const EdgeInsets.all(16),
          color: Colors.blue.shade50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Roommates (${roommates.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              roommates.isEmpty
                  ? const Text('No roommates found')
                  : SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: roommates.length,
                  itemBuilder: (context, index) {
                    final roommate = roommates[index];
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 12),
                      child: Column(
                        children: [
                          CircleAvatar(
                            backgroundColor: roommate['isRA'] ? Colors.blue : Colors.blue.shade200,
                            child: Text(
                              roommate['fullName'].isNotEmpty
                                  ? roommate['fullName'][0].toUpperCase()
                                  : '?',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  roommate['fullName'],
                                  style: const TextStyle(fontSize: 12),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (roommate['isRA'])
                                Container(
                                  margin: const EdgeInsets.only(left: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'RA',
                                    style: TextStyle(color: Colors.white, fontSize: 8),
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            roommate['email'],
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
      },
    );
  }

  Widget _buildChatMessages() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('groupChats')
          .doc(widget.roomId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text('No messages yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('Start the conversation with your residents',
                    style: TextStyle(fontSize: 14, color: Colors.grey)),
              ],
            ),
          );
        }

        final messages = snapshot.data!.docs;
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index].data() as Map<String, dynamic>;
            final isMe = message['senderId'] == FirebaseAuth.instance.currentUser?.uid;
            final timestamp = message['timestamp'] as Timestamp?;
            final time = timestamp != null
                ? '${timestamp.toDate().hour}:${timestamp.toDate().minute.toString().padLeft(2, '0')}'
                : '';
            final isSystemMessage = message['isSystemMessage'] == true;

            if (isSystemMessage) {
              return Container(
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    message['message'] ?? '',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              );
            }

            return Align(
              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4.0),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                decoration: BoxDecoration(
                  color: isMe ? Colors.blue.shade100 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(16),
                ),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.7,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(message['senderName'] ?? 'Unknown',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isMe ? Colors.blue.shade800 : Colors.black87,
                            )),
                        const SizedBox(width: 4),
                        if (message['senderRole'] == 'RA')
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade800,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text('RA',
                                style: TextStyle(color: Colors.white, fontSize: 10)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(message['message'] ?? ''),
                    const SizedBox(height: 2),
                    Text(time,
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
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
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            offset: const Offset(0, -1),
            blurRadius: 3,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.photo),
              color: Colors.blue,
              onPressed: () {},
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24.0),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              color: Colors.blue,
              onPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class UserService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  Future<List<String>> getAssignedRooms() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (doc.exists) {
      return List<String>.from(doc['assignedRooms'] ?? []);
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getRoommates(String roomNumber) async {
    try {
      final roomSnapshot = await _firestore
          .collection('rooms')
          .where('roomNumber', isEqualTo: roomNumber)
          .limit(1)
          .get();

      if (roomSnapshot.docs.isEmpty) return [];

      final String roomId = roomSnapshot.docs.first.id;

      final groupChatDoc = await _firestore
          .collection('groupChats')
          .doc(roomId)
          .get();

      if (!groupChatDoc.exists) return [];

      final List<String> memberIds = List<String>.from(groupChatDoc.data()?['members'] ?? []);
      final String? raId = groupChatDoc.data()?['ra_id'] as String?;

      if (raId != null && !memberIds.contains(raId)) {
        memberIds.add(raId);
      }

      List<Map<String, dynamic>> members = [];
      for (String memberId in memberIds) {
        final userDoc = await _firestore.collection('users').doc(memberId).get();
        if (userDoc.exists) {
          members.add({
            'id': memberId,
            'fullName': userDoc.data()?['fullName'] ?? 'Unknown',
            'email': userDoc.data()?['email'] ?? '',
            'isRA': raId == memberId,
          });
        }
      }

      return members;
    } catch (e) {
      debugPrint('Error getting roommates: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getRoomDetails(String roomNumber) async {
    try {
      final snapshot = await _firestore
          .collection('rooms')
          .where('roomNumber', isEqualTo: roomNumber)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return {
          'id': snapshot.docs.first.id,
          'hostelName': snapshot.docs.first['hostelName'] ?? 'Hostel',
        };
      }
      return {'id': '', 'hostelName': 'Hostel'};
    } catch (e) {
      debugPrint('Error getting room details: $e');
      return {'id': '', 'hostelName': 'Hostel'};
    }
  }
}