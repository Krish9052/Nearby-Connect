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

    final String imageUrl = user['image']?.toString() ?? '';
    final String name = user['name']?.toString() ?? '';
    final String age = user['age']?.toString() ?? '';
    final String gender = user['gender']?.toString() ?? '';
    final String bio = user['bio']?.toString() ?? '';
    final String instagram = user['instagram']?.toString().trim() ?? '';

    Widget profileInfoCard({
      required IconData icon,
      required String title,
      required String value,
    }) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF2FF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Color(0xFF1976D2),
                size: 25,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value.isEmpty ? "Not provided" : value,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF0A1B4D),
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF8FAFF),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Color(0xFF0A1B4D),
            size: 32,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Color(0xFF0A1B4D),
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Large round profile photo. No online indicator.
            CircleAvatar(
              radius: 78,
              backgroundColor: const Color(0xFFE2E8F0),
              backgroundImage: imageUrl.isNotEmpty
                  ? NetworkImage(imageUrl)
                  : null,
              child: imageUrl.isEmpty
                  ? const Icon(
                      Icons.person,
                      size: 68,
                      color: Color(0xFF1E293B),
                    )
                  : null,
            ),

            const SizedBox(height: 12),

            Text(
              name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF0A1B4D),
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 18),

            profileInfoCard(
              icon: Icons.calendar_month_outlined,
              title: 'Age',
              value: age,
            ),
            profileInfoCard(
              icon: Icons.person_outline,
              title: 'Gender',
              value: gender,
            ),
            profileInfoCard(
              icon: Icons.notes_outlined,
              title: 'Bio',
              value: bio,
            ),

            if (instagram.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(24),
                  onTap: () async {
                    String username = instagram;
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
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF3E8FF),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt_outlined,
                          color: Color(0xFF1976D2),
                          size: 25,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Instagram',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              instagram,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF0A1B4D),
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.open_in_new,
                        color: Color(0xFF1976D2),
                        size: 25,
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 0),

            // Existing friend-status logic is preserved.
            FutureBuilder<String>(
              future: getFriendStatus(user['uid']),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox(
                    height: 52,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1976D2),
                      ),
                    ),
                  );
                }

                final status = snapshot.data!;

                if (status == "friends") {
                  return const SizedBox.shrink();
                }

                if (status == "sent") {
                  return SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.schedule),
                      label: const Text("Request Sent"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
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
                                .where("senderId", isEqualTo: user["uid"])
                                .where(
                                  "receiverId",
                                  isEqualTo: currentUser.uid,
                                )
                                .where("status", isEqualTo: "pending")
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
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size(0, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
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
                                .where("senderId", isEqualTo: user["uid"])
                                .where(
                                  "receiverId",
                                  isEqualTo: currentUser.uid,
                                )
                                .where("status", isEqualTo: "pending")
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
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFDC2626),
                            side: const BorderSide(
                              color: Color(0xFFFCA5A5),
                            ),
                            minimumSize: const Size(0, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (currentUser == null) return;

                      await FriendService.sendRequest(
                        senderId: currentUser.uid,
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 14),

            // Existing Message navigation is preserved.
            FutureBuilder<bool>(
              future: checkIfFriends(user['uid']),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data == false) {
                  return const SizedBox.shrink();
                }

                return SizedBox(
                  width: double.infinity,
                  height: 52,
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
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      size: 21,
                    ),
                    label: const Text(
                      'Message',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
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
