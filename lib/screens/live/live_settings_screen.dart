import 'package:flutter/material.dart';

class LiveSettingsScreen extends StatefulWidget {
  const LiveSettingsScreen({super.key});

  @override
  State<LiveSettingsScreen> createState() =>
      _LiveSettingsScreenState();
}

class _LiveSettingsScreenState extends State<LiveSettingsScreen> {

  bool allowComments = true;
  bool saveReplay = true;
  bool notifyFollowers = true;
  bool allowGuests = false;

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

                    "Live Settings",

                    style: TextStyle(

                      color: Colors.white,

                      fontSize: 24,

                      fontWeight: FontWeight.bold,

                    ),

                  ),

                ],

              ),

            ),


            const SizedBox(height: 10),


            // Settings cards
            _settingTile(
              icon: Icons.comment,
              title: "Allow Comments",
              subtitle: "Viewers can comment during your live",
              value: allowComments,
              onChanged: (value) {
                setState(() {
                  allowComments = value;
                });
              },
            ),


            _settingTile(
              icon: Icons.people,
              title: "Allow Guests",
              subtitle: "Invite people to join your live",
              value: allowGuests,
              onChanged: (value) {
                setState(() {
                  allowGuests = value;
                });
              },
            ),


            _settingTile(
              icon: Icons.video_library,
              title: "Save Replay",
              subtitle: "Save your live after ending",
              value: saveReplay,
              onChanged: (value) {
                setState(() {
                  saveReplay = value;
                });
              },
            ),


            _settingTile(
              icon: Icons.notifications,
              title: "Notify Followers",
              subtitle: "Tell followers when you go live",
              value: notifyFollowers,
              onChanged: (value) {
                setState(() {
                  notifyFollowers = value;
                });
              },
            ),


            const Spacer(),


            Container(

              margin:
                  const EdgeInsets.all(25),

              width:
                  double.infinity,

              height:
                  55,

              child: ElevatedButton(

                onPressed: () {
                  Navigator.pop(context);
                },

                style: ElevatedButton.styleFrom(

                  backgroundColor:
                      const Color(0xff8A3DFF),

                  shape:
                      RoundedRectangleBorder(

                    borderRadius:
                        BorderRadius.circular(18),

                  ),

                ),

                child: const Text(

                  "SAVE SETTINGS",

                  style: TextStyle(

                    color: Colors.white,

                    fontWeight: FontWeight.bold,

                  ),

                ),

              ),

            ),

          ],

        ),

      ),

    );

  }


  Widget _settingTile({

    required IconData icon,

    required String title,

    required String subtitle,

    required bool value,

    required Function(bool) onChanged,

  }) {

    return Container(

      margin:
          const EdgeInsets.symmetric(

        horizontal: 18,

        vertical: 8,

      ),

      padding:
          const EdgeInsets.all(16),

      decoration: BoxDecoration(

        color:
            const Color(0xff11111A),

        borderRadius:
            BorderRadius.circular(18),

        border: Border.all(

          color:
              const Color(0xff8A3DFF)
                  .withValues(alpha: .5),

        ),

      ),

      child: Row(

        children: [

          Container(

            padding:
                const EdgeInsets.all(10),

            decoration: BoxDecoration(

              shape:
                  BoxShape.circle,

              color:
                  const Color(0xff8A3DFF)
                      .withValues(alpha: .2),

            ),

            child: Icon(

              icon,

              color:
                  const Color(0xff00D4FF),

            ),

          ),


          const SizedBox(width: 15),


          Expanded(

            child: Column(

              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Text(

                  title,

                  style: const TextStyle(

                    color: Colors.white,

                    fontSize: 16,

                    fontWeight: FontWeight.bold,

                  ),

                ),


                Text(

                  subtitle,

                  style: TextStyle(

                    color: Colors.white
                        .withValues(alpha: .5),

                    fontSize: 13,

                  ),

                ),

              ],

            ),

          ),


          Switch(

            value: value,

            onChanged: onChanged,

            activeThumbColor:
                const Color(0xff8A3DFF),

          ),

        ],

      ),

    );

  }
}