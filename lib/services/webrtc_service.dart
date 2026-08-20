import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class WebRTCService {
  void Function(MediaStream stream)? onRemoteStream;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  RTCPeerConnection? peerConnection;
  MediaStream? localStream;

  Future<bool> _isBlockedBetween(
    String userA,
    String userB,
  ) async {
    final aBlockedB = await _firestore
        .collection("blocks")
        .doc("${userA}_${userB}")
        .get();

    if (aBlockedB.exists) return true;

    final bBlockedA = await _firestore
        .collection("blocks")
        .doc("${userB}_${userA}")
        .get();

    return bBlockedA.exists;
  }

  Future<String> createCall({
    required String callerId,
    required String receiverId,
    bool isVideo = false,
  }) async {
    final blocked = await _isBlockedBetween(callerId, receiverId);

    if (blocked) {
      throw Exception("This user is blocked. Calls are not allowed.");
    }

    final callDoc = _firestore.collection("calls").doc();

    await callDoc.set({
      "callerId": callerId,
      "receiverId": receiverId,
      "status": "calling",
      "isVideo": isVideo,
      "offer": null,
      "answer": null,
      "createdAt": FieldValue.serverTimestamp(),
    });

    return callDoc.id;
  }

  Future<void> initialize() async {
    final Map<String, dynamic> configuration = {
      'iceServers': [
        {
          'urls': 'stun:stun.l.google.com:19302',
        },
      ],
    };

    peerConnection = await createPeerConnection(
      configuration,
    );
    peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        onRemoteStream?.call(event.streams.first);
      }
    };
  }

  Future<void> createOffer({
    required String callId,
  }) async {
    if (peerConnection == null) {
      await initialize();
    }

    final callDoc =
        _firestore.collection("calls").doc(callId);

    final offer = await peerConnection!.createOffer();

    await peerConnection!.setLocalDescription(offer);

    await callDoc.update({
      "offer": {
        "sdp": offer.sdp,
        "type": offer.type,
      },
    });
  }

  Future<void> listenForIceCandidates({
    required String callId,
    required bool isCaller,
  }) async {
    final collectionName =
        isCaller ? "callerCandidates" : "receiverCandidates";

    peerConnection!.onIceCandidate = (candidate) async {
      if (candidate.candidate == null) return;

      await _firestore
          .collection("calls")
          .doc(callId)
          .collection(collectionName)
          .add({
        "candidate": candidate.candidate,
        "sdpMid": candidate.sdpMid,
        "sdpMLineIndex": candidate.sdpMLineIndex,
      });
    };
  }

  Future<void> listenForCallOffer({
    required String callId,
  }) async {
    final callDoc =
        _firestore.collection("calls").doc(callId);

    callDoc.snapshots().listen((snapshot) async {
      final data = snapshot.data();

      if (data == null) return;

      final offerData = data["offer"];

      if (offerData == null) return;

      if (peerConnection == null) {
        await initialize();
      }

      final offer = RTCSessionDescription(
        offerData["sdp"],
        offerData["type"],
      );

      await peerConnection!.setRemoteDescription(offer);
    });
  }

  Future<void> createAnswer({
    required String callId,
  }) async {
    if (peerConnection == null) {
      await initialize();
    }

    final callDoc =
        _firestore.collection("calls").doc(callId);

    final answer = await peerConnection!.createAnswer();

    await peerConnection!.setLocalDescription(answer);

    await callDoc.update({
      "answer": {
        "sdp": answer.sdp,
        "type": answer.type,
      },
      "status": "connected",
    });
  }

  Future<void> acceptCall({
    required String callId,
    bool isVideo = false,
  }) async {
    final callDoc =
        _firestore.collection("calls").doc(callId);

    final snapshot = await callDoc.get();

    final data = snapshot.data();

    if (data == null) {
      throw Exception("Call not found");
    }

    final callerId = data["callerId"]?.toString();
    final receiverId = data["receiverId"]?.toString();

    if (callerId == null || receiverId == null) {
      throw Exception("Invalid call participants");
    }

    final blocked = await _isBlockedBetween(callerId, receiverId);

    if (blocked) {
      await callDoc.update({
        "status": "rejected",
      });
      throw Exception("This user is blocked. Calls are not allowed.");
    }

    if (peerConnection == null) {
      await initialize();
    }

    await getLocalMediaStream(
      video: isVideo,
    );

    await listenForIceCandidates(
      callId: callId,
      isCaller: false,
    );

    final offerData = data["offer"];

    if (offerData == null) {
      throw Exception("Call offer not found");
    }

    final offer = RTCSessionDescription(
      offerData["sdp"],
      offerData["type"],
    );

    await peerConnection!.setRemoteDescription(offer);

    await createAnswer(
      callId: callId,
    );

    await listenForRemoteIceCandidates(
      callId: callId,
      isCaller: false,
    );

    print("✅ CALL ACCEPTED: $callId");
  }

  Future<void> listenForAnswer({
    required String callId,
    required void Function() onConnected,
  }) async {
    final callDoc =
        _firestore.collection("calls").doc(callId);

    callDoc.snapshots().listen((snapshot) async {
      final data = snapshot.data();

      if (data == null) return;

      final answerData = data["answer"];

      if (answerData == null) return;

      final currentDescription =
          await peerConnection?.getRemoteDescription();

      if (currentDescription != null) return;

      final answer = RTCSessionDescription(
        answerData["sdp"],
        answerData["type"],
      );

      await peerConnection!.setRemoteDescription(answer);

      print("✅ Remote answer set");

      onConnected();
    });
  }

  Future<void> listenForRemoteIceCandidates({
    required String callId,
    required bool isCaller,
  }) async {
    final collectionName =
        isCaller ? "receiverCandidates" : "callerCandidates";

    _firestore
        .collection("calls")
        .doc(callId)
        .collection(collectionName)
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docChanges) {
        if (doc.type != DocumentChangeType.added) continue;

        final data = doc.doc.data();

        if (data == null) continue;

        final candidate = RTCIceCandidate(
          data["candidate"],
          data["sdpMid"],
          data["sdpMLineIndex"],
        );

        await peerConnection?.addCandidate(candidate);
      }
    });
  }
  Future<void> listenForCallEnd({
    required String callId,
    required VoidCallback onEnded,
  }) async {
    final callDoc = _firestore
        .collection("calls")
        .doc(callId);
  
    callDoc.snapshots().listen((snapshot) {
      final data = snapshot.data();
  
      if (data == null) return;
  
      final status = data["status"]?.toString();
  
      print("📞 CALL STATUS: $status");
  
      if (status == "ended") {
        print("📞 CALL ENDED: $callId");
        onEnded();
      }
    });
  }
  Future<void> listenForCallRejected({
    required String callId,
    required VoidCallback onRejected,
  }) async {
    final callDoc =
        _firestore.collection("calls").doc(callId);

    callDoc.snapshots().listen((snapshot) {
      final data = snapshot.data();

      if (data == null) return;

      final status = data["status"]?.toString();

      print("📞 REJECT LISTENER STATUS: $status");

      if (status == "rejected") {
        print("❌ CALL REJECTED BY RECEIVER: $callId");
        onRejected();
      }
    });
  }

  Future<MediaStream> getLocalMediaStream({
    bool video = false,
  }) async {
    localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': video,
    });
  
    for (final track in localStream!.getTracks()) {
      await peerConnection?.addTrack(
        track,
        localStream!,
      );
    }
  
    return localStream!;
  }

  Future<void> dispose() async {
    await localStream?.dispose();
    await peerConnection?.close();

    localStream = null;
    peerConnection = null;
  }
}