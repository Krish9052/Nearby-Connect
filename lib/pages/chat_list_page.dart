import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_page.dart';

class ChatListPage extends StatelessWidget {
  const ChatListPage({super.key});

  String getChatId(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0
        ? "${uid1}_$uid2"
        : "${uid2}_$uid1";
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser!;

    return Scaffold(
      backgroundColor: const Color(0xFFF0EDFF),

      appBar: AppBar(
        backgroundColor: const Color(0xFFF0EDFF),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(
          color: Color(0xFF0A1B4D),
          size: 30,
        ),
        title: const Text(
          "Chats",
          style: TextStyle(
            color: Color(0xFF0A1B4D),
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("friends")
            .where(
              "userId",
              isEqualTo: currentUser.uid,
            )
            .snapshots(),

        builder: (context, friendsSnapshot) {
          if (friendsSnapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (friendsSnapshot.hasError) {
            return Center(
              child: Text(
                "Unable to load chats",
                style: const TextStyle(
                  color: Color(0xFF68739A),
                  fontSize: 17,
                ),
              ),
            );
          }

          if (!friendsSnapshot.hasData) {
            return const Center(
              child: Text(
                "No messages",
                style: TextStyle(
                  color: Color(0xFF68739A),
                  fontSize: 17,
                ),
              ),
            );
          }

          final friends = friendsSnapshot.data!.docs;

          if (friends.isEmpty) {
            return const Center(
              child: Text(
                "No messages",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 17,
                ),
              ),
            );
          }

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadChats(
              currentUser.uid,
              friends,
            ),

            builder: (context, chatSnapshot) {
              if (chatSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(),
                );
              }

              final chats = chatSnapshot.data ?? [];

              if (chats.isEmpty) {
                return const Center(
                  child: Text(
                    "No messages",
                    style: TextStyle(
                      color: const Color(0xFF68739A),
                      fontSize: 17,
                    ),
                  ),
                );
              }

              // 🔥 Latest conversation first
              chats.sort((a, b) {
                final Timestamp? timeA = a["timestamp"];
                final Timestamp? timeB = b["timestamp"];

                if (timeA == null && timeB == null) return 0;
                if (timeA == null) return 1;
                if (timeB == null) return -1;

                return timeB.compareTo(timeA);
              });

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  vertical: 8,
                ),
                itemCount: chats.length,

                itemBuilder: (context, index) {
                  final chat = chats[index];

                  final friendId = chat["friendId"];
                  final friendName = chat["friendName"];
                  final friendImage = chat["friendImage"];
                  final preview = chat["preview"];
                  final unreadCount = chat["unreadCount"] ?? 0;
                  final Timestamp? timestamp = chat["timestamp"];

                  return Card(
                    color: Colors.white,
                    elevation: 4,
                    shadowColor: const Color(0x22000000),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 7,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 9,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 7,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 34,
                          backgroundColor: const Color(0xFFE4E1F2),
                          backgroundImage: friendImage.isNotEmpty
                              ? NetworkImage(friendImage)
                              : null,
                          child: friendImage.isEmpty
                              ? const Icon(
                                  Icons.person,
                                  color: Color(0xFF68739A),
                                  size: 32,
                                )
                              : null,
                        ),
                      ),

                      title: Text(
                        friendName,
                        style: const TextStyle(
                          color: const Color(0xFF0A1B4D),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      subtitle: Text(
                        preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unreadCount > 0
                              ? const Color(0xFF68739A)
                              : const Color(0xFF8A8EA5),
                          fontWeight: unreadCount > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),

                      trailing: Column(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        crossAxisAlignment:
                            CrossAxisAlignment.end,
                        children: [
                          if (timestamp != null)
                            Text(
                              _formatTime(timestamp),
                              style: const TextStyle(
                                color: const Color(0xFF68739A),
                                fontSize: 13,
                              ),
                            ),

                          if (unreadCount > 0) ...[
                            const SizedBox(height: 5),

                            Container(
                              constraints:
                                  const BoxConstraints(
                                minWidth: 22,
                                minHeight: 22,
                              ),
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6B4DB8),
                                borderRadius:
                                    BorderRadius.circular(16),
                              ),
                              child: Text(
                                unreadCount > 99
                                    ? "99+"
                                    : unreadCount.toString(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatPage(
                              receiverId: friendId,
                              receiverName: friendName,
                            ),
                          ),
                        );
                      },

                      // Long press -> delete conversation for this user only.
                      onLongPress: () {
                        showDialog(
                          context: context,
                          builder: (dialogContext) {
                            return AlertDialog(
                              backgroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              title: const Text(
                                "Delete Conversation?",
                                style: TextStyle(
                                  color: Color(0xFF0A1B4D),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              content: const Text(
                                "This conversation will be removed from your chat list. Your friend will still have the messages.",
                                style: TextStyle(
                                  color: Color(0xFF68739A),
                                  fontSize: 15,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(dialogContext);
                                  },
                                  child: const Text(
                                    "Cancel",
                                    style: TextStyle(
                                      color: Color(0xFF68739A),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    Navigator.pop(dialogContext);

                                    await FirebaseFirestore.instance
                                        .collection("users")
                                        .doc(currentUser.uid)
                                        .collection("deletedConversations")
                                        .doc(friendId)
                                        .set({
                                      "deletedAt": Timestamp.now(),
                                    });

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            "Conversation deleted",
                                          ),
                                          duration:
                                              Duration(milliseconds: 1400),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text(
                                    "Delete",
                                    style: TextStyle(
                                      color: Color(0xFF6B4DB8),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
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

  Future<List<Map<String, dynamic>>> _loadChats(
    String currentUserId,
    List<QueryDocumentSnapshot> friends,
  ) async {
    final List<Map<String, dynamic>> chats = [];

    for (final friend in friends) {
      final friendId = friend["friendId"].toString();

      final userDoc = await FirebaseFirestore.instance
          .collection("users")
          .doc(friendId)
          .get();

      if (!userDoc.exists) continue;

      final userData =
          userDoc.data() as Map<String, dynamic>;

      final chatId = getChatId(
        currentUserId,
        friendId,
      );

      final messagesSnapshot =
          await FirebaseFirestore.instance
              .collection("chats")
              .doc(chatId)
              .collection("messages")
              .orderBy(
                "timestamp",
                descending: true,
              )
              .limit(1)
              .get();

      // ❌ No conversation → don't show in Chat list
      if (messagesSnapshot.docs.isEmpty) {
        continue;
      }

      final messageDoc =
          messagesSnapshot.docs.first;

      final data =
          messageDoc.data();

      String preview = "";

      final imageUrl =
          data["imageUrl"]?.toString() ?? "";

      final voiceUrl =
          data["voiceUrl"]?.toString() ?? "";

      final message =
          data["message"]?.toString() ?? "";

      if (imageUrl.isNotEmpty) {
        preview = "📷 Photo";
      } else if (voiceUrl.isNotEmpty) {
        preview = "🎤 Voice message";
      } else if (message.isNotEmpty) {
        preview = message;
      } else {
        preview = "Message";
      }

      final unreadSnapshot =
          await FirebaseFirestore.instance
              .collection("chats")
              .doc(chatId)
              .collection("messages")
              .where(
                "receiverId",
                isEqualTo: currentUserId,
              )
              .where(
                "read",
                isEqualTo: false,
              )
              .get();

      chats.add({
        "friendId": friendId,
        "friendName":
            userData["name"]?.toString() ?? "User",
        "friendImage":
            userData["image"]?.toString() ?? "",
        "preview": preview,
        "timestamp": data["timestamp"],
        "unreadCount":
            unreadSnapshot.docs.length,
      });
    }

    return chats;
  }

  static String _formatTime(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      final hour =
          date.hour > 12 ? date.hour - 12 : date.hour;

      final displayHour = hour == 0 ? 12 : hour;

      final minute =
          date.minute.toString().padLeft(2, "0");

      final period =
          date.hour >= 12 ? "PM" : "AM";

      return "$displayHour:$minute $period";
    }

    return "${date.day}/${date.month}";
  }
}