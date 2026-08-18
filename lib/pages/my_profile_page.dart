import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_page.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  final currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F8FF),
      appBar: AppBar(
        toolbarHeight: 56,
        backgroundColor: const Color(0xFFF0EDFF),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back,
              color: Color(0xFF0A1B4D), size: 34),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "My Profile",
          style: TextStyle(
            color: Color(0xFF0A1B4D),
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection("users")
            .doc(currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1976D2),
              ),
            );
          }

          final user =
              snapshot.data!.data() as Map<String, dynamic>;

          return Stack(
            children: [
              Positioned(
                top: 0,
                left: -70,
                right: -70,
                height: 365,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0EDFF),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(260),
                      bottomRight: Radius.circular(260),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: Column(
                    children: [
                      const SizedBox(height: 28),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x22000000),
                              blurRadius: 14,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 96,
                          backgroundColor: const Color(0xFFE2E8F0),
                          backgroundImage:
                              user["image"] != null &&
                                      user["image"] != ""
                                  ? NetworkImage(user["image"])
                                  : null,
                          child: (user["image"] == null ||
                                  user["image"] == "")
                              ? const Icon(
                                  Icons.person,
                                  size: 90,
                                  color: Color(0xFF1E293B),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        user["name"] ?? "",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF0A1B4D),
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user["bio"] ?? "",
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF68739A),
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 48),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.edit, size: 27),
                          label: const Text(
                            "Edit Profile",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const EditProfilePage(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shadowColor: const Color(0x33000000),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.logout, size: 28),
                          label: const Text(
                            "Logout",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onPressed: () async {
                            await FirebaseAuth.instance.signOut();
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF68739A),
                            side: const BorderSide(
                              color: Color(0xFFD5D1E8),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(32),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
