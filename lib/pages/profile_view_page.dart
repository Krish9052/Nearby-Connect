// profile_view_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/friend_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_page.dart';

class ProfileViewPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProfileViewPage({
    super.key,
    required this.userData,
  });

  @override
  State<ProfileViewPage> createState() => _ProfileViewPageState();
}

class _ProfileViewPageState extends State<ProfileViewPage> {
  final currentUser = FirebaseAuth.instance.currentUser!;

  Future<bool> checkIfFriends(String otherUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return false;

    final result = await FirebaseFirestore.instance
        .collection("friends")
        .where("userId", isEqualTo: currentUser.uid)
        .where("friendId", isEqualTo: otherUserId)
        .limit(1)
        .get();
  
    return result.docs.isNotEmpty;
  }

  Future<String> getFriendStatus(String otherUserId) async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      return "none";
    }

    // Check if already friends
    final friendResult = await FirebaseFirestore.instance
        .collection("friends")
        .where("userId", isEqualTo: currentUser.uid)
        .where("friendId", isEqualTo: otherUserId)
        .limit(1)
        .get();

    if (friendResult.docs.isNotEmpty) {
      return "friends";
    }

    // Check if current user already sent request
    final sentResult = await FirebaseFirestore.instance
        .collection("friend_requests")
        .where("senderId", isEqualTo: currentUser.uid)
        .where("receiverId", isEqualTo: otherUserId)
        .where("status", isEqualTo: "pending")
        .limit(1)
        .get();

    if (sentResult.docs.isNotEmpty) {
      return "sent";
    }

    // Check if other user sent request to current user
    final receivedResult = await FirebaseFirestore.instance
        .collection("friend_requests")
        .where("senderId", isEqualTo: otherUserId)
        .where("receiverId", isEqualTo: currentUser.uid)
        .where("status", isEqualTo: "pending")
        .limit(1)
        .get();

    if (receivedResult.docs.isNotEmpty) {
      return "received";
    }

    return "none";
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.userData;
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1B4D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1B4D),
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 65,
              backgroundImage: user['image'] != null &&
                      user['image'].toString().isNotEmpty
                  ? NetworkImage(user['image'])
                  : null,
              child: user['image'] == null ||
                      user['image'].toString().isEmpty
                  ? const Icon(Icons.person, size: 60)
                  : null,
            ),
            const SizedBox(height: 20),
            Text(
              user['name'] ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Card(
              color: Colors.white12,
              child: ListTile(
                title: const Text('Age', style: TextStyle(color: Colors.white70)),
                subtitle: Text('${user['age'] ?? ''}',
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
            Card(
              color: Colors.white12,
              child: ListTile(
                title: const Text('Gender', style: TextStyle(color: Colors.white70)),
                subtitle: Text('${user['gender'] ?? ''}',
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
            Card(
              color: Colors.white12,
              child: ListTile(
                title: const Text('Bio', style: TextStyle(color: Colors.white70)),
                subtitle: Text('${user['bio'] ?? ''}',
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
            if ((user['instagram'] ?? '').toString().trim().isNotEmpty)
              Card(
                color: Colors.white12,
                child: ListTile(
                  leading: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                  ),
                  title: const Text(
                    'Instagram',
                    style: TextStyle(color: Colors.white70),
                  ),
                  subtitle: Text(
                    user['instagram'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.open_in_new,
                    color: Colors.white70,
                  ),
                  onTap: () async {
                    String username = user['instagram'].toString().trim();

                    if (username.startsWith('@')) {
                      username = username.substring(1);
                    }

                    final Uri url = Uri.parse(
                      'https://www.instagram.com/$username/',
                    );

                    if (await canLaunchUrl(url)) {
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  },
                ),
              ),
            const SizedBox(height: 30),
            FutureBuilder<String>(
              future: getFriendStatus(user['uid']),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 50,
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final status = snapshot.data!;

                if (status == "friends") {
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check),
                      label: const Text("Friends"),
                    ),
                  );
                }

                if (status == "sent") {
                  return SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.schedule),
                      label: const Text("Request Sent"),
                    ),
                  );
                }
                if (status == "received") {
                  return Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final currentUser =
                                FirebaseAuth.instance.currentUser;

                            if (currentUser == null) return;

                            final request = await FirebaseFirestore.instance
                                .collection("friend_requests")
                                .where(
                                  "senderId",
                                  isEqualTo: user["uid"],
                                )
                                .where(
                                  "receiverId",
                                  isEqualTo: currentUser.uid,
                                )
                                .where(
                                  "status",
                                  isEqualTo: "pending",
                                )
                                .limit(1)
                                .get();
                
                            if (request.docs.isEmpty) return;

                            await FriendService.acceptRequest(
                              request.docs.first.id,
                            );

                            if (!context.mounted) return;

                            setState(() {});
                          },
                          icon: const Icon(Icons.check),
                          label: const Text("Accept"),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final currentUser =
                                FirebaseAuth.instance.currentUser;

                            if (currentUser == null) return;

                            final request = await FirebaseFirestore.instance
                                .collection("friend_requests")
                                .where(
                                  "senderId",
                                  isEqualTo: user["uid"],
                                )
                                .where(
                                  "receiverId",
                                  isEqualTo: currentUser.uid,
                                )
                                .where(
                                  "status",
                                  isEqualTo: "pending",
                                )
                                .limit(1)
                                .get();

                            if (request.docs.isEmpty) return;

                            await FriendService.rejectRequest(
                              request.docs.first.id,
                            );

                            if (!context.mounted) return;

                            setState(() {});
                          },
                          icon: const Icon(Icons.close),
                          label: const Text("Reject"),
                        ),
                      ),
                    ],
                  );
                }

                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (currentUser == null) return;

                      await FriendService.sendRequest(
                        senderId: currentUser!.uid,
                        receiverId: user['uid'],
                      );

                      if (!context.mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Friend Request Sent"),
                        ),
                      );

                      setState(() {});
                    },
                    icon: const Icon(Icons.person_add),
                    label: const Text("Add Friend"),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            FutureBuilder<bool>(
              future: checkIfFriends(user['uid']),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data == false) {
                  return const SizedBox.shrink();
                }

                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatPage(
                            receiverId: user['uid'],
                            receiverName: user['name'] ?? '',
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.message),
                    label: const Text('Message'),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
