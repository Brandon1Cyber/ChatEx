import 'package:flutter/material.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}


class _PrivacySettingsScreenState
    extends State<PrivacySettingsScreen> {


  bool hideOnline = false;
  bool hideTyping = false;
  bool readReceipts = true;
  bool screenshotProtection = true;
  bool aiProtection = true;
  bool invisibleMode = false;



  final Color background =
      const Color(0xFF050816);

  final Color card =
      const Color(0xFF0D1528);

  final Color cyan =
      const Color(0xFF00D9FF);



  @override
  Widget build(BuildContext context) {


    return Scaffold(

      backgroundColor: background,


      appBar: AppBar(

        backgroundColor: background,

        elevation:0,

        title: const Text(

          "Privacy Shield",

          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),

        ),

        iconTheme:
        IconThemeData(color: cyan),

      ),



      body: ListView(

        padding:
        const EdgeInsets.all(20),


        children: [


          _securityBanner(),



          const SizedBox(height:20),



          _settingTile(

            "Invisible Mode",

            "Appear offline while using ChatEx",

            Icons.visibility_off,

            invisibleMode,

                (value){

              setState(() {

                invisibleMode = value;

              });

            },

          ),



          _settingTile(

            "Hide Online Status",

            "Control who sees when you are online",

            Icons.circle_outlined,

            hideOnline,

                (value){

              setState(() {

                hideOnline = value;

              });

            },

          ),




          _settingTile(

            "Typing Indicator",

            "Show when you are typing",

            Icons.keyboard,

            hideTyping,

                (value){

              setState(() {

                hideTyping = value;

              });

            },

          ),




          _settingTile(

            "Read Receipts",

            "Allow others to see message reads",

            Icons.done_all,

            readReceipts,

                (value){

              setState(() {

                readReceipts = value;

              });

            },

          ),





          _settingTile(

            "Screenshot Protection",

            "Protect private conversations",

            Icons.screenshot_monitor,

            screenshotProtection,

                (value){

              setState(() {

                screenshotProtection = value;

              });

            },

          ),





          _settingTile(

            "AI Scam Protection",

            "Detect suspicious messages automatically",

            Icons.smart_toy,

            aiProtection,

                (value){

              setState(() {

                aiProtection = value;

              });

            },

          ),





          const SizedBox(height:25),




          _infoCard(

            "Advanced Privacy",

            "Your ChatEx identity is protected with "
                "next-generation privacy controls.",

            Icons.shield,

          ),



        ],

      ),

    );

  }






  Widget _securityBanner(){


    return Container(

      padding:
      const EdgeInsets.all(20),


      decoration:
      BoxDecoration(

        color:
        cyan.withValues(alpha:.12),

        borderRadius:
        BorderRadius.circular(25),

        border:

        Border.all(

          color:cyan,

        ),

      ),



      child: const Column(

        crossAxisAlignment:
        CrossAxisAlignment.start,


        children: [


          Text(

            "Privacy Shield Active",

            style: TextStyle(

              color: Colors.white,

              fontSize:20,

              fontWeight:
              FontWeight.bold,

            ),

          ),



          SizedBox(height:8),



          Text(

            "Manage your digital privacy "
                "and control your visibility.",

            style: TextStyle(

              color: Colors.white70,

            ),

          ),

        ],

      ),

    );

  }







  Widget _settingTile(

      String title,

      String subtitle,

      IconData icon,

      bool value,

      Function(bool) onChanged,

      ){


    return Container(

      margin:
      const EdgeInsets.only(
          bottom:12
      ),


      decoration:
      BoxDecoration(

        color:card,

        borderRadius:
        BorderRadius.circular(20),

      ),



      child:
      SwitchListTile(

        activeThumbColor:cyan,

        value:value,


        onChanged:onChanged,


        title:Text(

          title,

          style:
          const TextStyle(

            color:Colors.white,

            fontWeight:
            FontWeight.bold,

          ),

        ),



        subtitle:Text(

          subtitle,

          style:
          const TextStyle(

            color:Colors.white54,

          ),

        ),



        secondary:
        Icon(

          icon,

          color:cyan,

        ),

      ),

    );

  }






  Widget _infoCard(

      String title,

      String text,

      IconData icon,

      ){


    return Container(

      padding:
      const EdgeInsets.all(20),


      decoration:
      BoxDecoration(

        color:card,

        borderRadius:
        BorderRadius.circular(20),

      ),



      child:Row(

        children:[


          Icon(

            icon,

            color:cyan,

            size:35,

          ),


          const SizedBox(width:15),


          Expanded(

            child:Column(

              crossAxisAlignment:
              CrossAxisAlignment.start,


              children:[


                Text(

                  title,

                  style:
                  const TextStyle(

                    color:Colors.white,

                    fontWeight:
                    FontWeight.bold,

                  ),

                ),



                Text(

                  text,

                  style:
                  const TextStyle(

                    color:Colors.white54,

                  ),

                ),

              ],

            ),

          )

        ],

      ),

    );

  }


}