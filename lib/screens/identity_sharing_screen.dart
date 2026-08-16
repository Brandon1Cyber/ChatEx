import 'package:flutter/material.dart';


class IdentitySharingScreen extends StatelessWidget {

  const IdentitySharingScreen({super.key});


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

          "Share ChattªX Identity",

          style: TextStyle(

            color: Colors.white,

            fontWeight: FontWeight.bold,

          ),

        ),



        iconTheme: IconThemeData(

          color: cyan,

        ),

      ),





      body: Padding(

        padding: const EdgeInsets.all(20),


        child: Column(

          children: [



            _identityPreview(),



            const SizedBox(height:25),




            _actionCard(

              Icons.copy,

              "Copy ChattªX ID",

              "CX-847291",

            ),




            _actionCard(

              Icons.qr_code_2,

              "Generate Identity QR",

              "Let others scan your identity",

            ),




            _actionCard(

              Icons.link,

              "Create Profile Link",

              "Share your public identity",

            ),




            _actionCard(

              Icons.security,

              "Sharing Privacy",

              "Control what others can see",

            ),



          ],

        ),

      ),

    );

  }








  Widget _identityPreview(){


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



          const CircleAvatar(

            radius:50,

            backgroundColor: Color(0xFF111827),


            child: Icon(

              Icons.person,

              color: Colors.white,

              size:55,

            ),

          ),



          const SizedBox(height:15),




          const Text(

            "ChattªX User",

            style: TextStyle(

              color: Colors.white,

              fontSize:24,

              fontWeight: FontWeight.bold,

            ),

          ),




          const SizedBox(height:8),




          Text(

            "CX-847291",

            style: TextStyle(

              color: cyan,

              fontWeight: FontWeight.bold,

            ),

          ),



        ],

      ),

    );

  }







  Widget _actionCard(

      IconData icon,

      String title,

      String subtitle,

      ){


    return Container(

      margin: const EdgeInsets.only(

        bottom:12,

      ),



      decoration: BoxDecoration(

        color: card,

        borderRadius: BorderRadius.circular(22),

      ),



      child: ListTile(

        contentPadding:

        const EdgeInsets.all(12),



        leading: Container(

          padding: const EdgeInsets.all(10),


          decoration: BoxDecoration(

            color: cyan.withValues(alpha:.15),

            shape: BoxShape.circle,

          ),



          child: Icon(

            icon,

            color: cyan,

          ),

        ),



        title: Text(

          title,

          style: const TextStyle(

            color: Colors.white,

            fontWeight: FontWeight.bold,

          ),

        ),



        subtitle: Text(

          subtitle,

          style: const TextStyle(

            color: Colors.white54,

          ),

        ),



        trailing: Icon(

          Icons.arrow_forward_ios,

          color: cyan,

          size:16,

        ),



        onTap: (){},


      ),

    );

  }


}