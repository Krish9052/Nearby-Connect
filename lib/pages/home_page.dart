import 'friends_page.dart';
import '../services/friend_service.dart';
import 'package:flutter/material.dart';
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
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RequestsPage(),
                  ),
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
      body: StreamBuilder<QuerySnapshot>(
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
                  trailing: ElevatedButton(
                    onPressed: () async {
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
                    child: const Text("Add"),
                  ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}