import 'package:cloud_firestore/cloud_firestore.dart';

class FriendService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send Friend Request
  static Future<void> sendRequest({
    required String senderId,
    required String receiverId,
  }) async {
    await _firestore.collection("friend_requests").add({
      "senderId": senderId,
      "receiverId": receiverId,
      "status": "pending",
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  // Accept Friend Request
  static Future<void> acceptRequest(String requestId) async {
    final request = await _firestore
        .collection("friend_requests")
        .doc(requestId)
        .get();

    if (!request.exists) return;

    final data = request.data()!;

    final senderId = data["senderId"];
    final receiverId = data["receiverId"];

    // Update request status
    await _firestore
        .collection("friend_requests")
        .doc(requestId)
        .update({
      "status": "accepted",
    });

    // Save friend for sender
    await _firestore.collection("friends").add({
      "userId": senderId,
      "friendId": receiverId,
      "createdAt": FieldValue.serverTimestamp(),
    });

    // Save friend for receiver
    await _firestore.collection("friends").add({
      "userId": receiverId,
      "friendId": senderId,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  // Reject Friend Request
  static Future<void> rejectRequest(String requestId) async {
    await _firestore
        .collection("friend_requests")
        .doc(requestId)
        .delete();
  }
}