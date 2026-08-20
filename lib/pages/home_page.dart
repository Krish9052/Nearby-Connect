import 'friends_page.dart';
import '../services/friend_service.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'requests_page.dart';
import 'login_page.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'profile_view_page.dart';
import 'my_profile_page.dart';
import 'chat_list_page.dart';
import 'call_page.dart';
import 'dart:async';
import '../theme/app_theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
 State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with WidgetsBindingObserver {
  final currentUser = FirebaseAuth.instance.currentUser;
  StreamSubscription<QuerySnapshot>? _incomingCallSubscription;

  double? myLatitude;
  double? myLongitude;

  bool _incomingCallDialogOpen = false;
  String? _incomingCallId;

  Future<void> loadMyLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUser!.uid)
        .update({
      "latitude": position.latitude,
      "longitude": position.longitude,
    });

    setState(() {
      myLatitude = position.latitude;
      myLongitude = position.longitude;
    });
  }
  double calculateDistance(
    double lat,
    double lng,
  ) {
    if (myLatitude == null || myLongitude == null) {
      return double.infinity;
    }

    return Geolocator.distanceBetween(
          myLatitude!,
          myLongitude!,
          lat,
          lng,
        ) /
        1000; // meters → kilometers
  }
  String formatLastSeen(Timestamp? timestamp) {
    if (timestamp == null) return "Offline";

    final date = timestamp.toDate();

    return "Last seen ${DateFormat("hh:mm a").format(date)}";
  }
  Future<void> updateOnlineStatus(bool isOnline) async {
    await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUser!.uid)
        .update({
      "isOnline": isOnline,
      "lastSeen": FieldValue.serverTimestamp(),
    });
  }
  @override
