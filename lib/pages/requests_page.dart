import '../services/friend_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RequestsPage extends StatelessWidget {
  const RequestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Friend Requests"),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("friend_requests")
            .where("receiverId", isEqualTo: currentUser.uid)
            .where("status", isEqualTo: "pending")
            .snapshots(),

        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final requests = snapshot.data!.docs;

          if (requests.isEmpty) {
            return const Center(
              child: Text("No Friend Requests"),
            );
          }

          return ListView.builder(
            itemCount: requests.length,

            itemBuilder: (context, index) {

              final request = requests[index];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection("users")
                    .doc(request["senderId"])
                    .get(),

                builder: (context, userSnapshot) {

                  if (!userSnapshot.hasData) {
                    return const SizedBox();
                  }

                  final user = userSnapshot.data!;

                  return Card(
                    margin: const EdgeInsets.all(10),

                    child: ListTile(

                      leading: CircleAvatar(
                        backgroundImage:
                            user["image"] != ""
                                ? NetworkImage(user["image"])
                                : null,
                        child: user["image"] == ""
                            ? const Icon(Icons.person)
                            : null,
                      ),

                      title: Text(user["name"]),

                      subtitle: Text(user["bio"]),

                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,

                        children: [

                          IconButton(

                            icon: const Icon(
                              Icons.check,
                              color: Colors.green,
                            ),

                            onPressed: () async {

                              await FriendService.acceptRequest(request.id);

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Friend Request Accepted"),
                                ),
                              );
                            },

                          ),

                          IconButton(

                            icon: const Icon(
                              Icons.close,
                              color: Colors.red,
                            ),

                            onPressed: () async {

                              await FriendService.rejectRequest(request.id);

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Friend Request Rejected"),
                                ),
                              );
                            },

                          ),

                        ],
                      ),
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