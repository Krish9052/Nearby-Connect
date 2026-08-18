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
import 'call_page.dart';

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
    final ScrollController _chatScrollController = ScrollController();

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

    @override
    void dispose() {
      _chatScrollController.dispose();
      messageController.dispose();
      audioRecorder.dispose();
      super.dispose();
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
    Future<void> _markMessagesAsRead(
      List<QueryDocumentSnapshot> docs,
    ) async {
      final batch = FirebaseFirestore.instance.batch();
    
      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
    
        if (data["receiverId"] == currentUser.uid &&
            data["read"] == false) {
          batch.update(doc.reference, {
            "read": true,
            "delivered": true,
          });
        }
      }
    
      await batch.commit();
    }
    
    Future<void> _openCall({required bool video}) async {
      if (isBlocked) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("You cannot call this user"),
          ),
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CallPage(
            receiverName: widget.receiverName,
            receiverId: widget.receiverId,
            isVideoCall: video,
          ),
        ),
      );
    }

    @override
    Widget build(BuildContext context) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0EDFF),

        appBar: AppBar(
        backgroundColor: const Color(0xFFF0EDFF),
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(
          color: Color(0xFF0A1B4D),
        ),
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
                Text(
                  widget.receiverName,
                  style: const TextStyle(
                    color: Color(0xFF0A1B4D),
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  typing ? "Typing..." : "",
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B4DB8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            tooltip: "Audio call",
            onPressed: () => _openCall(video: false),
            icon: const Icon(
              Icons.call_rounded,
              color: Color(0xFF0A1B4D),
              size: 27,
            ),
          ),
          IconButton(
            tooltip: "Video call",
            onPressed: () => _openCall(video: true),
            icon: const Icon(
              Icons.videocam_rounded,
              color: Color(0xFF0A1B4D),
              size: 29,
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              color: Color(0xFF0A1B4D),
              size: 30,
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
              
                //testing
                print("CHAT PAGE RECEIVER: ${widget.receiverId}");

                final debugChatId =
                    currentUser.uid.compareTo(widget.receiverId) < 0
                        ? "${currentUser.uid}_${widget.receiverId}"
                        : "${widget.receiverId}_${currentUser.uid}";

                print("CHAT PAGE CHAT ID: $debugChatId");
                print("CHAT PAGE MESSAGES: ${snapshot.data?.docs.length ?? 0}");
                //
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }
                final docs = snapshot.data!.docs;
                _markMessagesAsRead(docs);

                // Find first unread message
                int firstUnreadIndex = -1;
                
                for (int i = 0; i < docs.length; i++) {
                  final data = docs[i].data() as Map<String, dynamic>;
                
                  if (data["receiverId"] == currentUser.uid &&
                      data["read"] == false) {
                    firstUnreadIndex = i;
                    break;
                  }
                }
                
                // Scroll to first unread message
                if (firstUnreadIndex != -1) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!_chatScrollController.hasClients) return;
                
                    const double messageHeight = 90.0;
                
                    final position =
                firstUnreadIndex * messageHeight;
                
                    _chatScrollController.jumpTo(
                      position.clamp(
                        0.0,
                        _chatScrollController.position.maxScrollExtent,
                      ),
                    );
                  });
                }
                
                // Mark messages as delivered/read
                for (var doc in docs) {
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

                return ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index];
                    final messageData =
                        data.data() as Map<String, dynamic>;

                    final List deletedFor =
                        (messageData["deletedFor"] as List?) ?? [];

                    if (deletedFor.contains(currentUser.uid)) {
                      return const SizedBox.shrink();
                    }

                    // Normal text messages have "message".
                    // Call messages intentionally do not; CallPage stores
                    // type/isVideo/callStatus instead. Build a safe preview
                    // so a call record can never crash the chat list.
                    String displayMessage =
                        messageData["message"]?.toString() ?? "";

                    if (messageData["type"]?.toString() == "call") {
                      final bool isVideo =
                          messageData["isVideo"] == true;
                      final String status =
                          messageData["callStatus"]?.toString() ?? "";

                      if (status == "missed") {
                        displayMessage = isVideo
                            ? "📹 Missed video call"
                            : "📞 Missed audio call";
                      } else {
                        displayMessage = isVideo
                            ? "📹 Video call"
                            : "📞 Audio call";
                      }
                    }

                    // Call history is shown as a divider notification,
                    // not as a normal chat bubble.
                    if (messageData["type"]?.toString() == "call") {
                      final bool isVideo =
                          messageData["isVideo"] == true;
                      final String status =
                          messageData["callStatus"]?.toString() ?? "";
                      final bool missed = status == "missed";

                      return _callDivider(
                        isVideo: isVideo,
                        missed: missed,
                        timestamp: messageData["timestamp"] as Timestamp?,
                        me: messageData["senderId"] == currentUser.uid,
                      );
                    }

                    return messageBubble(
                      docs[index].id,
                      displayMessage,
                      messageData["imageUrl"]?.toString(),
                      messageData["voiceUrl"]?.toString(),
                      messageData["senderId"] == currentUser.uid,
                      messageData["delivered"] == true,
                      messageData["read"] == true,
                      messageData["timestamp"] as Timestamp?,
                      messageData["deleted"] == true,
                      messageData["reaction"]?.toString() ?? "",
                    );
                  },
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
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
                    Icons.image_rounded,
                    color: Color(0xFF0A1B4D),
                    size: 28,
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
                        style: const TextStyle(
                          color: Color(0xFF0A1B4D),
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                    decoration: InputDecoration(
                      hintText: "Type message...",
                      hintStyle: const TextStyle(
                        color: Color(0xFF8A8EA5),
                        fontSize: 16,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: Color(0xFFD5D1E8),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: const BorderSide(
                          color: Color(0xFF6B4DB8),
                          width: 1.8,
                        ),
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
                    Icons.send_rounded,
                    color: Color(0xFF0A1B4D),
                    size: 29,
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

                        //testing
                        print("CHAT PAGE RECEIVER: ${widget.receiverId}");
                        print("CHAT PAGE CHAT ID: $chatId");
                        //
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
                    isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: isRecording
                        ? Colors.red
                        : const Color(0xFF0A1B4D),
                    size: 29,
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
            color: Color(0xFF0A1B4D),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
  Widget _callDivider({
    required bool isVideo,
    required bool missed,
    required Timestamp? timestamp,
    required bool me,
  }) {
    final time = timestamp == null
        ? ""
        : TimeOfDay.fromDateTime(timestamp.toDate()).format(context);

    final label = missed
        ? (isVideo ? "Missed video call" : "Missed audio call")
        : (isVideo ? "Video call" : "Audio call");

    final icon = isVideo ? Icons.videocam_rounded : Icons.call_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
      child: Row(
        children: [
          const Expanded(
            child: Divider(
              color: Color(0xFFD5D1E8),
              thickness: 1.2,
            ),
          ),
          const SizedBox(width: 10),
          Icon(
            icon,
            size: 22,
            color: const Color(0xFF68739A),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF68739A),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (time.isNotEmpty) ...[
            const SizedBox(width: 7),
            Text(
              time,
              style: const TextStyle(
                color: Color(0xFF9A9CAF),
                fontSize: 11,
              ),
            ),
          ],
          const SizedBox(width: 10),
          const Expanded(
            child: Divider(
              color: Color(0xFFD5D1E8),
              thickness: 1.2,
            ),
          ),
        ],
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
                          "imageUrl": FieldValue.delete(),
                          "voiceUrl": FieldValue.delete(),
                          "reaction": "",
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

        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: me
              ? const Color(0xFFB53BFF)
              : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(22),
            topRight: const Radius.circular(22),
            bottomLeft: Radius.circular(me ? 22 : 6),
            bottomRight: Radius.circular(me ? 6 : 22),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x18000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment:
              me ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (deleted)
              Text(
                "🚫 This message was deleted",
                style: TextStyle(
                  color: me
                      ? Colors.white70
                      : const Color(0xFF68739A),
                  fontStyle: FontStyle.italic,
                ),
              )
            else if (voiceUrl != null && voiceUrl.isNotEmpty)
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
                text,
                style: TextStyle(
                  color: me
                      ? Colors.white
                      : const Color(0xFF0A1B4D),
                  fontSize: 16,
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
                    style: TextStyle(
                      color: me
                          ? Colors.white70
                          : const Color(0xFF8A8EA5),
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
                      color: read
                          ? const Color(0xFF5BA7FF)
                          : (me
                              ? Colors.white70
                              : const Color(0xFF8A8EA5)),
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