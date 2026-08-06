import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'otp_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController phoneController =
      TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1B4D),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(25),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 100),

                const Icon(
                  Icons.phone_android,
                  size: 80,
                  color: Colors.white,
                ),

                const SizedBox(height: 20),

                const Text(
                  "Login with Phone",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 30),

                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Enter mobile number",
                    hintStyle: const TextStyle(
                      color: Colors.white54,
                    ),
                    filled: true,
                    fillColor: Colors.white12,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(12),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: () async {
                    await FirebaseAuth.instance
                        .verifyPhoneNumber(
                      phoneNumber:
                          '+91${phoneController.text}',
                      verificationCompleted:
                          (PhoneAuthCredential credential) {
                      },
                      verificationFailed:
                          (FirebaseAuthException e) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(
                          SnackBar(
                            content: Text(
                              e.message ??
                                  "Verification failed",
                            ),
                          ),
                        );
                      },
                      codeSent:
                          (String verificationId,
                              int? resendToken) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                OtpPage(
                              verificationId:
                                  verificationId,
                            ),
                          ),
                        );
                      },
                      codeAutoRetrievalTimeout:
                          (String verificationId) {},
                    );
                  },
                  child: const Text("Send OTP"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}