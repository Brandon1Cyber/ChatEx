import 'package:flutter/material.dart';


class ProfileVerificationScreen extends StatelessWidget {

  const ProfileVerificationScreen({super.key});


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

        elevation: 0,


        title: const Text(

          "Verification Center",

          style: TextStyle(

            color: Colors.white,

            fontWeight: FontWeight.bold,

          ),

        ),


        iconTheme: IconThemeData(

          color: cyan,

        ),

      ),




      body: SingleChildScrollView(

        padding: const EdgeInsets.all(20),


        child: Column(

          children: [



            _verificationCard(),



            const SizedBox(height:20),




            _levelCard(

              Icons.verified,

              "Identity Verified",

              "Your account identity is confirmed",

            ),




            _levelCard(

              Icons.shield,

              "Anti-Impersonation Protection",

              "AI protects your identity from copies",

            ),




            _levelCard(

              Icons.workspace_premium,

              "Verification Level",

              "Level 3 Elite Identity",

            ),




            _levelCard(

              Icons.history,

              "Verification History",

              "Last verified today",

            ),




            _levelCard(

              Icons.business,

              "Creator / Business Verification",

              "Available for future upgrades",

            ),



          ],

        ),

      ),

    );

  }







  Widget _verificationCard(){


    return Container(

      width: double.infinity,


      padding: const EdgeInsets.all(25),


      decoration: BoxDecoration(

        color: cyan.withValues(alpha:.12),


        borderRadius: BorderRadius.circular(30),


        border: Border.all(

          color: cyan,

        ),

      ),




      child: Column(

        children: [



          const Icon(

            Icons.verified,

            color: Colors.white,

            size:70,

          ),




          const SizedBox(height:15),




          const Text(

            "Verified ChattªX Identity",

            style: TextStyle(

              color: Colors.white,

              fontSize:24,

              fontWeight: FontWeight.bold,

            ),

          ),




          const SizedBox(height:10),




          Text(

            "Trusted digital identity",

            style: TextStyle(

              color: cyan,

              fontWeight: FontWeight.bold,

            ),

          ),



        ],

      ),

    );

  }







  Widget _levelCard(

      IconData icon,

      String title,

      String subtitle,

      ){


    return Container(

      margin: const EdgeInsets.only(

        bottom:12,

      ),



      padding: const EdgeInsets.all(18),


      decoration: BoxDecoration(

        color: card,

        borderRadius: BorderRadius.circular(22),

      ),




      child: Row(

        children: [



          Container(

            padding: const EdgeInsets.all(12),


            decoration: BoxDecoration(

              color: cyan.withValues(alpha:.15),

              shape: BoxShape.circle,

            ),



            child: Icon(

              icon,

              color: cyan,

            ),

          ),




          const SizedBox(width:15),




          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,


              children: [



                Text(

                  title,

                  style: const TextStyle(

                    color: Colors.white,

                    fontWeight: FontWeight.bold,

                  ),

                ),




                const SizedBox(height:5),




                Text(

                  subtitle,

                  style: const TextStyle(

                    color: Colors.white54,

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