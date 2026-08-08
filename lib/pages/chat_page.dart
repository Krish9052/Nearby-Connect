import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../widgets/voice_message_bubble.dart';

class ChatPage extends StatefulWidget {
  final String receiverId;
  final String receiverName;

  const ChatPage({
    super.key,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
    TextEditingController messageController = TextEditingController();
    final ImagePicker picker = ImagePicker();
    final currentUser = FirebaseAuth.instance.currentUser!;
    final AudioRecorder audioRecorder = AudioRecorder();

    bool isRecording = false;
    String? recordedFilePath;
    bool isTyping = false;
    bool isFriend = false;
    bool isBlocked = false;
    bool isMuted = false;

    @override
    void initState() {
      super.initState();
      checkFriendStatus();
      checkBlockStatus();
      checkMuteStatus();
    }
    
    Future<void> checkFriendStatus() async {
      final result = await FirebaseFirestore.instance
          .collection("friends")
          .where(
            "userId",
            isEqualTo: currentUser.uid,
          )
          .where(
            "friendId",
            isEqualTo: widget.receiverId,
          )
          .limit(1)
          .get();

      if (!mounted) return;

      setState(() {
        isFriend = result.docs.isNotEmpty;
      });
    }
    Future<void> checkBlockStatus() async {
      final currentUserId = currentUser.uid;
      final receiverId = widget.receiverId;

      final myBlock = await FirebaseFirestore.instance
          .collection("blocks")
          .doc("${currentUserId}_$receiverId")
          .get();

      final theirBlock = await FirebaseFirestore.instance
          .collection("blocks")
          .doc("${receiverId}_$currentUserId")
          .get();

      if (!mounted) return;

      setState(() {
        isBlocked = myBlock.exists || theirBlock.exists;
      });
    }
    Future<void> checkMuteStatus() async {
      final doc = await FirebaseFirestore.instance
          .collection("mutes")
          .doc("${currentUser.uid}_${widget.receiverId}")
          .get();

      if (!mounted) return;

      setState(() {
        isMuted = doc.exists;
      });
    }
    Future<void> toggleMute() async {
      final muteId =
          "${currentUser.uid}_${widget.receiverId}";

      if (isMuted) {
        await FirebaseFirestore.instance
            .collection("mutes")
            .doc(muteId)
            .delete();

        if (!mounted) return;

        setState(() {
          isMuted = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Notifications unmuted"),
          ),
        );
      } else {
        await FirebaseFirestore.instance
            .collection("mutes")
            .doc(muteId)
            .set({
          "userId": currentUser.uid,
          "mutedUserId": widget.receiverId,
          "createdAt": FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        setState(() {
          isMuted = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Notifications muted"),
          ),
        );
      }
    }
    Future<void> blockUser() async {
      await FirebaseFirestore.instance
          .collection("blocks")
          .doc("${currentUser.uid}_${widget.receiverId}")
          .set({
        "blockerId": currentUser.uid,
        "blockedId": widget.receiverId,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      setState(() {
        isBlocked = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("User blocked"),
        ),
      );
    }

    Future<void> unblockUser() async {
      await FirebaseFirestore.instance
          .collection("blocks")
          .doc("${currentUser.uid}_${widget.receiverId}")
          .delete();

      if (!mounted) return;

      setState(() {
        isBlocked = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("User unblocked"),
        ),
      );
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A1B4D),

        appBar: AppBar(
        backgroundColor: const Color(0xFF0A1B4D),
        title: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection("users")
              .doc(widget.receiverId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Text(widget.receiverName);
            }

            final data = snapshot.data!.data() as Map<String, dynamic>?;

            final bool typing =
                data?["typingTo"] == FirebaseAuth.instance.currentUser!.uid;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.receiverName),
                Text(
                  typing ? "Typing..." : "",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              color: Colors.white,
            ),
            onSelected: (value) async {
              if (value == "mute") {
                await toggleMute();
              }

              if (value == "block") {
                if (isBlocked) {
                  await unblockUser();
                } else {
                  await blockUser();
                }
              }

              if (value == "report") {
                final reason = await showDialog<String>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: const Text("Report User"),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            title: const Text("Spam"),
                            onTap: () => Navigator.pop(context, "Spam"),
                          ),
                          ListTile(
                            title: const Text("Harassment"),
                            onTap: () => Navigator.pop(context, "Harassment"),
                          ),
                          ListTile(
                            title: const Text("Fake account"),
                            onTap: () => Navigator.pop(context, "Fake account"),
                          ),
                          ListTile(
                            title: const Text("Inappropriate content"),
                            onTap: () =>
                                Navigator.pop(context, "Inappropriate content"),
                          ),
                          ListTile(
                            title: const Text("Other"),
                            onTap: () => Navigator.pop(context, "Other"),
                          ),
                        ],
                      ),
                    );
                  },
                );

                if (reason == null) return;

                await FirebaseFirestore.instance.collection("reports").add({
                  "reporterId": currentUser.uid,
                  "reportedUserId": widget.receiverId,
                  "reason": reason,
                  "createdAt": FieldValue.serverTimestamp(),
                });

                if (!mounted) return;

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("User reported successfully"),
                  ),
                );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: "mute",
                child: Row(
                  children: [
                    Icon(
                      isMuted
                          ? Icons.notifications
                          : Icons.notifications_off,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isMuted
                          ? "Unmute notifications"
                          : "Mute notifications",
                    ),
                  ],
                ),
              ),

              PopupMenuItem(
                value: "block",
                child: Row(
                  children: [
                    Icon(
                      isBlocked
                          ? Icons.lock_open
                          : Icons.block,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isBlocked
                          ? "Unblock"
                          : "Block",
                    ),
                  ],
                ),
              ),

              const PopupMenuItem(
                value: "report",
                child: Row(
                  children: [
                    Icon(Icons.report),
                    SizedBox(width: 10),
                    Text("Report"),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      body: isFriend
          ? Column(
              children: [

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("chats")
                  .doc(
                    currentUser.uid.compareTo(widget.receiverId) < 0
                        ? "${currentUser.uid}_${widget.receiverId}"
                        : "${widget.receiverId}_${currentUser.uid}",
                  )
                  .collection("messages")
                  .orderBy("timestamp")
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;

                    if (data["receiverId"] == currentUser.uid) {
                      if (data["delivered"] == false) {
                        doc.reference.update({
                          "delivered": true,
                        });
                      }

                      if (data["read"] == false) {
                        doc.reference.update({
                          "read": true,
                        });
                      }
                    }
                  }
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index];
                    final messageData = data.data() as Map<String, dynamic>;

                    List deletedFor = messageData["deletedFor"] ?? [];

                    if (deletedFor.contains(currentUser.uid)) {
                      return const SizedBox.shrink();
                    }

                    return messageBubble(
                      docs[index].id,
                      data["message"],
                      messageData["imageUrl"],
                      messageData["voiceUrl"],
                      data["senderId"] == currentUser.uid,
                      data.data().toString().contains("delivered")
                          ? data["delivered"]
                          : false,
                      data.data().toString().contains("read")
                          ? data["read"]
                          : false,
                      data["timestamp"],
                      messageData["deleted"] ?? false,
                      messageData["reaction"] ?? "",
                    );
                  },
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                IconButton(
                  onPressed: () async {
                    if (isBlocked) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("You have blocked this user"),
                        ),
                      );
                      return;
                    }
                  try {
                    final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );

                    if (image == null) return;

                    final file = File(image.path);

                    final fileName = DateTime.now().millisecondsSinceEpoch.toString();

                    final ref = FirebaseStorage.instance
                        .ref()
                        .child("chat_images")
                        .child(fileName);

                    await ref.putFile(file);

                    final imageUrl = await ref.getDownloadURL();

                    await FirebaseFirestore.instance
                        .collection("chats")
                        .doc(
                          currentUser.uid.compareTo(widget.receiverId) < 0
                              ? "${currentUser.uid}_${widget.receiverId}"
                              : "${widget.receiverId}_${currentUser.uid}",
                        )
                        .collection("messages")
                        .add({
                          "senderId": FirebaseAuth.instance.currentUser!.uid,
                          "receiverId": widget.receiverId,
                          "message": "",
                          "imageUrl": imageUrl,
                          "timestamp": FieldValue.serverTimestamp(),
                          "delivered": false,
                          "read": false,
                          "deletedFor": [],
                          "reaction": "",
                        });
                    print("Step 3");
                  } catch (e) {
                    print("ERROR: $e");
                  } 
                },
                  icon: const Icon(
                    Icons.image,
                    color: Colors.white,
                  ),
                ),

                Expanded(
                  child: TextField(
                        controller: messageController,
                        onChanged: (value) async {
                          await FirebaseFirestore.instance
                              .collection("users")
                              .doc(currentUser.uid)
                              .update({
                            "typingTo": value.isNotEmpty ? widget.receiverId : "",
                          });
                        },
                        style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Type message...",
                      hintStyle:
                          const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.white12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                IconButton(
                  onPressed: () async {

                    if (messageController.text.trim().isEmpty) return;
                    await checkBlockStatus();

                    if (isBlocked) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("You cannot message this user"),
                        ),
                      );
                      return;
                    }

                    if (isBlocked) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("You have blocked this user"),
                        ),
                      );
                      return;
                    }

                    String chatId;

                    if (currentUser.uid.compareTo(widget.receiverId) < 0) {
                      chatId = "${currentUser.uid}_${widget.receiverId}";
                    } else {
                      chatId = "${widget.receiverId}_${currentUser.uid}";
                    }

                    await FirebaseFirestore.instance
                        .collection("chats")
                        .doc(chatId)
                        .collection("messages")
                        .add({

                      "senderId": currentUser.uid,
                      "receiverId": widget.receiverId,
                      "message": messageController.text.trim(),
                      "timestamp": FieldValue.serverTimestamp(),

                      "delivered": false,
                      "read": false,
                      "deletedFor": [],
                      "reaction": "",

                    });
                    await FirebaseFirestore.instance
                        .collection("users")
                        .doc(currentUser.uid)
                        .update({
                      "typingTo": "",
                    });

                    messageController.clear();

                  },
                  icon: const Icon(
                    Icons.send,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    if (isBlocked) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("You have blocked this user"),
                        ),
                      );
                      return;
                    }
                    if (!isRecording) {
                      if (await audioRecorder.hasPermission()) {
                        final dir = await getTemporaryDirectory();

                        final path =
                            "${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a";

                        await audioRecorder.start(
                          const RecordConfig(),
                          path: path,
                        );

                        setState(() {
                          isRecording = true;
                        });
                      }
                    } else {
                      final path = await audioRecorder.stop();

                      setState(() {
                        isRecording = false;
                        recordedFilePath = path;
                      });

                      if (path != null) {
                        final file = File(path);

                        final ref = FirebaseStorage.instance
                            .ref()
                            .child("voice_messages")
                            .child("${DateTime.now().millisecondsSinceEpoch}.m4a");

                        await ref.putFile(file);

                        final voiceUrl = await ref.getDownloadURL();

                        print("Voice URL: $voiceUrl");
                        String chatId;

                        if (currentUser.uid.compareTo(widget.receiverId) < 0) {
                          chatId = "${currentUser.uid}_${widget.receiverId}";
                        } else {
                          chatId = "${widget.receiverId}_${currentUser.uid}";
                        }

                        await FirebaseFirestore.instance
                            .collection("chats")
                            .doc(chatId)
                            .collection("messages")
                            .add({
                          "senderId": currentUser.uid,
                          "receiverId": widget.receiverId,
                          "message": "",
                          "voiceUrl": voiceUrl,
                          "timestamp": FieldValue.serverTimestamp(),
                          "delivered": false,
                          "read": false,
                          "deletedFor": [],
                        });
                      }
                    }
                  },
                  icon: Icon(
                    isRecording ? Icons.stop : Icons.mic,
                    color: isRecording ? Colors.red : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      )
    : const Center(
        child: Text(
          "You can message only your friends",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
  Widget messageBubble(
    String messageId,
    String text,
    String? imageUrl,
    String? voiceUrl,
    bool me,
    bool delivered,
    bool read,
    Timestamp? timestamp,
    bool deleted,
    String reaction,  
  ) {
    return Align(
      alignment: me
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: GestureDetector(
    onLongPress: () {
      if (me) {

        showDialog(
          context: context,
          builder: (context) {

            return AlertDialog(
              title: const Text("Message"),
              content: const Text("What do you want to do?"),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),

                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);

                    String chatId;

                    if (currentUser.uid.compareTo(widget.receiverId) < 0) {
                      chatId = "${currentUser.uid}_${widget.receiverId}";
                    } else {
                      chatId = "${widget.receiverId}_${currentUser.uid}";
                    }

                    await FirebaseFirestore.instance
                        .collection("chats")
                        .doc(chatId)
                        .collection("messages")
                        .doc(messageId)
                        .update({
                      "deletedFor": FieldValue.arrayUnion([
                        currentUser.uid,
                      ]),
                    });
                  },
                  child: const Text("Delete for Me"),
                ),

                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);

                    String chatId;

                    if (currentUser.uid.compareTo(widget.receiverId) < 0) {
                      chatId = "${currentUser.uid}_${widget.receiverId}";
                    } else {
                      chatId = "${widget.receiverId}_${currentUser.uid}";
                    }

                    await FirebaseFirestore.instance
                        .collection("chats")
                        .doc(chatId)
                        .collection("messages")
                        .doc(messageId)
                        .update({
                      "message": "This message was deleted",
                      "deleted": true,
                    });
                  },
                  child: const Text("Delete for Everyone"),
                ),

              ],
            );

          },
        );

        return;
      }

      final emojis = [
        "👍",
        "❤️",
        "😂",
        "😮",
        "😢",
        "🙏",
      ];

      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Delete Message"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: emojis.map((emoji) {
                    return GestureDetector(
                      onTap: () async {

                        String chatId;

                        if (currentUser.uid.compareTo(widget.receiverId) < 0) {
                          chatId = "${currentUser.uid}_${widget.receiverId}";
                        } else {
                          chatId = "${widget.receiverId}_${currentUser.uid}";
                        }

                        await FirebaseFirestore.instance
                            .collection("chats")
                            .doc(chatId)
                            .collection("messages")
                            .doc(messageId)
                            .update({
                          "reaction": emoji,
                        });

                        Navigator.pop(context);
                      },
                      child: Text(
                        emoji,
                        style: const TextStyle(fontSize: 28),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 20),

                const Text("What do you want to do?"),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text("Cancel"),
              ),
            ],
          );
        },
      );
    },
    child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),

        decoration: BoxDecoration(
          color: me ? Colors.purpleAccent : Colors.white12,
          borderRadius: BorderRadius.circular(12),
        ),

        child: Column(
          crossAxisAlignment:
              me ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (voiceUrl != null && voiceUrl.isNotEmpty)
              VoiceMessageBubble(
                voiceUrl: voiceUrl,
                me: me,
              )
            else if (imageUrl != null && imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  imageUrl,
                  width: 200,
                  fit: BoxFit.cover,
               ),
              )
            else
              Text(
                deleted ? "🚫 This message was deleted" : text,
                style: TextStyle(
                  color: deleted ? Colors.white54 : Colors.white,
                  fontStyle:
                      deleted ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            if (reaction.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  reaction,
                  style: const TextStyle(fontSize: 22),
                ),
              ),

            const SizedBox(height: 5),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (timestamp != null)
                  Text(
                    TimeOfDay.fromDateTime(timestamp.toDate()).format(context),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),

                if (me) ...[
                  const SizedBox(width: 5),
                  Text(
                    read
                        ? "✓✓"
                        : delivered
                            ? "✓✓"
                            : "✓",
                    style: TextStyle(
                      fontSize: 12,
                      color: read ? Colors.blue : Colors.white70,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
}