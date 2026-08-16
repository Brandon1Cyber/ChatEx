import 'package:flutter/material.dart';
import 'live_room_screen.dart';

class LiveNowScreen extends StatelessWidget {
  const LiveNowScreen({super.key});

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

                  const Text(

                    "Live Now",

                    style: TextStyle(

                      color: Colors.white,

                      fontSize: 26,

                      fontWeight: FontWeight.bold,

                    ),

                  ),


                  const Spacer(),


                  Container(

                    padding:
                        const EdgeInsets.all(10),

                    decoration: BoxDecoration(

                      shape: BoxShape.circle,

                      color:
                          const Color(0xff11111A),

                      border: Border.all(

                        color:
                            const Color(0xff8A3DFF),

                      ),

                    ),

                    child: const Icon(

                      Icons.search,

                      color: Colors.white,

                    ),

                  ),

                ],

              ),

            ),


            // Live list
            Expanded(

              child: ListView.builder(

                padding:
                    const EdgeInsets.symmetric(

                  horizontal: 18,

                ),

                itemCount: 5,

                itemBuilder: (context, index) {


                  return GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const LiveRoomScreen(),
      ),
    );
  },

  child: Container(

                    margin:
                        const EdgeInsets.only(

                      bottom: 18,

                    ),

                    height: 220,


                    decoration: BoxDecoration(

                      borderRadius:
                          BorderRadius.circular(25),

                      gradient: LinearGradient(

                        colors: [

                          const Color(0xff8A3DFF)
                              .withValues(alpha: .35),

                          const Color(0xff00D4FF)
                              .withValues(alpha: .20),

                        ],

                      ),


                      border: Border.all(

                        color:
                            const Color(0xff8A3DFF),

                      ),

                    ),


                    child: Stack(

                      children: [


                        const Center(

                          child: Icon(

                            Icons.videocam,

                            size: 60,

                            color:
                                Color(0xff00D4FF),

                          ),

                        ),


                        Positioned(

                          top: 15,

                          left: 15,

                          child: Row(

                            children: [

                              CircleAvatar(

                                radius: 20,

                                backgroundColor:
                                    const Color(0xff8A3DFF),

                                child: const Icon(

                                  Icons.person,

                                  color:
                                      Colors.white,

                                ),

                              ),


                              const SizedBox(width: 10),


                              const Text(

                                "ChattªX User",

                                style: TextStyle(

                                  color:
                                      Colors.white,

                                  fontWeight:
                                      FontWeight.bold,

                                ),

                              ),

                            ],

                          ),

                        ),


                        Positioned(

                          bottom: 15,

                          left: 15,

                          child: Container(

                            padding:
                                const EdgeInsets.symmetric(

                              horizontal: 12,

                              vertical: 6,

                            ),

                            decoration: BoxDecoration(

                              color: Colors.red,

                              borderRadius:
                                  BorderRadius.circular(20),

                            ),

                            child: const Text(

                              "🔴 LIVE",

                              style: TextStyle(

                                color:
                                    Colors.white,

                                fontWeight:
                                    FontWeight.bold,

                              ),

                            ),

                          ),

                        ),


                        Positioned(

                          bottom: 15,

                          right: 15,

                          child: Container(

                            padding:
                                const EdgeInsets.all(10),

                            decoration: BoxDecoration(

                              color:
                                  Colors.black.withValues(alpha: .45),

                              borderRadius:
                                  BorderRadius.circular(20),

                            ),

                            child: const Row(

                              children: [

                                Icon(

                                  Icons.remove_red_eye,

                                  color:
                                      Colors.white,

                                  size: 18,

                                ),

                                SizedBox(width: 5),

                                Text(

                                  "0",

                                  style: TextStyle(

                                    color:
                                        Colors.white,

                                  ),

                                ),

                              ],

                            ),

                          ),

                        ),

                      ],

                    ),
  ),

                  );

                },

              ),

            ),

          ],

        ),

      ),

    );

  }
}