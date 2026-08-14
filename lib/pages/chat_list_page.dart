import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  final currentUser = FirebaseAuth.instance.currentUser!;

  StreamSubscription<QuerySnapshot>? _friendsSubscription;

  final Map<String, StreamSubscription<QuerySnapshot>>
      _messageSubscriptions = {};

  final Map<String, StreamSubscription<QuerySnapshot>>
      _unreadSubscriptions = {};

  final Map<String, Map<String, dynamic>> _chats = {};

  bool _loadingFriends = true;

  String getChatId(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0
        ? "${uid1}_$uid2"
        : "${uid2}_$uid1";
  }

  @override
  void initState() {
    super.initState();
    _listenToFriends();
  }

  void _listenToFriends() {
    _friendsSubscription = FirebaseFirestore.instance
        .collection("friends")
        .where(
          "userId",
          isEqualTo: currentUser.uid,
        )
        .snapshots()
        .listen((snapshot) async {
      _loadingFriends = false;

      final currentFriendIds = snapshot.docs
          .map(
            (doc) => doc["friendId"].toString(),
          )
          .toSet();

      // Remove friends who are no longer friends.
      final oldFriendIds = _chats.keys.toList();

      for (final friendId in oldFriendIds) {
        if (!currentFriendIds.contains(friendId)) {
          _messageSubscriptions[friendId]?.cancel();
          _unreadSubscriptions[friendId]?.cancel();

          _messageSubscriptions.remove(friendId);
          _unreadSubscriptions.remove(friendId);
          _chats.remove(friendId);
        }
      }

      // Start realtime listeners for new friends.
      for (final friendId in currentFriendIds) {
        if (!_messageSubscriptions.containsKey(friendId)) {
          await _startFriendListeners(friendId);
        }
      }

      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _startFriendListeners(String friendId) async {
    final chatId = getChatId(
      currentUser.uid,
      friendId,
    );
    print("CHAT LIST FRIEND: $friendId");
    print("CHAT LIST CHAT ID: $chatId");

    // Get friend profile once.
    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(friendId)
        .get();

    if (!userDoc.exists) return;

    final userData =
        userDoc.data() as Map<String, dynamic>;

    final friendName =
        userData["name"]?.toString() ?? "User";

    final friendImage =
        userData["image"]?.toString() ?? "";

    // 🗑 Check if this conversation was deleted by me
    final deletedConversationDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUser.uid)
        .collection("deletedConversations")
        .doc(friendId)
        .get();

    Timestamp? deletedAt;
    
    if (deletedConversationDoc.exists) {
      final deletedData =
          deletedConversationDoc.data() as Map<String, dynamic>?;
    
      if (deletedData != null &&
          deletedData["deletedAt"] is Timestamp) {
        deletedAt = deletedData["deletedAt"] as Timestamp;
      }
    }

    // 🔥 Latest message realtime listener
    _messageSubscriptions[friendId] =
        FirebaseFirestore.instance
            .collection("chats")
            .doc(chatId)
            .collection("messages")
            .orderBy(
              "timestamp",
              descending: true,
            )
            .limit(1)
            .snapshots()
            .listen((snapshot) async {
      if (snapshot.docs.isEmpty) {
        // No conversation yet.
        if (_chats.containsKey(friendId)) {
          _chats.remove(friendId);

          if (mounted) {
            setState(() {});
          }
        }

        return;
      }

      final data =
          snapshot.docs.first.data();

      final timestamp =
          data["timestamp"] is Timestamp
              ? data["timestamp"] as Timestamp
              : null;
       
      // 🗑 Handle "Delete for me"
      if (deletedAt != null && timestamp != null) {
        if (timestamp.toDate().isAfter(deletedAt!.toDate())) {
          // 🆕 New message came after deletion
          await FirebaseFirestore.instance
              .collection("users")
              .doc(currentUser.uid)
              .collection("deletedConversations")
              .doc(friendId)
              .delete();
      
          deletedAt = null;
        } else {
          // Old message → keep conversation hidden
          _chats.remove(friendId);
      
          if (mounted) {
            setState(() {});
          }
      
          return;
        }
      }

      _chats[friendId] = {
        "friendId": friendId,
        "friendName": friendName,
        "friendImage": friendImage,
        "preview": _getPreview(data),
        "timestamp": timestamp,
        "unreadCount":
            _chats[friendId]?["unreadCount"] ?? 0,
      };

      if (mounted) {
        setState(() {});
      }
    });

    // 🔴 Unread messages realtime listener
    _unreadSubscriptions[friendId] =
        FirebaseFirestore.instance
            .collection("chats")
            .doc(chatId)
            .collection("messages")
            .where(
              "receiverId",
              isEqualTo: currentUser.uid,
            )
            .where(
              "read",
              isEqualTo: false,
            )
            .snapshots()
            .listen((snapshot) async {
              print("CHAT LIST MESSAGES: ${snapshot.docs.length}");
      if (!_chats.containsKey(friendId)) {
        // If latest-message listener hasn't created
        // the conversation yet, don't create one.
        return;
      }

      _chats[friendId]?["unreadCount"] =
          snapshot.docs.length;

      if (mounted) {
        setState(() {});
      }
    });
  }

  String _getPreview(
    Map<String, dynamic> data,
  ) {
    final imageUrl =
        data["imageUrl"]?.toString() ?? "";

    final voiceUrl =
        data["voiceUrl"]?.toString() ?? "";

    final message =
        data["message"]?.toString() ?? "";

    if (imageUrl.isNotEmpty) {
      return "📷 Photo";
    }

    if (voiceUrl.isNotEmpty) {
      return "🎤 Voice message";
    }

    if (message.isNotEmpty) {
      return message;
    }

    return "Message";
  }

  @override
  void dispose() {
    _friendsSubscription?.cancel();

    for (final subscription
        in _messageSubscriptions.values) {
      subscription.cancel();
    }

    for (final subscription
        in _unreadSubscriptions.values) {
      subscription.cancel();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chats = _chats.values.toList();

    // 🔥 Latest conversation first
    chats.sort((a, b) {
      final Timestamp? timeA =
          a["timestamp"];

      final Timestamp? timeB =
          b["timestamp"];

      if (timeA == null && timeB == null) {
        return 0;
      }

      if (timeA == null) return 1;

      if (timeB == null) return -1;

      return timeB.compareTo(timeA);
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0A1B4D),

      appBar: AppBar(
        backgroundColor:
            const Color(0xFF0A1B4D),

        iconTheme: const IconThemeData(
          color: Colors.white,
        ),

        title: const Text(
          "Chats",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: _loadingFriends
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : chats.isEmpty
              ? const Center(
                  child: Text(
                    "No messages",
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 17,
                    ),
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 8,
                  ),
                  itemCount: chats.length,
                  itemBuilder: (context, index) {
                    final chat = chats[index];

                    final friendId =
                        chat["friendId"]
                            .toString();

                    final friendName =
                        chat["friendName"]
                            .toString();

                    final friendImage =
                        chat["friendImage"]
                            .toString();

                    final preview =
                        chat["preview"]
                            .toString();

                    final unreadCount =
                        chat["unreadCount"] ?? 0;

                    final Timestamp? timestamp =
                        chat["timestamp"];

                    return Card(
                      color:
                          const Color(0xFF243B73),

                      margin:
                          const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),

                      child: ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),

                        leading: CircleAvatar(
                          radius: 27,
                          backgroundColor:
                              Colors.white24,

                          backgroundImage:
                              friendImage.isNotEmpty
                                  ? NetworkImage(
                                      friendImage,
                                    )
                                  : null,

                          child:
                              friendImage.isEmpty
                                  ? const Icon(
                                      Icons.person,
                                      color:
                                          Colors.white,
                                    )
                                  : null,
                        ),

                        title: Text(
                          friendName,
                          style:
                              const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        subtitle: Text(
                          preview,
                          maxLines: 1,
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                unreadCount > 0
                                    ? Colors.white
                                    : Colors.white70,
                            fontWeight:
                                unreadCount > 0
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
                                _formatTime(
                                  timestamp,
                                ),
                                style:
                                    const TextStyle(
                                  color:
                                      Colors.white54,
                                  fontSize: 11,
                                ),
                              ),

                            if (unreadCount > 0) ...[
                              const SizedBox(
                                height: 5,
                              ),

                              Container(
                                constraints:
                                    const BoxConstraints(
                                  minWidth: 22,
                                  minHeight: 22,
                                ),

                                padding:
                                    const EdgeInsets
                                        .symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),

                                decoration:
                                    BoxDecoration(
                                  color: Colors.red,
                                  borderRadius:
                                      BorderRadius
                                          .circular(
                                    12,
                                  ),
                                ),

                                child: Text(
                                  unreadCount > 99
                                      ? "99+"
                                      : unreadCount
                                          .toString(),
                                  textAlign:
                                      TextAlign.center,
                                  style:
                                      const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight:
                                        FontWeight.bold,
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
                              builder: (_) =>
                                  ChatPage(
                                receiverId:
                                    friendId,
                                receiverName:
                                    friendName,
                              ),
                            ),
                          );
                        },
                        onLongPress: () {
                          showDialog(
                            context: context,
                            builder: (dialogContext) {
                              return AlertDialog(
                                backgroundColor: const Color(0xFF243B73),
                                title: const Text(
                                  "Delete Conversation?",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                content: Text(
                                  "This conversation will be removed from your chat list. Your friend will still have the messages.",
                                  style: const TextStyle(
                                    color: Colors.white70,
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
                                        color: Colors.white70,
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
                                        "deletedAt":
                                            Timestamp.now(),
                                      });
                        
                                      if (mounted) {
                                        setState(() {
                                          _chats.remove(friendId);
                                        });
                                      }
                                    },
                                    child: const Text(
                                      "Delete",
                                      style: TextStyle(
                                        color: Colors.redAccent,
                                        fontWeight: FontWeight.bold,
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
                ),
    );
  }

  static String _formatTime(
    Timestamp timestamp,
  ) {
    final date = timestamp.toDate();
    final now = DateTime.now();

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      final hour =
          date.hour > 12
              ? date.hour - 12
              : date.hour;

      final displayHour =
          hour == 0 ? 12 : hour;

      final minute =
          date.minute
              .toString()
              .padLeft(2, "0");

      final period =
          date.hour >= 12 ? "PM" : "AM";

      return "$displayHour:$minute $period";
    }

    return "${date.day}/${date.month}";
  }
}