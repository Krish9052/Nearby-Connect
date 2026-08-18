import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/webrtc_service.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CallPage extends StatefulWidget {
  final String receiverName;
  final String receiverId;
  final String? callId;
  final bool isIncoming;
  final bool isVideoCall;

  const CallPage({
    super.key,
    required this.receiverName,
    required this.receiverId,
    this.callId,
    this.isIncoming = false,
    this.isVideoCall = false,
  });
  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {

  bool isMuted = false;
  bool speakerOn = false;

  Duration callDuration = Duration.zero;
  Timer? callTimer;
  Timer? ringingTimer;
  bool isConnected = false;
  bool callEnded = false;
  String? profileImage;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _profileSubscription;

  final WebRTCService _webRTCService = WebRTCService();
  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  String? _callId;

  @override
  void initState() {
    super.initState();
    localRenderer.initialize();
    remoteRenderer.initialize();
    _webRTCService.onRemoteStream = (stream) {
      if (!mounted) return;

      setState(() {
        remoteRenderer.srcObject = stream;
      });
    };
    _startCall();
    _loadProfileImage();
  }
  void _loadProfileImage() {
    // Edit Profile stores the permanent profile photo in users/{uid}.image.
    // Realtime listening keeps this call screen synced when the DP changes.
    final userId = widget.receiverId;

    _profileSubscription = FirebaseFirestore.instance
        .collection("users")
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
      final data = snapshot.data();

      // "image" is the current field. "profileImage" is kept only as a
      // fallback for any older user documents.
      final imageUrl =
          data?["image"]?.toString() ??
          data?["profileImage"]?.toString() ??
          "";

      if (!mounted) return;

      setState(() {
        profileImage = imageUrl.isEmpty ? null : imageUrl;
      });
    });
  }
  void _startTimer() {
    callTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;

        setState(() {
          callDuration += const Duration(seconds: 1);
        });
      },
    );
  }
  String _formatDuration(Duration duration) {
    final minutes =
        duration.inMinutes.remainder(60).toString().padLeft(2, '0');

    final seconds =
        duration.inSeconds.remainder(60).toString().padLeft(2, '0');

    return "$minutes:$seconds";
  }
  
  Future<void> _startCall() async {
    try {
      // 📞 Incoming call
      if (widget.isIncoming) {
        if (widget.callId == null) {
          throw Exception("Incoming call ID missing");
        }
        print("📹 CALL PAGE VIDEO MODE: ${widget.isVideoCall}");
        await _webRTCService.acceptCall(
          callId: widget.callId!,
          isVideo: widget.isVideoCall,
        );
        await _webRTCService.listenForCallEnd(
          callId: widget.callId!,
          onEnded: () async {
            if (!mounted || callEnded) return;

            callEnded = true;

            callTimer?.cancel();
            ringingTimer?.cancel();
        
            await _webRTCService.dispose();
        
            if (mounted) {
              Navigator.of(context).pop();
            }
          },
        );
        if (widget.isVideoCall &&
            _webRTCService.localStream != null) {
          localRenderer.srcObject =
              _webRTCService.localStream;
        }
        setState(() {
          isConnected = true;
        });
        _startTimer();
        print("✅ INCOMING CALL CONNECTED: ${widget.callId}");
  
        return;
      }
  
      // 📞 Outgoing call
      _callId = await _webRTCService.createCall(
        callerId: FirebaseAuth.instance.currentUser!.uid,
        receiverId: widget.receiverId,
        isVideo: widget.isVideoCall,
      );
      await _webRTCService.listenForCallEnd(
        callId: _callId!,
        onEnded: () async {
          if (!mounted || callEnded) return;

          callEnded = true;

          callTimer?.cancel();
          ringingTimer?.cancel();

          await _webRTCService.dispose();

          if (mounted) {
            Navigator.of(context).pop();
          }
        },
      );
      ringingTimer = Timer(
        const Duration(seconds: 30),
        () async {
          if (!mounted || isConnected || callEnded) return;

          callEnded = true;
          if (!widget.isIncoming) {
            await saveCallMessage(
              isVideo: widget.isVideoCall,
              duration: 0,
              missed: true,
            );
          }
          try {
            await FirebaseFirestore.instance
                .collection("calls")
                .doc(_callId)
                .update({
              "status": "ended",
            });
      
            await _webRTCService.dispose();
          } catch (e) {
            print("❌ RINGING TIMEOUT ERROR: $e");
          }
      
          if (mounted) {
            Navigator.pop(context);
          }
        },
      );
  
      await _webRTCService.initialize();
  
      final stream = await _webRTCService.getLocalMediaStream(
        video: widget.isVideoCall,
      );
      if (widget.isVideoCall) {
        localRenderer.srcObject = stream;
      }
  
      await _webRTCService.listenForIceCandidates(
        callId: _callId!,
        isCaller: true,
      );
  
      await _webRTCService.createOffer(
        callId: _callId!,
      );
  
      await _webRTCService.listenForAnswer(
        callId: _callId!,
        onConnected: () {
          if (!mounted) return;

          ringingTimer?.cancel();

          setState(() {
            isConnected = true;
          });

          _startTimer();
        },
      );
  
      await _webRTCService.listenForRemoteIceCandidates(
        callId: _callId!,
        isCaller: true,
      );
      await _webRTCService.listenForCallRejected(
        callId: _callId!,
        onRejected: () async {
          if (!mounted) return;
      
          print("❌ CLOSING CALL PAGE - RECEIVER REJECTED");
      
          callTimer?.cancel();
          if (!widget.isIncoming) {
            await saveCallMessage(
              isVideo: widget.isVideoCall,
              duration: 0,
              missed: true,
            );
          }
          await _webRTCService.dispose();
          if (mounted) {
            Navigator.pop(context);
          }
        },
      );
      print("📞 CALL STARTED: $_callId");
    } catch (e) {
      print("❌ CALL ERROR: $e");
    }
  }

  Widget _callControlButton({
    required String heroTag,
    required IconData icon,
    required VoidCallback onPressed,
    bool active = false,
    Color? activeColor,
    Color? backgroundColor,
    Color? iconColor,
    double size = 64,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: FloatingActionButton(
        heroTag: heroTag,
        elevation: 3,
        backgroundColor: backgroundColor ??
            (active
                ? (activeColor ?? const Color(0xFF6B4DB8))
                : const Color(0xFFE1DEEC)),
        foregroundColor: iconColor ?? const Color(0xFF0A1B4D),
        onPressed: onPressed,
        child: Icon(
          icon,
          size: size * 0.43,
        ),
      ),
    );
  }

  @override
  void dispose() {
    print("🚨 CALL PAGE DISPOSE");
    _profileSubscription?.cancel();
    ringingTimer?.cancel();
    callTimer?.cancel();
    localRenderer.dispose();
    remoteRenderer.dispose();
    _webRTCService.dispose();
    super.dispose();
  }
  Future<void> saveCallMessage({
    required bool isVideo,
    required int duration,
    required bool missed,
  }) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final otherUserId = widget.receiverId;

    final chatId = user.uid.compareTo(otherUserId) < 0
        ? "${user.uid}_$otherUserId"
        : "${otherUserId}_${user.uid}";
  
    await FirebaseFirestore.instance
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .add({
      "type": "call",
      "isVideo": isVideo,
      "callStatus": missed ? "missed" : "completed",
      "duration": duration,
      "senderId": user.uid,
      "receiverId": otherUserId,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0EDFF),
      body: SafeArea(
        child: widget.isVideoCall
            ? Stack(
                children: [
  
                  // =========================
                  // FULL SCREEN REMOTE VIDEO
                  // =========================
                  Positioned.fill(
                    child: RTCVideoView(
                      remoteRenderer,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
  
                  // =========================
                  // TOP NAME + STATUS
                  // =========================
                  Positioned(
                    top: 20,
                    left: 20,
                    right: 155,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.receiverName,
                          style: const TextStyle(
                            color: Color(0xFF0A1B4D),
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          isConnected ? "Connected" : "Calling...",
                          style: TextStyle(
                            color: isConnected
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFF68739A),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _formatDuration(callDuration),
                          style: const TextStyle(
                            color: Color(0xFF8A8EA5),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
  
                  // =========================
                  // SMALL LOCAL CAMERA
                  // =========================
                  Positioned(
                    top: 70,
                    right: 20,
                    width: 120,
                    height: 170,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        color: Colors.black,
                        child: RTCVideoView(
                          localRenderer,
                          mirror: true,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                      ),
                    ),
                  ),
  
                  // =========================
                  // BOTTOM CONTROLS
                  // =========================
                  Positioned(
                    bottom: 35,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
  
                        // MUTE
                        FloatingActionButton(
                          heroTag: "videoMute",
                          backgroundColor:
                              isMuted ? Colors.orange : Colors.white24,
                          onPressed: () {
                            setState(() {
                              isMuted = !isMuted;
                            });
  
                            final stream =
                                _webRTCService.localStream;
  
                            if (stream != null) {
                              for (final track
                                  in stream.getAudioTracks()) {
                                track.enabled = !isMuted;
                              }
                            }
                          },
                          child: Icon(
                            isMuted
                                ? Icons.mic_off
                                : Icons.mic,
                          ),
                        ),
  
                        const SizedBox(width: 20),
  
                        // END CALL
                        FloatingActionButton(
                          heroTag: "videoEnd",
                          backgroundColor: Colors.red,
                          onPressed: () async {
                            ringingTimer?.cancel();
                            callTimer?.cancel();
                            callEnded = true;
  
                            final activeCallId =
                                widget.callId ?? _callId;
  
                            if (activeCallId != null) {
                              await FirebaseFirestore.instance
                                  .collection("calls")
                                  .doc(activeCallId)
                                  .update({
                                "status": "ended",
                              });
                            }
  
                            await _webRTCService.dispose();
  
                            if (mounted) {
                              Navigator.pop(context);
                            }
                          },
                          child: const Icon(
                            Icons.call_end,
                          ),
                        ),
  
                        const SizedBox(width: 20),
  
                        // SWITCH CAMERA
                        FloatingActionButton(
                          heroTag: "switchCamera",
                          backgroundColor: Colors.white24,
                          onPressed: () async {
                            final stream =
                                _webRTCService.localStream;
  
                            if (stream == null) return;
  
                            final videoTracks =
                                stream.getVideoTracks();
  
                            if (videoTracks.isNotEmpty) {
                              await Helper.switchCamera(
                                videoTracks.first,
                              );
                            }
                          },
                          child: const Icon(
                            Icons.cameraswitch,
                          ),
                        ),
  
                        const SizedBox(width: 20),
  
                        // SPEAKER
                        FloatingActionButton(
                          heroTag: "videoSpeaker",
                          backgroundColor:
                              speakerOn
                                  ? Colors.green
                                  : Colors.white24,
                          onPressed: () async {
                            setState(() {
                              speakerOn = !speakerOn;
                            });
  
                            await Helper.setSpeakerphoneOn(
                              speakerOn,
                            );
                          },
                          child: Icon(
                            speakerOn
                                ? Icons.volume_up
                                : Icons.volume_off,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Profile photo — same white-border style as the app UI.
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 18,
                              offset: Offset(0, 7),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 88,
                          backgroundColor: const Color(0xFFE2E0ED),
                          backgroundImage:
                              profileImage != null &&
                                      profileImage!.isNotEmpty
                                  ? NetworkImage(profileImage!)
                                  : null,
                          child:
                              profileImage == null ||
                                      profileImage!.isEmpty
                                  ? const Icon(
                                      Icons.person_rounded,
                                      size: 82,
                                      color: Color(0xFF68739A),
                                    )
                                  : null,
                        ),
                      ),

                      const SizedBox(height: 28),

                      Text(
                        widget.receiverName,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF0A1B4D),
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(height: 18),

                      Text(
                        isConnected ? "Connected" : "Calling...",
                        style: TextStyle(
                          color: isConnected
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFF68739A),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        _formatDuration(callDuration),
                        style: const TextStyle(
                          color: Color(0xFF8A8EA5),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 82),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _callControlButton(
                            heroTag: "mute",
                            icon: isMuted
                                ? Icons.mic_off_rounded
                                : Icons.mic_rounded,
                            active: isMuted,
                            activeColor: const Color(0xFFFFA726),
                            onPressed: () {
                              setState(() {
                                isMuted = !isMuted;
                              });

                              final stream =
                                  _webRTCService.localStream;

                              if (stream != null) {
                                for (final track
                                    in stream.getAudioTracks()) {
                                  track.enabled = !isMuted;
                                }
                              }
                            },
                          ),

                          const SizedBox(width: 30),

                          _callControlButton(
                            heroTag: "end",
                            icon: Icons.call_end_rounded,
                            backgroundColor: const Color(0xFFFF3B30),
                            iconColor: Colors.white,
                            size: 72,
                            onPressed: () async {
                              ringingTimer?.cancel();
                              callEnded = true;
                              callTimer?.cancel();

                              if (!widget.isIncoming) {
                                await saveCallMessage(
                                  isVideo: widget.isVideoCall,
                                  duration: callDuration.inSeconds,
                                  missed: !isConnected,
                                );
                              }

                              final activeCallId =
                                  widget.callId ?? _callId;

                              if (activeCallId != null) {
                                await FirebaseFirestore.instance
                                    .collection("calls")
                                    .doc(activeCallId)
                                    .update({
                                  "status": "ended",
                                });
                              }

                              await _webRTCService.dispose();

                              if (mounted) {
                                Navigator.pop(context);
                              }
                            },
                          ),

                          const SizedBox(width: 30),

                          _callControlButton(
                            heroTag: "speaker",
                            icon: speakerOn
                                ? Icons.volume_up_rounded
                                : Icons.hearing_rounded,
                            active: speakerOn,
                            activeColor: const Color(0xFF6B4DB8),
                            onPressed: () async {
                              setState(() {
                                speakerOn = !speakerOn;
                              });

                              await Helper.setSpeakerphoneOn(
                                speakerOn,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),      ),
    );
  }
}