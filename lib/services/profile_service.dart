import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // -----------------------------
  // Friend Status
  // -----------------------------
  static Future<Map<String, dynamic>> getFriendStatus({
    required String currentUserId,
    required String otherUserId,
  }) async {
    // Already Friends?
    final friends = await _firestore
        .collection("friends")
        .where("userId", isEqualTo: currentUserId)
        .where("friendId", isEqualTo: otherUserId)
        .get();

    if (friends.docs.isNotEmpty) {
      return {
        "status": "friends",
      };
    }

    // Request Sent?
    final sent = await _firestore
        .collection("friend_requests")
        .where("senderId", isEqualTo: currentUserId)
        .where("receiverId", isEqualTo: otherUserId)
        .where("status", isEqualTo: "pending")
        .get();

    if (sent.docs.isNotEmpty) {
      return {
        "status": "sent",
        "requestId": sent.docs.first.id,
      };
    }

    // Request Received?
    final received = await _firestore
        .collection("friend_requests")
        .where("senderId", isEqualTo: otherUserId)
        .where("receiverId", isEqualTo: currentUserId)
        .where("status", isEqualTo: "pending")
        .get();

    if (received.docs.isNotEmpty) {
      return {
        "status": "received",
        "requestId": received.docs.first.id,
      };
    }

    return {
      "status": "none",
    };
  }

  // -----------------------------
  // Send Friend Request
  // -----------------------------
  static Future<void> sendFriendRequest({
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

  // -----------------------------
  // Accept Request
  // -----------------------------
  static Future<void> acceptRequest(
    String requestId,
  ) async {
    final request = await _firestore
        .collection("friend_requests")
        .doc(requestId)
        .get();

    if (!request.exists) return;

    final data = request.data()!;

    final senderId = data["senderId"];
    final receiverId = data["receiverId"];

    await _firestore
        .collection("friend_requests")
        .doc(requestId)
        .update({
      "status": "accepted",
    });

    await _firestore.collection("friends").add({
      "userId": senderId,
      "friendId": receiverId,
      "createdAt": FieldValue.serverTimestamp(),
    });

    await _firestore.collection("friends").add({
      "userId": receiverId,
      "friendId": senderId,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  // -----------------------------
  // Reject Request
  // -----------------------------
  static Future<void> rejectRequest(
    String requestId,
  ) async {
    await _firestore
        .collection("friend_requests")
        .doc(requestId)
        .delete();
  }
}