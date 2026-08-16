import 'package:flutter/material.dart';
import 'live_room_screen.dart';

class GoLiveScreen extends StatefulWidget {
  const GoLiveScreen({super.key});

  @override
  State<GoLiveScreen> createState() => _GoLiveScreenState();
}

class _GoLiveScreenState extends State<GoLiveScreen> {

  final TextEditingController titleController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff050509),

      body: SafeArea(
        child: Column(
          children: [

            // Header
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [

                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(
                      Icons.arrow_back_ios_new,
                      color: Colors.white,
                    ),
                  ),

                  const SizedBox(width: 8),

                  const Text(
                    "Go Live",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                ],
              ),
            ),


            // Camera Preview
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),

                  gradient: LinearGradient(
                    colors: [
                      const Color(0xff8A3DFF)
                          .withValues(alpha: .35),

                      const Color(0xff00D4FF)
                          .withValues(alpha: .20),
                    ],
                  ),

                  border: Border.all(
                    color: const Color(0xff8A3DFF),
                    width: 1.5,
                  ),
                ),

                child: Center(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,

                    children: [

                      Container(
                        padding:
                            const EdgeInsets.all(25),

                        decoration: BoxDecoration(
                          shape: BoxShape.circle,

                          color: Colors.black
                              .withValues(alpha: .35),
                        ),

                        child: const Icon(
                          Icons.videocam_rounded,
                          size: 55,
                          color: Color(0xff00D4FF),
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        "Camera Preview",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                        ),
                      ),

                    ],
                  ),
                ),
              ),
            ),


            const SizedBox(height: 20),


            // Live title
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20),

              child: TextField(
                controller: titleController,

                style: const TextStyle(
                  color: Colors.white,
                ),

                decoration: InputDecoration(

                  hintText:
                      "What's your live about?",

                  hintStyle: TextStyle(
                    color: Colors.white
                        .withValues(alpha: .5),
                  ),

                  filled: true,

                  fillColor:
                      const Color(0xff11111A),

                  border:
                      OutlineInputBorder(

                    borderRadius:
                        BorderRadius.circular(18),

                    borderSide:
                        BorderSide.none,
                  ),
                ),
              ),
            ),


            const SizedBox(height: 20),


            // Controls
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,

              children: [

                _controlButton(
                  Icons.flip_camera_ios,
                ),

                const SizedBox(width: 20),

                _controlButton(
                  Icons.settings,
                ),

              ],
            ),


            const SizedBox(height: 25),


            // Start button
            Container(
              width: double.infinity,

              height: 58,

              margin:
                  const EdgeInsets.symmetric(horizontal: 25),

              child: ElevatedButton(

                onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => const LiveRoomScreen(),
    ),
  );
},

                style: ElevatedButton.styleFrom(

                  backgroundColor:
                      const Color(0xff8A3DFF),

                  shape:
                      RoundedRectangleBorder(

                    borderRadius:
                        BorderRadius.circular(20),

                  ),
                ),

                child: const Text(

                  "START LIVE",

                  style: TextStyle(

                    color: Colors.white,

                    fontSize: 17,

                    fontWeight:
                        FontWeight.bold,

                  ),
                ),
              ),
            ),


            const SizedBox(height: 25),

          ],
        ),
      ),
    );
  }


  Widget _controlButton(IconData icon) {

    return Container(

      height: 52,

      width: 52,

      decoration: BoxDecoration(

        shape: BoxShape.circle,

        color:
            const Color(0xff11111A),

        border: Border.all(

          color:
              const Color(0xff8A3DFF),

        ),

      ),

      child: Icon(

        icon,

        color: Colors.white,

      ),
    );
  }
}