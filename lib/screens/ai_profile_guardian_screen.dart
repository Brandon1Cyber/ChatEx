import 'package:flutter/material.dart';


class AIProfileGuardianScreen extends StatefulWidget {

  const AIProfileGuardianScreen({super.key});


  @override
  State<AIProfileGuardianScreen> createState() =>
      _AIProfileGuardianScreenState();

}



class _AIProfileGuardianScreenState
    extends State<AIProfileGuardianScreen> {


  final Color background =
      const Color(0xFF050816);


  final Color card =
      const Color(0xFF0D1528);


  final Color cyan =
      const Color(0xFF00D9FF);



  bool guardianActive = true;

  bool scamDetection = true;

  bool fakeAccountProtection = true;

  bool autoProtection = false;




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

          "AI Profile Guardian",

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



            _guardianCard(),



            const SizedBox(height:20),




            _switchCard(

              Icons.shield,

              "Guardian Mode",

              "AI continuously protects your identity",

              guardianActive,

                  (v){

                setState(() {

                  guardianActive=v;

                });

              },

            ),




            _switchCard(

              Icons.warning,

              "Scam Detection",

              "Detect suspicious messages and profiles",

              scamDetection,

                  (v){

                setState(() {

                  scamDetection=v;

                });

              },

            ),





            _switchCard(

              Icons.person_off,

              "Fake Account Protection",

              "Identify possible fake identities",

              fakeAccountProtection,

                  (v){

                setState(() {

                  fakeAccountProtection=v;

                });

              },

            ),





            _switchCard(

              Icons.auto_awesome,

              "Automatic Protection",

              "AI activates security actions automatically",

              autoProtection,

                  (v){

                setState(() {

                  autoProtection=v;

                });

              },

            ),




            const SizedBox(height:20),




            _recommendationCard(),



          ],

        ),

      ),

    );

  }







  Widget _guardianCard(){


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



          Icon(

            Icons.smart_toy,

            color:
            cyan,

            size:65,

          ),




          const SizedBox(height:15),




          const Text(

            "ChattªX AI Guardian",

            style:
            TextStyle(

              color:
              Colors.white,

              fontSize:24,

              fontWeight:
              FontWeight.bold,

            ),

          ),




          const SizedBox(height:8),




          const Text(

            "Your digital identity protection system",

            textAlign:
            TextAlign.center,


            style:
            TextStyle(

              color:
              Colors.white70,

            ),

          ),



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

        value:
        value,


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








  Widget _recommendationCard(){


    return Container(

      width:
      double.infinity,


      padding:
      const EdgeInsets.all(20),


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

            "AI Recommendations",

            style:
            TextStyle(

              color:
              Colors.white,

              fontWeight:
              FontWeight.bold,

              fontSize:18,

            ),

          ),




          const SizedBox(height:10),




          const Text(

            "• Enable two-factor authentication\n"
            "• Review unknown devices\n"
            "• Keep your profile verification active",

            style:
            TextStyle(

              color:
              Colors.white70,

            ),

          ),



        ],

      ),

    );

  }


}