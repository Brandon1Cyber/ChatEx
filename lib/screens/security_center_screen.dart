import 'package:flutter/material.dart';


class SecurityCenterScreen extends StatefulWidget {

  const SecurityCenterScreen({super.key});


  @override
  State<SecurityCenterScreen> createState() =>
      _SecurityCenterScreenState();

}




class _SecurityCenterScreenState
    extends State<SecurityCenterScreen> {


  final Color background =
      const Color(0xFF050816);


  final Color card =
      const Color(0xFF0D1528);


  final Color cyan =
      const Color(0xFF00D9FF);



  bool appLock = true;
  bool biometric = false;
  bool encryption = true;
  bool loginAlerts = true;





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

          "Security Center",

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

          children: [



            _securityStatus(),



            const SizedBox(height:20),




            _securityToggle(

              Icons.lock_outline,

              "ChattªX App Lock",

              "Protect the app with an extra lock",

              appLock,

                  (value){

                setState(() {

                  appLock = value;

                });

              },

            ),




            _securityToggle(

              Icons.fingerprint,

              "Biometric Protection",

              "Use fingerprint or face unlock",

              biometric,

                  (value){

                setState(() {

                  biometric = value;

                });

              },

            ),





            _securityToggle(

              Icons.enhanced_encryption,

              "End-to-End Encryption",

              "Your messages stay private",

              encryption,

                  (value){

                setState(() {

                  encryption = value;

                });

              },

            ),





            _securityToggle(

              Icons.notifications_active,

              "Security Alerts",

              "Receive suspicious login alerts",

              loginAlerts,

                  (value){

                setState(() {

                  loginAlerts = value;

                });

              },

            ),





            const SizedBox(height:20),





            _securityAction(

              Icons.devices,

              "Active Devices",

              "Manage phones and sessions",

            ),





            _securityAction(

              Icons.history,

              "Login History",

              "Review account activity",

            ),





            _securityAction(

              Icons.key,

              "Recovery Keys",

              "Manage account recovery",

            ),





            _securityAction(

              Icons.warning_amber,

              "Emergency Protection",

              "Extra account safety controls",

            ),



          ],

        ),

      ),

    );

  }







  Widget _securityStatus(){


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
        BorderRadius.circular(25),


        border:
        Border.all(

          color:
          cyan,

        ),

      ),



      child:
      Column(

        crossAxisAlignment:
        CrossAxisAlignment.start,


        children: [



          const Text(

            "Security Level",

            style:
            TextStyle(

              color:
              Colors.white70,

            ),

          ),



          const SizedBox(height:10),




          Row(

            children: [


              Text(

                "98%",

                style:
                TextStyle(

                  color:
                  cyan,

                  fontSize:42,

                  fontWeight:
                  FontWeight.bold,

                ),

              ),



              const SizedBox(width:15),




              const Text(

                "Protected",

                style:
                TextStyle(

                  color:
                  Colors.white,

                  fontSize:18,

                ),

              ),



            ],

          ),




          const SizedBox(height:10),




          const Text(

            "Your ChattªX identity has advanced protection enabled.",

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







  Widget _securityToggle(

      IconData icon,

      String title,

      String subtitle,

      bool value,

      Function(bool) onChanged,

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

        activeThumbColor:
        cyan,


        value:
        value,


        onChanged:
        onChanged,



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








  Widget _securityAction(

      IconData icon,

      String title,

      String subtitle,

      ){


    return Container(

      margin:
      const EdgeInsets.only(

        bottom:12,

      ),


      padding:
      const EdgeInsets.all(18),



      decoration:
      BoxDecoration(

        color:
        card,


        borderRadius:
        BorderRadius.circular(20),

      ),



      child:
      Row(

        children: [



          Icon(

            icon,

            color:
            cyan,

            size:30,

          ),




          const SizedBox(width:15),





          Expanded(

            child:
            Column(

              crossAxisAlignment:
              CrossAxisAlignment.start,


              children: [


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



                Text(

                  subtitle,

                  style:
                  const TextStyle(

                    color:
                    Colors.white54,

                  ),

                ),


              ],

            ),

          ),




          const Icon(

            Icons.arrow_forward_ios,

            size:16,

            color:
            Colors.white38,

          )


        ],

      ),

    );

  }


}