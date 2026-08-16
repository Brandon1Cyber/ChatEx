import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart';
import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class SettingsScreen extends StatefulWidget {

  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() =>
      _SettingsScreenState();

}



class _SettingsScreenState
    extends State<SettingsScreen> {


  final Color bg =
      const Color(0xFF050816);

  final Color cyan =
      const Color(0xFF00D9FF);

  final Color purple =
      const Color(0xFF7B2FF7);



  bool aiMemory = true;
  bool aiAssistant = true;
  bool smartReplies = true;

  bool ghostMode = false;
  bool secretChats = false;

  bool biometric = false;
  bool smartNotifications = true;

  bool chatCoins = true;

  final ImagePicker _picker = ImagePicker();

String? profileImageUrl;

  Future<void> _logout() async {
  await FirebaseAuth.instance.signOut();

  if (!mounted) return;

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (_) => const LoginScreen(),
    ),
    (route) => false,
  );
}

Future<void> _pickProfilePhoto() async {
  final XFile? image = await _picker.pickImage(
    source: ImageSource.gallery,
    imageQuality: 80,
  );

  if (image == null) return;

  final uid = FirebaseAuth.instance.currentUser!.uid;

  final ref = FirebaseStorage.instance
      .ref()
      .child("profile_photos")
      .child("$uid.jpg");

  await ref.putFile(File(image.path));

  final url = await ref.getDownloadURL();

  await FirebaseFirestore.instance
      .collection("users")
      .doc(uid)
      .update({
    "photoUrl": url,
  });

  setState(() {
    profileImageUrl = url;
  });
}

  @override
  Widget build(BuildContext context) {


    return Scaffold(

      backgroundColor: bg,


      body: SafeArea(

        child: ListView(

          padding:
          const EdgeInsets.all(16),


          children: [


            _header(),


            const SizedBox(height:20),


            _identityCard(),


            const SizedBox(height:20),


            _controlCenter(),



            _section(

              "👤 Profile Settings",

              [


                _tile(

                  "Edit ChattªX Profile",

                  "Manage your digital identity",

                  Icons.person,

                  cyan,

                ),



                _tile(

                  "QR Identity",

                  "Share your ChattªX profile",

                  Icons.qr_code,

                  purple,

                ),



                _tile(

                  "AI Avatar Creator",

                  "Create your digital avatar",

                  Icons.face,

                  cyan,

                ),


              ],

            ),



            _section(

              "🧠 Neural AI Core",

              [


                _switch(

                  "AI Memory",

                  "Learns your preferences",

                  Icons.psychology,

                  aiMemory,

                  (v){

                    setState((){

                      aiMemory=v;

                    });

                  },

                ),



                _switch(

                  "AI Assistant",

                  "Your personal ChattªX AI",

                  Icons.smart_toy,

                  aiAssistant,

                  (v){

                    setState((){

                      aiAssistant=v;

                    });

                  },

                ),



                _switch(

                  "Smart Replies",

                  "AI powered responses",

                  Icons.reply,

                  smartReplies,

                  (v){

                    setState((){

                      smartReplies=v;

                    });

                  },

                ),


              ],

            ),
            _section(

              "🛡 Privacy Fortress",

              [


                _switch(

                  "Ghost Mode",

                  "Read messages without showing seen",

                  Icons.visibility_off,

                  ghostMode,

                  (v){

                    setState((){

                      ghostMode = v;

                    });

                  },

                ),



                _switch(

                  "Secret Chats",

                  "Extra protected private conversations",

                  Icons.lock,

                  secretChats,

                  (v){

                    setState((){

                      secretChats = v;

                    });

                  },

                ),



                _tile(

                  "Privacy Scanner AI",

                  "AI checks your account privacy",

                  Icons.security,

                  cyan,

                ),



                _tile(

                  "Invisible Profile Mode",

                  "Control who can discover you",

                  Icons.person_off,

                  purple,

                ),


              ],

            ),





            _section(

              "🔐 Security Matrix",

              [


                _switch(

                  "Biometric Lock",

                  "Protect ChattªX with fingerprint",

                  Icons.fingerprint,

                  biometric,

                  (v){

                    setState((){

                      biometric = v;

                    });

                  },

                ),



                _tile(

                  "Encryption Monitor",

                  "Your chats are protected",

                  Icons.enhanced_encryption,

                  Colors.greenAccent,

                ),



                _tile(

                  "Connected Devices",

                  "Manage logged in devices",

                  Icons.devices,

                  cyan,

                ),



                _tile(

                  "Security Score",

                  "Account protection level: 98%",

                  Icons.shield,

                  purple,

                ),


              ],

            ),
            _section(

              "📡 Communication Engine",

              [


                _switch(

                  "Smart Notifications",

                  "AI prioritizes important messages",

                  Icons.notifications_active,

                  smartNotifications,

                  (v){

                    setState((){

                      smartNotifications = v;

                    });

                  },

                ),



                _tile(

                  "Conversation Intelligence",

                  "AI analyzes your conversations",

                  Icons.analytics,

                  cyan,

                ),



                _tile(

                  "Message Scheduler",

                  "Schedule messages for later",

                  Icons.schedule,

                  purple,

                ),



                _tile(

                  "Live Translation",

                  "Communicate in any language",

                  Icons.translate,

                  cyan,

                ),



              ],

            ),





            _section(

              "🌌 ChattªX Universe",

              [


                _switch(

                  "ChatCoins Wallet",

                  "Manage your ChattªX rewards",

                  Icons.account_balance_wallet,

                  chatCoins,

                  (v){

                    setState((){

                      chatCoins = v;

                    });

                  },

                ),



                _tile(

                  "Treasure Vault",

                  "Your rewards and achievements",

                  Icons.diamond,

                  cyan,

                ),



                _tile(

                  "Premium Center",

                  "Unlock advanced ChattªX features",

                  Icons.workspace_premium,

                  purple,

                ),



                _tile(

                  "Creator Studio",

                  "Create and grow your profile",

                  Icons.create,

                  cyan,

                ),



                _tile(

                  "Achievement Center",

                  "View your ChattªX milestones",

                  Icons.emoji_events,

                  Colors.orange,

                ),


              ],

            ),
            _section(

              "⚙️ Device & Data Center",

              [


                _tile(

                  "Cloud Sync",

                  "Securely sync your ChattªX data",

                  Icons.cloud_sync,

                  cyan,

                ),



                _tile(

                  "Backup Vault",

                  "Encrypted chat backup storage",

                  Icons.backup,

                  purple,

                ),



                _tile(

                  "Storage Optimizer",

                  "Clean unnecessary files",

                  Icons.cleaning_services,

                  cyan,

                ),



                _tile(

                  "Active Sessions",

                  "Manage connected devices",

                  Icons.devices_other,

                  purple,

                ),



                _tile(

                  "Data Export Center",

                  "Download your ChattªX data",

                  Icons.download,

                  cyan,

                ),


              ],

            ),






            _section(

              "🧪 ChattªX Advanced Lab",

              [


                _tile(

                  "Developer Mode",

                  "Experimental ChattªX features",

                  Icons.code,

                  purple,

                ),



                _tile(

                  "AI Experiments",

                  "Test future intelligence features",

                  Icons.science,

                  cyan,

                ),



                _tile(

                  "Performance Monitor",

                  "Check app speed and health",

                  Icons.speed,

                  Colors.greenAccent,

                ),



                _tile(

                  "Network Diagnostics",

                  "Analyze connection quality",

                  Icons.network_check,

                  cyan,

                ),


              ],

            ),

SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    onPressed: _logout,
    icon: const Icon(Icons.logout),
    label: const Text("Log Out"),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
      minimumSize: const Size(double.infinity, 55),
    ),
  ),
),

const SizedBox(height: 30),

            const SizedBox(height:40),



            Center(

              child: Text(

                "ChattªX • Messaging Beyond Tomorrow",

                style: TextStyle(

                  color: Colors.white38,

                  fontSize:12,

                ),

              ),

            ),


          ],

        ),

      ),

    );

  }

  Widget _header(){

    return Row(

      mainAxisAlignment:
      MainAxisAlignment.spaceBetween,

      children:[

        const Text(

          "Settings",

          style:TextStyle(

            color:Colors.white,

            fontSize:30,

            fontWeight:FontWeight.bold,

          ),

        ),


        Container(

          padding:
          const EdgeInsets.all(10),

          decoration:BoxDecoration(

            shape:BoxShape.circle,

            gradient:LinearGradient(

              colors:[

                cyan,

                purple,

              ],

            ),

          ),

          child:const Icon(

            Icons.settings,

            color:Colors.white,

          ),

        ),

      ],

    );

  }





  Widget _identityCard(){

    return Container(

      padding:
      const EdgeInsets.all(20),

      decoration:BoxDecoration(

        borderRadius:
        BorderRadius.circular(28),

        gradient:const LinearGradient(

          colors:[

            Color(0xFF101827),

            Color(0xFF151032),

          ],

        ),

        border:Border.all(

          color:
          Color(0xFF00D9FF),

          width:0.5,

        ),

      ),


      child:Row(

        children:[


          GestureDetector(
  onTap: _pickProfilePhoto,
  child: StreamBuilder<DocumentSnapshot>(
    stream: FirebaseFirestore.instance
        .collection("users")
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .snapshots(),
    builder: (context, snapshot) {
      String photo = "";

      if (snapshot.hasData && snapshot.data!.exists) {
        final data =
            snapshot.data!.data() as Map<String, dynamic>;
        photo = data["photoUrl"] ?? "";
      }

      return Container(
        height: 65,
        width: 65,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              cyan,
              purple,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: CircleAvatar(
            backgroundColor: bg,
            backgroundImage: photo.isNotEmpty
                ? NetworkImage(photo)
                : null,
            child: photo.isEmpty
                ? const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 34,
                  )
                : null,
          ),
        ),
      );
    },
  ),
),



          const SizedBox(width:15),



          const Expanded(

            child:Column(

              crossAxisAlignment:
              CrossAxisAlignment.start,

              children:[


                Text(

                  "ChattªX Identity",

                  style:TextStyle(

                    color:Colors.white,

                    fontSize:20,

                    fontWeight:
                    FontWeight.bold,

                  ),

                ),



                Text(

                  "Digital profile center",

                  style:TextStyle(

                    color:Colors.white54,

                  ),

                ),


              ],

            ),

          ),



          Icon(

            Icons.qr_code,

            color:cyan,

          ),

        ],

      ),

    );

  }





  Widget _controlCenter(){

    return Container(

      padding:
      const EdgeInsets.all(20),

      decoration:BoxDecoration(

        borderRadius:
        BorderRadius.circular(25),

        color:
        const Color(0xFF0D1528),

        border:Border.all(

          color:
          purple,

        ),

      ),


      child:Column(

        crossAxisAlignment:
        CrossAxisAlignment.start,

        children:[


          const Text(

            "ChattªX Command Center",

            style:TextStyle(

              color:Colors.white,

              fontSize:20,

              fontWeight:
              FontWeight.bold,

            ),

          ),


          const SizedBox(height:20),


          Row(

            mainAxisAlignment:
            MainAxisAlignment.spaceAround,

            children:[


              _stat(

                "98%",

                "Security",

              ),



              _stat(

                "AI 5",

                "Power",

              ),



              _stat(

                "1.2GB",

                "Cloud",

              ),


            ],

          ),


        ],

      ),

    );

  }





  Widget _stat(

      String value,

      String title,

      ){

    return Column(

      children:[


        Text(

          value,

          style:TextStyle(

            color:cyan,

            fontSize:18,

            fontWeight:
            FontWeight.bold,

          ),

        ),



        Text(

          title,

          style:const TextStyle(

            color:Colors.white54,

            fontSize:12,

          ),

        ),


      ],

    );

  }





  Widget _section(

      String title,

      List<Widget> children,

      ){

    return Column(

      crossAxisAlignment:
      CrossAxisAlignment.start,

      children:[


        Padding(

          padding:
          const EdgeInsets.only(

            top:25,

            bottom:10,

          ),

          child:Text(

            title,

            style:TextStyle(

              color:cyan,

              fontSize:17,

              fontWeight:
              FontWeight.bold,

            ),

          ),

        ),



        Container(

          decoration:BoxDecoration(

            color:
            const Color(0xFF0D1528),

            borderRadius:
            BorderRadius.circular(22),

          ),

          child:Column(

            children:children,

          ),

        ),

      ],

    );

  }





  Widget _tile(

      String title,

      String subtitle,

      IconData icon,

      Color color,

      ){

    return ListTile(

      leading:Icon(

        icon,

        color:color,

      ),


      title:Text(

        title,

        style:const TextStyle(

          color:Colors.white,

          fontWeight:
          FontWeight.w600,

        ),

      ),



      subtitle:Text(

        subtitle,

        style:const TextStyle(

          color:Colors.white54,

        ),

      ),



      trailing:const Icon(

        Icons.arrow_forward_ios,

        size:15,

        color:Colors.white38,

      ),

    );

  }





  Widget _switch(

      String title,

      String subtitle,

      IconData icon,

      bool value,

      Function(bool) onChanged,

      ){

    return SwitchListTile(

      value:value,

      onChanged:onChanged,

      activeThumbColor:cyan,


      secondary:Icon(

        icon,

        color:cyan,

      ),


      title:Text(

        title,

        style:const TextStyle(

          color:Colors.white,

        ),

      ),



      subtitle:Text(

        subtitle,

        style:const TextStyle(

          color:Colors.white54,

        ),

      ),

    );

  }


}