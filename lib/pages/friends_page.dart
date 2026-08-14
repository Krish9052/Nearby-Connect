import 'chat_page.dart';
import 'profile_view_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class FriendsPage extends StatelessWidget {
  String formatLastSeen(Timestamp? timestamp) {
    if (timestamp == null) return "Offline";

    final date = timestamp.toDate();
    return "Last seen ${DateFormat("hh:mm a").format(date)}";
  }
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Friends"),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("friends")
            .where("userId", isEqualTo: currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final friends = snapshot.data!.docs;

          if (friends.isEmpty) {
            return const Center(
              child: Text("No Friends"),
            );
          }

          return ListView.builder(
            itemCount: friends.length,
            itemBuilder: (context, index) {
              final friend = friends[index];

             return StreamBuilder<DocumentSnapshot>(
               stream: FirebaseFirestore.instance
                   .collection("users")
                   .doc(friend["friendId"])
                   .snapshots(),
                builder: (context, userSnapshot) {

                  if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                    return const SizedBox();
                  }

                  final user = userSnapshot.data!;
                  final data = user.data() as Map<String, dynamic>;

                  final bool isOnline =
                      data.containsKey("isOnline") && data["isOnline"] == true;

                  final Timestamp? lastSeen =
                      data.containsKey("lastSeen")
                          ? data["lastSeen"] as Timestamp?
                          : null;

                  return Card(
                    margin: const EdgeInsets.all(10),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(user["image"]),
                      ),

                      title: Text(user["name"]),

                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user["bio"]),

                          const SizedBox(height: 4),

                          Text(
                            isOnline
                                ? "🟢 Online"
                                : formatLastSeen(lastSeen),
                            style: TextStyle(
                              color: isOnline ? Colors.green : Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ProfileViewPage(
                              userData: user.data() as Map<String, dynamic>,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}