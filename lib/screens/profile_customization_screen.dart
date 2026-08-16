import 'package:flutter/material.dart';


class ProfileCustomizationScreen extends StatefulWidget {

  const ProfileCustomizationScreen({super.key});


  @override
  State<ProfileCustomizationScreen> createState() =>
      _ProfileCustomizationScreenState();

}



class _ProfileCustomizationScreenState
    extends State<ProfileCustomizationScreen> {


  final Color background =
      const Color(0xFF050816);


  final Color card =
      const Color(0xFF0D1528);


  final Color cyan =
      const Color(0xFF00D9FF);



  String theme =
      "Cyber Blue";


  bool animatedProfile = true;

  bool showBadges = true;

  bool publicProfile = true;

  bool avatarGlow = true;





  @override
  Widget build(BuildContext context) {


    return Scaffold(

      backgroundColor:
      background,


      appBar: AppBar(

        backgroundColor:
        background,

        elevation:0,


        title:
        const Text(

          "Customization Studio",

          style:
          TextStyle(

            color:
            Colors.white,

            fontWeight:
            FontWeight.bold,

          ),

        ),


        iconTheme:
        IconThemeData(

          color:
          cyan,

        ),

      ),





      body:
      SingleChildScrollView(

        padding:
        const EdgeInsets.all(20),



        child:
        Column(

          children:[



            _previewCard(),



            const SizedBox(height:20),




            _themeCard(),




            _switchCard(

              Icons.animation,

              "Animated Profile",

              "Add futuristic profile animations",

              animatedProfile,

                  (v){

                setState(() {

                  animatedProfile=v;

                });

              },

            ),





            _switchCard(

              Icons.auto_awesome,

              "Avatar Glow",

              "Enable neon avatar effects",

              avatarGlow,

                  (v){

                setState(() {

                  avatarGlow=v;

                });

              },

            ),





            _switchCard(

              Icons.badge,

              "Show Badges",

              "Display achievements and ranks",

              showBadges,

                  (v){

                setState(() {

                  showBadges=v;

                });

              },

            ),





            _switchCard(

              Icons.public,

              "Public Profile",

              "Allow others to discover you",

              publicProfile,

                  (v){

                setState(() {

                  publicProfile=v;

                });

              },

            ),



          ],

        ),

      ),

    );

  }








  Widget _previewCard(){


    return Container(

      width:
      double.infinity,


      padding:
      const EdgeInsets.all(25),


      decoration:
      BoxDecoration(

        color:
        cyan.withValues(alpha:.12),


        borderRadius:
        BorderRadius.circular(30),


        border:
        Border.all(

          color:
          cyan,

        ),

      ),




      child:
      Column(

        children:[



          const CircleAvatar(

            radius:50,


            backgroundColor:
            Color(0xFF111827),



            child:
            Icon(

              Icons.person,

              color:
              Colors.white,

              size:55,

            ),

          ),




          const SizedBox(height:15),




          const Text(

            "ChattªX Identity Preview",

            style:
            TextStyle(

              color:
              Colors.white,

              fontSize:22,

              fontWeight:
              FontWeight.bold,

            ),

          ),



          const SizedBox(height:8),




          Text(

            theme,

            style:
            TextStyle(

              color:
              cyan,

            ),

          ),



        ],

      ),

    );

  }








  Widget _themeCard(){


    return Container(

      padding:
      const EdgeInsets.all(20),


      margin:
      const EdgeInsets.only(

        bottom:12,

      ),



      decoration:
      BoxDecoration(

        color:
        card,


        borderRadius:
        BorderRadius.circular(22),

      ),



      child:
      Column(

        crossAxisAlignment:
        CrossAxisAlignment.start,


        children:[



          const Text(

            "Profile Theme",

            style:
            TextStyle(

              color:
              Colors.white,

              fontWeight:
              FontWeight.bold,

            ),

          ),




          DropdownButton<String>(

            dropdownColor:
            card,


            value:
            theme,


            items:[

              "Cyber Blue",

              "Neon Purple",

              "Quantum Dark",

              "Future Glass",

            ]

                .map(

                    (e)=>

                    DropdownMenuItem(

                      value:e,


                      child:
                      Text(

                        e,

                        style:
                        const TextStyle(

                          color:
                          Colors.white,

                        ),

                      ),

                    )

            )

                .toList(),



            onChanged:(v){

              setState(() {

                theme=v!;

              });

            },


          )

        ],

      ),

    );

  }







  Widget _switchCard(

      IconData icon,

      String title,

      String subtitle,

      bool value,

      Function(bool) changed,

      ){


    return Container(

      margin:
      const EdgeInsets.only(

        bottom:12,

      ),


      decoration:
      BoxDecoration(

        color:
        card,


        borderRadius:
        BorderRadius.circular(20),

      ),



      child:
      SwitchListTile(

        value:value,


        activeThumbColor:
        cyan,


        onChanged:
        changed,



        secondary:
        Icon(

          icon,

          color:
          cyan,

        ),



        title:
        Text(

          title,

          style:
          const TextStyle(

            color:
            Colors.white,

            fontWeight:
            FontWeight.bold,

          ),

        ),



        subtitle:
        Text(

          subtitle,

          style:
          const TextStyle(

            color:
            Colors.white54,

          ),

        ),

      ),

    );

  }


}