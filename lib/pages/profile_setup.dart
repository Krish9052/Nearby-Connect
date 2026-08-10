import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'home_page.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  File? profileImage;

  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final genderController = TextEditingController();
  final bioController = TextEditingController();
  final instagramController = TextEditingController();
  String selectedActivity = "";

  final ImagePicker picker = ImagePicker();

  Future<void> pickImage() async {
    final XFile? image =
        await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        profileImage = File(image.path);
      });
    }
  }

  Future<void> saveProfile() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) return;

  String imageUrl = "";

  // Upload image to Cloudinary
  if (profileImage != null) {
    var request = http.MultipartRequest(
      "POST",
      Uri.parse("https://api.cloudinary.com/v1_1/pdkqvivw/image/upload"),
    );

    request.fields["upload_preset"] = "nearby_profile";

    request.files.add(
      await http.MultipartFile.fromPath(
        "file",
        profileImage!.path,
      ),
    );

    var response = await request.send();

    if (response.statusCode == 200) {
      var responseData = await response.stream.bytesToString();
      var jsonData = jsonDecode(responseData);

      imageUrl = jsonData["secure_url"];
    } else {
      throw Exception("Image upload failed");
    }
  }
  LocationPermission permission = await Geolocator.checkPermission();

  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.deniedForever) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Location permission permanently denied"),
      ),
    );
    return;
  }

  Position position = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );

  // Save profile to Firestore
  await FirebaseFirestore.instance
      .collection("users")
      .doc(user.uid)
      .set({
    "uid": user.uid,
    "name": nameController.text.trim(),
    "age": ageController.text.trim(),
    "gender": genderController.text.trim(),
    "bio": bioController.text.trim(),
    "instagram": instagramController.text.trim(),
    "phone": user.phoneNumber,
    "email": user.email,
    "image": imageUrl,
    "fcmToken": await FirebaseMessaging.instance.getToken(),

    "latitude": position.latitude,
    "longitude": position.longitude,

    "createdAt": FieldValue.serverTimestamp(),
  });
}

  @override
  void dispose() {
    nameController.dispose();
    ageController.dispose();
    genderController.dispose();
    bioController.dispose();
    instagramController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1B4D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1B4D),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Setup Profile",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const SizedBox(height: 20),

            GestureDetector(
              onTap: pickImage,
              child: CircleAvatar(
                radius: 55,
                backgroundColor: Colors.white24,
                backgroundImage:
                    profileImage != null ? FileImage(profileImage!) : null,
                child: profileImage == null
                    ? const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 35,
                      )
                    : null,
              ),
            ),

            const SizedBox(height: 30),

            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Enter your name",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: ageController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Enter your age",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: genderController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Gender (Male/Female)",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: bioController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Write bio about you",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            TextField(
              controller: instagramController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: "Instagram",
                hintText: "Instagram username",
                prefixIcon: Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                ),
                labelStyle: TextStyle(color: Colors.white),
                hintStyle: TextStyle(color: Colors.white54),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameController.text.trim().isEmpty ||
                      ageController.text.trim().isEmpty ||
                      genderController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please fill all required fields"),
                      ),
                    );
                    return;
                  }

                  try {
                    await saveProfile();

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Profile Saved Successfully"),
                      ),
                    );

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const HomePage(),
                      ),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("Error: $e"),
                      ),
                    );
                  }
                },
                child: const Text(
                  "Continue",
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}