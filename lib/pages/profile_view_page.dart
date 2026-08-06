// profile_view_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileViewPage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ProfileViewPage({
    super.key,
    required this.userData,
  });

  @override
  State<ProfileViewPage> createState() => _ProfileViewPageState();
}

class _ProfileViewPageState extends State<ProfileViewPage> {
  final currentUser = FirebaseAuth.instance.currentUser!;

  @override
  Widget build(BuildContext context) {
    final user = widget.userData;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1B4D),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1B4D),
        title: const Text('Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 65,
              backgroundImage: user['image'] != null &&
                      user['image'].toString().isNotEmpty
                  ? NetworkImage(user['image'])
                  : null,
              child: user['image'] == null ||
                      user['image'].toString().isEmpty
                  ? const Icon(Icons.person, size: 60)
                  : null,
            ),
            const SizedBox(height: 20),
            Text(
              user['name'] ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Card(
              color: Colors.white12,
              child: ListTile(
                title: const Text('Age', style: TextStyle(color: Colors.white70)),
                subtitle: Text('${user['age'] ?? ''}',
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
            Card(
              color: Colors.white12,
              child: ListTile(
                title: const Text('Gender', style: TextStyle(color: Colors.white70)),
                subtitle: Text('${user['gender'] ?? ''}',
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
            Card(
              color: Colors.white12,
              child: ListTile(
                title: const Text('Bio', style: TextStyle(color: Colors.white70)),
                subtitle: Text('${user['bio'] ?? ''}',
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.person_add),
                label: const Text('Add Friend'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.message),
                label: const Text('Message'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
