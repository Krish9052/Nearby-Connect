import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../pages/chat_page.dart';
import '../services/profile_service.dart';

class ProfileViewPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final double distance;

  const ProfileViewPage({
    super.key,
    required this.userData,
    required this.distance,
  });

  @override
  State<ProfileViewPage> createState() => _ProfileViewPageState();
}

class _ProfileViewPageState extends State<ProfileViewPage> {
  final currentUser = FirebaseAuth.instance.currentUser!;

  String friendStatus = "loading";
  String? requestId;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadFriendStatus();
  }

  Future<void> loadFriendStatus() async {
    final result = await ProfileService.getFriendStatus(
      currentUserId: currentUser.uid,
      otherUserId: widget.userData["uid"],
    );

    if (!mounted) return;

    setState(() {
      friendStatus = result["status"];
      requestId = result["requestId"];
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.userData;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1B4D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1B4D),
        title: const Text("Profile"),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [

                  CircleAvatar(
                    radius: 70,
                    backgroundImage:
                        user["image"] != null &&
                                user["image"] != ""
                            ? NetworkImage(user["image"])
                            : null,
                    child: user["image"] == null ||
                            user["image"] == ""
                        ? const Icon(
                            Icons.person,
                            size: 70,
                          )
                        : null,
                  ),

                  const SizedBox(height: 20),

                  Text(
                    user["name"] ?? "",
                    style: const TextStyle(
                      fontSize: 28,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    user["bio"] ?? "",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 25),

                  Card(
                    color: Colors.white12,
                    child: ListTile(
                      leading: const Icon(Icons.cake,color: Colors.white),
                      title: const Text(
                        "Age",
                        style: TextStyle(color: Colors.white70),
                      ),
                      subtitle: Text(
                        "${user["age"] ?? ""}",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),

                  Card(
                    color: Colors.white12,
                    child: ListTile(
                      leading: const Icon(Icons.wc,color: Colors.white),
                      title: const Text(
                        "Gender",
                        style: TextStyle(color: Colors.white70),
                      ),
                      subtitle: Text(
                        user["gender"] ?? "",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),

                  Card(
                    color: Colors.white12,
                    child: ListTile(
                      leading: const Icon(Icons.email,color: Colors.white),
                      title: const Text(
                        "Email",
                        style: TextStyle(color: Colors.white70),
                      ),
                      subtitle: Text(
                        user["email"] ?? "",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),

                  Card(
                    color: Colors.white12,
                    child: ListTile(
                      leading: const Icon(Icons.phone,color: Colors.white),
                      title: const Text(
                        "Phone",
                        style: TextStyle(color: Colors.white70),
                      ),
                      subtitle: Text(
                        user["phone"] ?? "",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),

                  Card(
                    color: Colors.white12,
                    child: ListTile(
                      leading: const Icon(Icons.location_on,color: Colors.white),
                      title: const Text(
                        "Distance",
                        style: TextStyle(color: Colors.white70),
                      ),
                      subtitle: Text(
                        "${widget.distance.toStringAsFixed(1)} km away",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // PART 2 STARTS HERE...
                  if (friendStatus == "none")
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.person_add),
                        label: const Text("Add Friend"),
                        onPressed: () async {
                          await ProfileService.sendFriendRequest(
                            senderId: currentUser.uid,
                            receiverId: user["uid"],
                          );

                          await loadFriendStatus();
                        },
                      ),
                    ),

                  if (friendStatus == "sent")
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: null,
                        icon: const Icon(Icons.schedule),
                        label: const Text("Request Sent"),
                      ),
                    ),

                  if (friendStatus == "received")
                    Row(
                      children: [

                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check),
                            label: const Text("Accept"),
                            onPressed: () async {

                              if (requestId == null) return;

                              await ProfileService.acceptRequest(
                                requestId!,
                              );

                              await loadFriendStatus();

                            },
                          ),
                        ),

                        const SizedBox(width: 10),

                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.close),
                            label: const Text("Reject"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                            onPressed: () async {

                              if (requestId == null) return;

                              await ProfileService.rejectRequest(
                                requestId!,
                              );

                              await loadFriendStatus();

                            },
                          ),
                        ),
                      ],
                    ),

                  if (friendStatus == "friends")
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.chat),
                        label: const Text("Message"),
                        onPressed: () {

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatPage(
                                receiverId: user["uid"],
                                receiverName: user["name"],
                              ),
                            ),
                          );

                        },
                      ),
                    ),

                  const SizedBox(height: 30),

                  Card(
                    color: Colors.white12,
                    child: ListTile(
                      leading: const Icon(
                        Icons.block,
                        color: Colors.red,
                      ),
                      title: const Text(
                        "Block User",
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {

                        onTap: _showBlockDialog,

                      },
                    ),
                  ),

                  Card(
                    color: Colors.white12,
                    child: ListTile(
                      leading: const Icon(
                        Icons.flag,
                        color: Colors.orange,
                      ),
                      title: const Text(
                        "Report User",
                        style: TextStyle(color: Colors.white),
                      ),
                      onTap: () {

                        onTap: _showReportDialog,

                      },
                    ),
                  ),

                  const SizedBox(height: 20),
                  // part 3 starts here
                ],
              ),
            ),
    );
  }

  Future<void> _showBlockDialog() async {
    final user = widget.userData;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Block User"),
        content: Text(
          "Do you want to block ${user["name"]}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () async {
              // TODO: BlockService.blockUser(...)
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("User blocked successfully"),
                ),
              );
            },
            child: const Text("Block"),
          ),
        ],
      ),
    );
  }

  Future<void> _showReportDialog() async {
    final user = widget.userData;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Report User"),
        content: Text(
          "Report ${user["name"]}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () async {
              // TODO: ReportService.reportUser(...)
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Report submitted"),
                ),
              );
            },
            child: const Text("Report"),
          ),
        ],
      ),
    );
  }
}