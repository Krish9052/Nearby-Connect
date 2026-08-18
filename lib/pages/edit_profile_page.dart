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
    const navy = Color(0xFF0A1B4D);
    const lavender = Color(0xFFF0EDFF);
    const pageBg = Color(0xFFF9F8FF);
    const muted = Color(0xFF68739A);
    const blue = Color(0xFF1976D2);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: lavender,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: navy,
            size: 32,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Edit Profile",
          style: TextStyle(
            color: navy,
            fontSize: 27,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: -70,
            right: -70,
            height: 330,
            child: Container(
              decoration: const BoxDecoration(
                color: lavender,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(240),
                  bottomRight: Radius.circular(240),
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
              child: Column(
                children: [
                  const SizedBox(height: 18),

                  // Profile photo with a neat white border.
                  GestureDetector(
                    onTap: pickImage,
                    child: Container(
                      padding: const EdgeInsets.all(5),
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
                        radius: 86,
                        backgroundColor: const Color(0xFFE2E8F0),
                        backgroundImage: profileImage != null
                            ? FileImage(profileImage!)
                            : null,
                        child: profileImage == null
                            ? const Icon(
                                Icons.camera_alt_rounded,
                                size: 52,
                                color: Color(0xFF36558F),
                              )
                            : null,
                      ),
                    ),
                  ),

                  const SizedBox(height: 34),

                  _editField(
                    controller: nameController,
                    label: "Name",
                    keyboardType: TextInputType.name,
                    navy: navy,
                    muted: muted,
                    blue: blue,
                  ),

                  const SizedBox(height: 20),

                  _editField(
                    controller: ageController,
                    label: "Age",
                    keyboardType: TextInputType.number,
                    navy: navy,
                    muted: muted,
                    blue: blue,
                  ),

                  const SizedBox(height: 20),

                  _editField(
                    controller: genderController,
                    label: "Gender",
                    keyboardType: TextInputType.text,
                    navy: navy,
                    muted: muted,
                    blue: blue,
                  ),

                  const SizedBox(height: 20),

                  _editField(
                    controller: bioController,
                    label: "Bio",
                    keyboardType: TextInputType.text,
                    maxLines: 2,
                    navy: navy,
                    muted: muted,
                    blue: blue,
                  ),

                  const SizedBox(height: 34),

                  SizedBox(
                    width: 190,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blue,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shadowColor: const Color(0x33000000),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                      child: const Text(
                        "Save Changes",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editField({
    required TextEditingController controller,
    required String label,
    required TextInputType keyboardType,
    required Color navy,
    required Color muted,
    required Color blue,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(
        color: Color(0xFF0A1B4D),
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          color: Color(0xFF68739A),
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: const TextStyle(
          color: Color(0xFF1976D2),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 2,
          vertical: 8,
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(
            color: Color(0xFFD0CCE2),
            width: 1.5,
          ),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(
            color: Color(0xFF1976D2),
            width: 2,
          ),
        ),
      ),
    );
  }
}