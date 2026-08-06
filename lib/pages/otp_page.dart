import 'package:firebase_auth/firebase_auth.dart';
import 'profile_setup.dart';
import 'home_page.dart';
import 'package:flutter/material.dart';

class OtpPage extends StatefulWidget {
  final String verificationId;

  const OtpPage({
    super.key,
    required this.verificationId,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final otpController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1B4D),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 80, color: Colors.white),
            const SizedBox(height: 20),

            const Text(
              "Enter OTP",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Enter OTP",
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 30),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
               padding: EdgeInsets.symmetric(
                 horizontal: 45,
                 vertical: 14,
                 ),
              ),
              onPressed: () async {
                try {
                  PhoneAuthCredential credential =
                      PhoneAuthProvider.credential(
                    verificationId: widget.verificationId,
                    smsCode: otpController.text,
                  );

                  await FirebaseAuth.instance
                      .signInWithCredential(credential);

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          const ProfileSetupPage(),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Invalid OTP"),
                    ),
                  );
                }
              },
              child: const Text("Verify"),
            )
          ],
        ),
      ),
    );
  }
}