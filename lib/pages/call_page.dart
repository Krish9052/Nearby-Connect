import 'package:flutter/material.dart';

class CallPage extends StatefulWidget {
  final String receiverName;

  const CallPage({
    super.key,
    required this.receiverName,
  });

  @override
  State<CallPage> createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {

  bool isMuted = false;
  bool speakerOn = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1B4D),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              const CircleAvatar(
                radius: 60,
                child: Icon(
                  Icons.person,
                  size: 60,
                ),
              ),

              const SizedBox(height: 20),

              Text(
                widget.receiverName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              const Text(
                "Calling...",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 60),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [

                  FloatingActionButton(
                    heroTag: "mute",
                    backgroundColor:
                        isMuted ? Colors.orange : Colors.white24,
                    onPressed: () {
                      setState(() {
                        isMuted = !isMuted;
                      });
                    },
                    child: Icon(
                      isMuted ? Icons.mic_off : Icons.mic,
                    ),
                  ),

                  FloatingActionButton(
                    heroTag: "end",
                    backgroundColor: Colors.red,
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Icon(Icons.call_end),
                  ),

                  FloatingActionButton(
                    heroTag: "speaker",
                    backgroundColor:
                        speakerOn ? Colors.green : Colors.white24,
                    onPressed: () {
                      setState(() {
                        speakerOn = !speakerOn;
                      });
                    },
                    child: Icon(
                      speakerOn
                          ? Icons.volume_up
                          : Icons.hearing,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}