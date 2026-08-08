import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}
class _EditProfilePageState extends State<EditProfilePage> {

  final currentUser = FirebaseAuth.instance.currentUser!;

  final nameController = TextEditingController();
  final ageController = TextEditingController();
  final genderController = TextEditingController();
  final bioController = TextEditingController();

  File? profileImage;
  final ImagePicker picker = ImagePicker();
  @override
  void initState() {
    super.initState();
    loadProfile();
  }
  Future<void> loadProfile() async {
    final doc = await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUser.uid)
        .get();

    if (!doc.exists) return;

    final data = doc.data()!;

    nameController.text = data["name"] ?? "";
    ageController.text = data["age"] ?? "";
    genderController.text = data["gender"] ?? "";
    bioController.text = data["bio"] ?? "";
  }
  Future<void> pickImage() async {
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (image == null) return;

    setState(() {
      profileImage = File(image.path);
    });
  }
  Future<void> saveProfile() async {
    String imageUrl = "";

    if (profileImage != null) {
      var request = http.MultipartRequest(
        "POST",
        Uri.parse(
          "https://api.cloudinary.com/v1_1/pdkqvivw/image/upload",
        ),
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
        var responseData =
            await response.stream.bytesToString();

        var jsonData = jsonDecode(responseData);

        imageUrl = jsonData["secure_url"];
      }
    }
    await FirebaseFirestore.instance
        .collection("users")
        .doc(currentUser.uid)
        .update({
      "name": nameController.text.trim(),
      "age": ageController.text.trim(),
      "gender": genderController.text.trim(),
      "bio": bioController.text.trim(),
      if (imageUrl.isNotEmpty) "image": imageUrl,
    });

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Profile Updated Successfully"),
      ),
    );

    Navigator.pop(context);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1B4D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1B4D),
        title: const Text(
          "Edit Profile",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [

            const SizedBox(height: 20),

            GestureDetector(
              onTap: pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundImage: profileImage != null
                    ? FileImage(profileImage!)
                    : null,
                child: profileImage == null
                    ? const Icon(
                        Icons.camera_alt,
                        size: 40,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: nameController,
              style: const TextStyle(
                color: Colors.white,
              ),
              decoration: const InputDecoration(
                labelText: "Name",
                labelStyle: TextStyle(color: Colors.white70),

                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white54),
                ),

                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.purpleAccent),
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: ageController,
              style: const TextStyle(
                color: Colors.white,
              ),
              decoration: const InputDecoration(
                labelText: "Age",
                labelStyle: TextStyle(color: Colors.white70),

                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white54),
                ),

                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.purpleAccent),
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: genderController,
              style: const TextStyle(
                color: Colors.white,
            ),
              decoration: const InputDecoration(
                labelText: "Gender",
                labelStyle: TextStyle(color: Colors.white70),

                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white54),
                ),

                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.purpleAccent),
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: bioController,
              style: const TextStyle(
                color: Colors.white,
              ),
              decoration: const InputDecoration(
                labelText: "Bio",
                labelStyle: TextStyle(color: Colors.white70),

                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white54),
                ),

                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.purpleAccent),
                ),
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: saveProfile,
              child: const Text("Save Changes"),
            ),

          ],
        ),
      ),
    );
  }
}