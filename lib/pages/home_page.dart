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

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
 State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with WidgetsBindingObserver {
  final currentUser = FirebaseAuth.instance.currentUser;

  double? myLatitude;
  double? myLongitude;

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
      backgroundColor: const Color(0xFF0A1B4D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1B4D),
        title: const Text(
          "Nearby People",
           
           style: TextStyle(color: Colors.white),
          ),
          actions: [

            // My Profile
            IconButton(
              icon: const Icon(
                Icons.account_circle,
                color: Colors.white,
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
                        color: Colors.white,
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

            // Logout
            IconButton(
              icon: const Icon(
                Icons.logout,
                color: Colors.white,
              ),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();

                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LoginPage(),
                  ),
                  (route) => false,
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
                    showModalBottomSheet(
                      context: context,
                      backgroundColor: const Color(0xFF0A1B4D),
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(25),
                        ),
                      ),
                      builder: (context) {
                        bool momentSaved = false;
                        bool momentDeleted = false;
                        bool momentExists = isVisible;

                        return StatefulBuilder(
                          builder: (context, sheetSetState) {
                          return SafeArea(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "What are you up to?",
                                style: TextStyle(
                                  color: Color(0xFF7DD3FC),
                                  fontSize: 21,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 20),

                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  "☕ Coffee",
                                  "🍽️ Dinner",
                                  "🍕 Having Food",
                                  "🎬 Movie",
                                  "🎵 Music",
                                  "🎮 Gaming",
                                  "🚶 Walk",
                                  "🏋️ Workout",
                                  "📚 Studying",
                                  "💻 Working",
                                  "😴 Sleeping",
                                  "💬 Free to Chat",
                                  "🏖️ Chilling",
                                ].map((activity) {
                                  return ActionChip(
                                    label: Text(
                                      activity,
                                      style: TextStyle(
                                        color: selectedMomentActivity == activity
                                            ? const Color(0xFF0A1B4D)
                                            : Colors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    backgroundColor: selectedMomentActivity == activity
                                        ? const Color(0xFF7DD3FC)
                                        : const Color(0xFF243B73),
                                    side: const BorderSide(
                                      color: Colors.white24,
                                    ),
                                    onPressed: () {
                                      sheetSetState(() {
                                        selectedMomentActivity = activity;
                                      });
                                    },
                                  );
                                }).toList(),
                              ),

                              const SizedBox(height: 20),

                              const SizedBox(height: 10),
                            
                            if (!momentExists)
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor: const Color(0xFF0A1B4D),
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(25),
                                        ),
                                      ),
                                      builder: (context) {
                                        return SafeArea(
                                          child: Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text(
                                                  "Add Your Moment Photo",
                                                  style: TextStyle(
                                                    color: Color(0xFF7DD3FC),
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                              
                                                const SizedBox(height: 20),
                              
                                                ListTile(
                                                  leading: const Icon(
                                                    Icons.camera_alt,
                                                    color: Colors.white,
                                                  ),
                                                  title: const Text(
                                                    "Take a Photo",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  onTap: () async {
                                                    final ImagePicker picker = ImagePicker();

                                                    final XFile? image = await picker.pickImage(
                                                      source: ImageSource.camera,
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
                                                    
                                                    setState(() {
                                                      selectedMomentPhoto = File(croppedImage.path);
                                                    });
                                                  
                                                    if (!context.mounted) return;
                                                  
                                                    Navigator.pop(context);
                                                  },
                                                ),
                              
                                                ListTile(
                                                  leading: const Icon(
                                                    Icons.photo_library,
                                                    color: Colors.white,
                                                  ),
                                                  title: const Text(
                                                    "Choose from Gallery",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  onTap: () async {
                                                    final ImagePicker picker = ImagePicker();
                                                  
                                                    final XFile? image = await picker.pickImage(
                                                      source: ImageSource.gallery,
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
                                                    
                                                    setState(() {
                                                      selectedMomentPhoto = File(croppedImage.path);
                                                    });
                                                  
                                                    if (!context.mounted) return;
                                                  
                                                    Navigator.pop(context);
                                                  },
                                                ),
                              
                                                const SizedBox(height: 10),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    "Add a Photo",
                                    style: TextStyle(
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                              if (momentSaved)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    "Your Moment saved successfully! ✨",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              
                              if (momentDeleted)
                                const Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    "Your Moment deleted successfully! 🗑️",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.greenAccent,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              // 💾 Save Moment
                              SizedBox(
                                width: double.infinity,
                                height: 50,
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
                                          color: Colors.redAccent,
                                        ),
                                        label: const Text(
                                          "Delete Moment",
                                          style: TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : ElevatedButton.icon(
                                        onPressed: selectedMomentActivity.isEmpty
                                            ? null
                                            : () async {
                                                try {
                                                  String? activityPhoto;
                              
                                                  // 📸 Upload photo only if selected
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
                                                      throw Exception(
                                                        "Photo URL not received",
                                                      );
                                                    }
                                                  }
                              
                                                  final Map<String, dynamic> momentData = {
                                                    "activity": selectedMomentActivity,
                                                    "activityVisible": true,
                                                    "activityUpdatedAt":
                                                        FieldValue.serverTimestamp(),
                                                  };
                              
                                                  if (activityPhoto != null) {
                                                    momentData["activityPhoto"] =
                                                        activityPhoto;
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

                                                  ScaffoldMessenger.of(homeContext)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content: Text("Failed: $e"),
                                                      duration:
                                                          const Duration(seconds: 6),
                                                    ),
                                                  );
                                                }
                                              },
                                        icon: const Icon(Icons.check),
                                        label: const Text(
                                          "Save Moment",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
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
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
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
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                "Share what you're up to",
                                style: TextStyle(
                                  color: Colors.white60,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.add_circle_outline,
                          color: Colors.white,
                          size: 28,
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
                style: TextStyle(color: Colors.white),
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
                color: Colors.white12,
                margin: const EdgeInsets.only(bottom: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage:
                            (user["image"] != null && user["image"] != "")
                                ? NetworkImage(user["image"])
                                : null,
                        child: (user["image"] == null || user["image"] == "")
                            ? const Icon(Icons.person)
                            : null,
                      ),
                    ],
                  ),
                  title: Text(
                    user["name"] ?? "",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
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
                                    color: Color(0xFF7DD3FC),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          
                              if (activityPhoto.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
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
                            ],
                          );
                        },
                      ),
                      Text(
                        user["bio"] ?? "",
                        style: const TextStyle(
                          color: Colors.white70,
                        ),
                      ),

                      Text(
                        "${distance.toStringAsFixed(1)} km away",
                        style: const TextStyle(
                          color: Colors.white54,
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
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.green.withOpacity(0.25),
                                disabledForegroundColor: Colors.white,
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