void didChangeAppLifecycleState(AppLifecycleState state) {
  if (state == AppLifecycleState.resumed) {
    updateOnlineStatus(true);
  } else if (state == AppLifecycleState.paused ||
      state == AppLifecycleState.detached) {
    updateOnlineStatus(false);
  }
}
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadMyLocation();
    updateOnlineStatus(true);
    _listenForIncomingCalls();
  }
  void _listenForIncomingCalls() {
    _incomingCallSubscription = FirebaseFirestore.instance
        .collection("calls")
        .where(
          "receiverId",
          isEqualTo: currentUser!.uid,
        )
        .where(
          "status",
          isEqualTo: "calling",
        )
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isEmpty) return;
  
      // Latest/newest calling document
      final callDoc = snapshot.docs.last;
      final data = callDoc.data();
      final bool incomingIsVideo = data["isVideo"] == true;

      print("📹 INCOMING CALL TYPE: ${data["isVideo"]}");
      print("📹 B VIDEO MODE: $incomingIsVideo");
  
      final callId = callDoc.id;
  
      // Same popup already open
      if (_incomingCallDialogOpen) return;
  
      _incomingCallDialogOpen = true;
      _incomingCallId = callId;
  
      final callerId = data["callerId"];
  
      final callerSnapshot = await FirebaseFirestore.instance
          .collection("users")
          .doc(callerId)
          .get();
  
      final callerData = callerSnapshot.data();
  
      final callerName =
          callerData?["name"]?.toString() ?? "Unknown User";
  
      if (!mounted) return;
  
      // Listen to THIS call document for ended/rejected
      final callEndSubscription = callDoc.reference.snapshots().listen(
        (updatedSnapshot) {
          if (!updatedSnapshot.exists) return;
  
          final updatedData = updatedSnapshot.data();
          final updatedStatus = updatedData?["status"]?.toString();
  
          if (updatedStatus == "ended") {
            if (_incomingCallId == callId) {
              _incomingCallDialogOpen = false;
              _incomingCallId = null;
  
              if (mounted) {
                Navigator.of(context, rootNavigator: true).pop();
              }
            }
          }
        },
      );
  
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              "Incoming Call from $callerName",
            ),
            content: Text(
              "$callerName is calling you",
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  print("❌ B REJECT PRESSED: ${callDoc.id}");
                  await callDoc.reference.update({
                    "status": "rejected",
                  });
                  print("❌ B REJECT STATUS UPDATED");
  
                  await callEndSubscription.cancel();
  
                  _incomingCallDialogOpen = false;
                  _incomingCallId = null;
  
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext, rootNavigator: true).pop();
                  }
                },
                child: const Text("Reject"),
              ),
              ElevatedButton(
                onPressed: () async {
                  await callEndSubscription.cancel();
  
                  _incomingCallDialogOpen = false;
                  _incomingCallId = null;
  
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
  
                  if (!mounted) return;
  
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CallPage(
                        receiverName: callerName,
                        receiverId: callerId,
                        callId: callDoc.id,
                        isIncoming: true,
                        isVideoCall: incomingIsVideo,
                      ),
                    ),
                  );
                },
                child: const Text("Accept"),
              ),
            ],
          );
        },
      );
    });
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    updateOnlineStatus(false);
    super.dispose();
  }
  String selectedMomentActivity = "";
  File? selectedMomentPhoto;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text(
          "Nearby People",
           
           style: const TextStyle(
             color: AppTheme.textDark,
             fontSize: 22,
             fontWeight: FontWeight.w700,
           ),
          ),
          actions: [

            // My Profile
            IconButton(
              icon: const Icon(
                Icons.account_circle,
                color: AppTheme.textDark,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const MyProfilePage(),
                  ),
                );
              },
            ),
            // Friend Requests
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("friend_requests")
                  .where(
                    "receiverId",
                    isEqualTo: FirebaseAuth.instance.currentUser!.uid,
                  )
                  .where(
                    "status",
                    isEqualTo: "pending",
                  )
                  .snapshots(),
              builder: (context, snapshot) {
                final count = snapshot.data?.docs.length ?? 0;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.notifications,
                        color: AppTheme.textDark,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const RequestsPage(),
                          ),
                        );
                      },
                    ),

                    if (count > 0)
                      Positioned(
                        right: 4,
                        top: 2,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            // Friends List
            IconButton(
              icon: const Icon(Icons.people),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const FriendsPage(),
                  ),
                );
              },
            ),

            // 💬 Chat
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("friends")
                  .where(
                    "userId",
                    isEqualTo: FirebaseAuth.instance.currentUser!.uid,
                  )
                  .snapshots(),
            
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return IconButton(
                    icon: const Icon(
                      Icons.chat_bubble_outline,
                      color: AppTheme.textDark,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChatListPage(),
                        ),
                      );
                    },
                  );
                }
              
                return _HomeChatButton(
                  friends: snapshot.data!.docs,
                );
              },
            ),
          ],
        ),
      body: Column(
        children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
                child: GestureDetector(
                  onTap: () async {
                    final userDoc = await FirebaseFirestore.instance
                        .collection("users")
                        .doc(currentUser!.uid)
                        .get();

                    final data = userDoc.data() as Map<String, dynamic>?;

                    final bool isVisible = data?["activityVisible"] == true;

                    if (isVisible) {
                      selectedMomentActivity = data?["activity"]?.toString() ?? "";
                    } else {
                      selectedMomentActivity = "";
                    }
                    
                    final homeContext = context;

                    // Keep Moment state outside the sheet builder so scrolling/
                    // rebuilding the bottom sheet cannot reset Save -> Delete state.
                    bool momentSaved = false;
                    bool momentDeleted = false;
                    bool momentExists = isVisible;

                    showModalBottomSheet(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (context) {
                        return StatefulBuilder(
                          builder: (context, sheetSetState) {
                            Future<void> pickMomentPhoto(ImageSource source) async {
                              final ImagePicker picker = ImagePicker();

                              final XFile? image = await picker.pickImage(
                                source: source,
                                imageQuality: 85,
                              );

                              if (image == null) return;

                              final CroppedFile? croppedImage =
                                  await ImageCropper().cropImage(
                                sourcePath: image.path,
                                aspectRatio: const CropAspectRatio(
                                  ratioX: 4,
                                  ratioY: 3,
                                ),
                                uiSettings: [
                                  AndroidUiSettings(
                                    toolbarTitle: 'Resize Your Moment Photo',
                                    toolbarColor: const Color(0xFF0A1B4D),
                                    toolbarWidgetColor: Colors.white,
                                    lockAspectRatio: false,
                                  ),
                                  IOSUiSettings(
                                    title: 'Resize Your Moment Photo',
                                  ),
                                ],
                              );

                              if (croppedImage == null) return;

                              sheetSetState(() {
                                selectedMomentPhoto = File(croppedImage.path);
                              });
                            }

                            const activities = <String, IconData>{
                              "☕ Coffee": Icons.local_cafe_outlined,
                              "🍽️ Dinner": Icons.restaurant_outlined,
                              "🍕 Having Food": Icons.fastfood_outlined,
                              "🎬 Movie": Icons.movie_outlined,
                              "🎵 Music": Icons.music_note_outlined,
                              "🎮 Gaming": Icons.sports_esports_outlined,
                              "🚶 Walk": Icons.directions_walk_outlined,
                              "🏋️ Workout": Icons.fitness_center_outlined,
                              "📚 Studying": Icons.menu_book_outlined,
                              "💻 Working": Icons.laptop_mac_outlined,
                              "😴 Sleeping": Icons.bed_outlined,
                              "💬 Free to Chat": Icons.chat_bubble_outline,
                              "🏖️ Chilling": Icons.beach_access_outlined,
                            };

                            return SafeArea(
                              top: false,
                              child: Container(
                                constraints: BoxConstraints(
                                  maxHeight: MediaQuery.of(context).size.height * 0.88,
                                ),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(30),
                                  ),
                                ),
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Center(
                                        child: Container(
                                          width: 42,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE2E8F0),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 22),
                                      const Text(
                                        "What are you up to?",
                                        style: TextStyle(
                                          color: AppTheme.textDark,
                                          fontSize: 24,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        "Choose a moment to share with people nearby.",
                                        style: TextStyle(
                                          color: Color(0xFF64748B),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      Wrap(
                                        spacing: 9,
                                        runSpacing: 10,
                                        children: activities.entries.map((entry) {
                                          final bool selected =
                                              selectedMomentActivity == entry.key;

                                          return FilterChip(
                                            selected: selected,
                                            showCheckmark: false,
                                            // The activity name already contains
                                            // its emoji (☕, 🍽️, 🎬, etc.).
                                            // Do not add a second Material icon here.
                                            label: Text(entry.key),
                                            labelStyle: TextStyle(
                                              color: selected
                                                  ? const Color(0xFF0A1B4D)
                                                  : const Color(0xFF334155),
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                            ),
                                            selectedColor: const Color(0xFFE0F2FE),
                                            backgroundColor: const Color(0xFFF8FAFC),
                                            side: BorderSide(
                                              color: selected
                                                  ? const Color(0xFF38BDF8)
                                                  : const Color(0xFFE2E8F0),
                                              width: selected ? 1.4 : 1,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                            onSelected: (_) {
                                              sheetSetState(() {
                                                selectedMomentActivity = entry.key;
                                              });
                                            },
                                          );
                                        }).toList(),
                                      ),
                                      const SizedBox(height: 22),
                                      if (!momentExists)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              "Moment photo",
                                              style: TextStyle(
                                                color: AppTheme.textDark,
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 9),
                                            if (selectedMomentPhoto != null)
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(18),
                                                child: Image.file(
                                                  selectedMomentPhoto!,
                                                  width: double.infinity,
                                                  height: 150,
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            if (selectedMomentPhoto != null)
                                              const SizedBox(height: 10),
                                            SizedBox(
                                              width: double.infinity,
                                              height: 52,
                                              child: OutlinedButton.icon(
                                                onPressed: () {
                                                  showModalBottomSheet(
                                                    context: context,
                                                    backgroundColor: Colors.transparent,
                                                    builder: (photoContext) {
                                                      return SafeArea(
                                                        child: Container(
                                                          margin: const EdgeInsets.all(12),
                                                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                                                          decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius: BorderRadius.circular(24),
                                                            boxShadow: const [
                                                              BoxShadow(
                                                                color: Color(0x22000000),
                                                                blurRadius: 20,
                                                                offset: Offset(0, 8),
                                                              ),
                                                            ],
                                                          ),
                                                          child: Column(
                                                            mainAxisSize: MainAxisSize.min,
                                                            children: [
                                                              ListTile(
                                                                leading: Container(
                                                                  width: 42,
                                                                  height: 42,
                                                                  decoration: BoxDecoration(
                                                                    color: const Color(0xFFE0F2FE),
                                                                    borderRadius: BorderRadius.circular(12),
                                                                  ),
                                                                  child: const Icon(
                                                                    Icons.camera_alt_outlined,
                                                                    color: Color(0xFF0A1B4D),
                                                                  ),
                                                                ),
                                                                title: const Text(
                                                                  "Take a Photo",
                                                                  style: TextStyle(
                                                                    color: AppTheme.textDark,
                                                                    fontWeight: FontWeight.w700,
                                                                  ),
                                                                ),
                                                                onTap: () async {
                                                                  Navigator.pop(photoContext);
                                                                  await pickMomentPhoto(ImageSource.camera);
                                                                },
                                                              ),
                                                              ListTile(
                                                                leading: Container(
                                                                  width: 42,
                                                                  height: 42,
                                                                  decoration: BoxDecoration(
                                                                    color: const Color(0xFFE0F2FE),
                                                                    borderRadius: BorderRadius.circular(12),
                                                                  ),
                                                                  child: const Icon(
                                                                    Icons.photo_library_outlined,
                                                                    color: Color(0xFF0A1B4D),
                                                                  ),
                                                                ),
                                                                title: const Text(
                                                                  "Choose from Gallery",
                                                                  style: TextStyle(
                                                                    color: AppTheme.textDark,
                                                                    fontWeight: FontWeight.w700,
                                                                  ),
                                                                ),
                                                                onTap: () async {
                                                                  Navigator.pop(photoContext);
                                                                  await pickMomentPhoto(ImageSource.gallery);
                                                                },
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  );
                                                },
                                                icon: const Icon(
                                                  Icons.add_a_photo_outlined,
                                                  color: Color(0xFF0A1B4D),
                                                ),
                                                label: Text(
                                                  selectedMomentPhoto == null
                                                      ? "Add a Photo"
                                                      : "Change Photo",
                                                  style: const TextStyle(
                                                    color: Color(0xFF0A1B4D),
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(
                                                    color: Color(0xFFCBD5E1),
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(16),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      if (momentSaved)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 16),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                color: Color(0xFF16A34A),
                                                size: 20,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                "Your Moment saved successfully!",
                                                style: TextStyle(
                                                  color: Color(0xFF15803D),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      if (momentDeleted)
                                        const Padding(
                                          padding: EdgeInsets.only(top: 16),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.delete_outline,
                                                color: Color(0xFFDC2626),
                                                size: 20,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                "Your Moment deleted successfully!",
                                                style: TextStyle(
                                                  color: Color(0xFFB91C1C),
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      const SizedBox(height: 18),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 54,
                                        child: momentExists
                                            ? OutlinedButton.icon(
                                                onPressed: () async {
                                                  try {
                                                    await FirebaseFirestore.instance
                                                        .collection("users")
                                                        .doc(currentUser!.uid)
                                                        .update({
                                                      "activityVisible": false,
                                                      "activity": FieldValue.delete(),
                                                      "activityPhoto": FieldValue.delete(),
                                                      "activityUpdatedAt": FieldValue.delete(),
                                                    });

                                                    sheetSetState(() {
                                                      momentExists = false;
                                                      momentSaved = false;
                                                      selectedMomentActivity = "";
                                                      selectedMomentPhoto = null;
                                                      momentDeleted = true;
                                                    });

                                                    Future.delayed(const Duration(seconds: 2), () {
                                                      if (!context.mounted) return;

                                                      sheetSetState(() {
                                                        momentDeleted = false;
                                                      });
                                                    });
                                                  } catch (e) {
                                                    if (!context.mounted) return;

                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(
                                                        content: Text("Failed to delete: $e"),
                                                      ),
                                                    );
                                                  }
                                                },
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                  color: Color(0xFFDC2626),
                                                ),
                                                label: const Text(
                                                  "Delete Moment",
                                                  style: TextStyle(
                                                    color: Color(0xFFDC2626),
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                style: OutlinedButton.styleFrom(
                                                  side: const BorderSide(
                                                    color: Color(0xFFFCA5A5),
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(17),
                                                  ),
                                                ),
                                              )
                                            : ElevatedButton.icon(
                                                onPressed: selectedMomentActivity.isEmpty
                                                    ? null
                                                    : () async {
                                                        try {
                                                          String? activityPhoto;

                                                          if (selectedMomentPhoto != null) {
                                                            final request = http.MultipartRequest(
                                                              'POST',
                                                              Uri.parse(
                                                                'https://api.cloudinary.com/v1_1/pdkqvivw/image/upload',
                                                              ),
                                                            );

                                                            request.fields["upload_preset"] =
                                                                "nearby_profile";

                                                            request.files.add(
                                                              await http.MultipartFile.fromPath(
                                                                "file",
                                                                selectedMomentPhoto!.path,
                                                              ),
                                                            );

                                                            final response = await request.send();
                                                            final responseData =
                                                                await response.stream.bytesToString();

                                                            if (response.statusCode != 200) {
                                                              throw Exception(
                                                                "Cloudinary upload failed: ${response.statusCode}\n$responseData",
                                                              );
                                                            }

                                                            final jsonData = jsonDecode(responseData);
                                                            activityPhoto =
                                                                jsonData["secure_url"]?.toString();

                                                            if (activityPhoto == null ||
                                                                activityPhoto!.isEmpty) {
                                                              throw Exception("Photo URL not received");
                                                            }
                                                          }

                                                          final Map<String, dynamic> momentData = {
                                                            "activity": selectedMomentActivity,
                                                            "activityVisible": true,
                                                            "activityUpdatedAt":
                                                                FieldValue.serverTimestamp(),
                                                          };

                                                          if (activityPhoto != null) {
                                                            momentData["activityPhoto"] = activityPhoto;
                                                          }

                                                          await FirebaseFirestore.instance
                                                              .collection("users")
                                                              .doc(currentUser!.uid)
                                                              .update(momentData);

                                                          sheetSetState(() {
                                                            momentExists = true;
                                                            momentSaved = true;
                                                          });

                                                          Future.delayed(
                                                            const Duration(seconds: 2),
                                                            () {
                                                              if (!context.mounted) return;

                                                              sheetSetState(() {
                                                                momentSaved = false;
                                                              });
                                                            },
                                                          );
                                                        } catch (e) {
                                                          if (!mounted) return;

                                                          ScaffoldMessenger.of(homeContext).showSnackBar(
                                                            SnackBar(
                                                              content: Text("Failed: $e"),
                                                              duration: const Duration(seconds: 6),
                                                            ),
                                                          );
                                                        }
                                                      },
                                                icon: const Icon(Icons.check_rounded),
                                                label: const Text(
                                                  "Save Moment",
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF2563EB),
                                                  foregroundColor: Colors.white,
                                                  disabledBackgroundColor: const Color(0xFFE2E8F0),
                                                  disabledForegroundColor: const Color(0xFF94A3B8),
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(17),
                                                  ),
                                                ),
                                              ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              "✨",
                              style: TextStyle(fontSize: 24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(                          
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Your Moment",
                                style: TextStyle(
                                  color: AppTheme.textDark,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Share what you're up to",
                                style: TextStyle(
                                  color: const Color(0xFF64748B),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.add_circle_outline,
                          color: AppTheme.textDark,
                          size: 30,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
    Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("users").snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No users found",
                style: const TextStyle(
             color: AppTheme.textDark,
             fontSize: 22,
             fontWeight: FontWeight.w700,
           ),
              ),
            );
          }

          final users = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              if (!user.data().toString().contains("latitude") ||
                  !user.data().toString().contains("longitude")) {
                return const SizedBox.shrink();
              }

              final double userLat = (user["latitude"] as num).toDouble();
              final double userLng = (user["longitude"] as num).toDouble();

              final double distance = calculateDistance(
                userLat,
                userLng,
              );
              final bool isOnline =
                  user.data().toString().contains("isOnline") &&
                  user["isOnline"] == true;

                  final Timestamp? lastSeen =
                      user.data().toString().contains("lastSeen")
                          ? user["lastSeen"]
                          : null;

              // Hide current user
              if (user["uid"] == currentUser?.uid) {
                return const SizedBox.shrink();
              }
              if (distance > 5) {
                return const SizedBox.shrink();
              }

              return InkWell(
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
                child: Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFE2E8F0),
                    backgroundImage:
                        (user["image"] != null && user["image"] != "")
                            ? NetworkImage(user["image"])
                            : null,
                    child: (user["image"] == null || user["image"] == "")
                        ? const Icon(
                            Icons.person,
                            size: 45,
                            color: Color(0xFF1E293B),
                          )
                        : null,
                  ),
                  title: Text(
                    user["name"] ?? "",
                    style: const TextStyle(
                      color: AppTheme.textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 19,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (context) {
                          final userData = user.data() as Map<String, dynamic>;
                          final activity = userData["activity"]?.toString() ?? "";
                          final bool activityVisible =
                              userData["activityVisible"] == true;
                          final activityPhoto =
                              userData["activityPhoto"]?.toString() ?? "";

                          if (activity.isEmpty || !activityVisible) {
                            return const SizedBox.shrink();
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 3, bottom: 5),
                                child: Text(
                                  activity,
                                  style: const TextStyle(
                                    color: AppTheme.textDark,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          
                              if (activityPhoto.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: GestureDetector(
                                    onTap: () {
                                      showDialog(
                                        context: context,
                                        barrierColor: Colors.black87,
                                        builder: (imageContext) {
                                          return Dialog(
                                            backgroundColor: Colors.transparent,
                                            insetPadding: const EdgeInsets.all(12),
                                            child: Stack(
                                              alignment: Alignment.center,
                                              children: [
                                                InteractiveViewer(
                                                  minScale: 0.8,
                                                  maxScale: 4.0,
                                                  child: Image.network(
                                                    activityPhoto,
                                                    fit: BoxFit.contain,
                                                    errorBuilder:
                                                        (context, error, stackTrace) {
                                                      return const Icon(
                                                        Icons.broken_image_outlined,
                                                        color: Colors.white70,
                                                        size: 52,
                                                      );
                                                    },
                                                  ),
                                                ),
                                                Positioned(
                                                  top: 0,
                                                  right: 0,
                                                  child: Material(
                                                    color: Colors.black54,
                                                    shape: const CircleBorder(),
                                                    child: IconButton(
                                                      onPressed: () =>
                                                          Navigator.pop(imageContext),
                                                      icon: const Icon(
                                                        Icons.close_rounded,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.network(
                                        activityPhoto,
                                        width: 120,
                                        height: 90,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return const SizedBox.shrink();
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      Text(
                        user["bio"] ?? "",
                        style: const TextStyle(
                          color: const Color(0xFF64748B),
                        ),
                      ),

                      Text(
                        "${distance.toStringAsFixed(1)} km away",
                        style: const TextStyle(
                          color: const Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  trailing: FutureBuilder<List<QuerySnapshot>>(
                    future: Future.wait([
                      FirebaseFirestore.instance
                          .collection("friends")
                          .where(
                            "userId",
                            isEqualTo: currentUser!.uid,
                          )
                          .where(
                            "friendId",
                            isEqualTo: user["uid"],
                          )
                          .limit(1)
                          .get(),

                      FirebaseFirestore.instance
                          .collection("friend_requests")
                          .where(
                            "senderId",
                            isEqualTo: currentUser!.uid,
                          )
                          .where(
                            "receiverId",
                            isEqualTo: user["uid"],
                          )
                          .where(
                            "status",
                            isEqualTo: "pending",
                          )
                          .limit(1)
                          .get(),
                    ]),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox(
                          width: 70,
                          height: 36,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      final bool isFriend = snapshot.data![0].docs.isNotEmpty;
                      final bool isRequested = snapshot.data![1].docs.isNotEmpty;
                      return ElevatedButton(
                        style: isFriend
                            ? ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.withOpacity(0.25),
                                foregroundColor: const Color(0xFF166534),
                                disabledBackgroundColor: Colors.green.withOpacity(0.25),
                                disabledForegroundColor: const Color(0xFF166534),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              )
                            : null,
                        onPressed: (isFriend || isRequested)
                            ? null
                            : () async {
                                await FriendService.sendRequest(
                                  senderId: currentUser!.uid,
                                  receiverId: user["uid"],
                                );

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Friend Request Sent"),
                                  ),
                                );
                              },
                        child: Text(
                          isFriend
                              ? "Friends"
                              : isRequested
                                  ? "Requested"
                                  : "Add",
                        ),
                      );
                    },
                  ),
                  ),
                ),
              );
            },
          );
        },
      ),
    ),
      ],
    ),
    );
  }
}
class _HomeChatButton extends StatefulWidget {
  final List<QueryDocumentSnapshot> friends;

  const _HomeChatButton({
    required this.friends,
  });

  @override
  State<_HomeChatButton> createState() => _HomeChatButtonState();
}

class _HomeChatButtonState extends State<_HomeChatButton> {
  int unreadCount = 0;

StreamSubscription? _unreadSubscription;
  @override
  void initState() {
    super.initState();
  
    _updateUnreadCount();
  
    _unreadSubscription = FirebaseFirestore.instance
        .collectionGroup("messages")
        .where(
          "receiverId",
          isEqualTo: FirebaseAuth.instance.currentUser!.uid,
        )
        .where(
          "read",
          isEqualTo: false,
        )
        .snapshots()
        .listen((snapshot) {
          //testing
          print("🔥 UNREAD LISTENER FIRED: ${snapshot.docs.length}");
          //
          if (!mounted) return;
  
          setState(() {
            unreadCount = snapshot.docs.length;
          });
        });
  }

  @override
  void didUpdateWidget(covariant _HomeChatButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.friends.length != widget.friends.length) {
      _updateUnreadCount();
    }
  }

  Future<void> _updateUnreadCount() async {
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) return;

    int total = 0;

    for (final friend in widget.friends) {
      final friendId = friend["friendId"].toString();

      final chatId = currentUser.uid.compareTo(friendId) < 0
          ? "${currentUser.uid}_$friendId"
          : "${friendId}_${currentUser.uid}";

      final snapshot = await FirebaseFirestore.instance
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
          .get();

      total += snapshot.docs.length;
    }

    if (mounted) {
      setState(() {
        unreadCount = total;
      });
    }
  }
  @override
  void dispose() {
    _unreadSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(
            Icons.chat_bubble_outline,
            color: AppTheme.textDark,
          ),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ChatListPage(),
              ),
            );
          },
        ),

        if (unreadCount > 0)
          Positioned(
            right: 3,
            top: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 5,
                vertical: 2,
              ),
              constraints: const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                unreadCount > 99
                    ? "99+"
                    : unreadCount.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
