import 'package:flutter/material.dart';

class AIProfileScreen extends StatefulWidget {
  const AIProfileScreen({super.key});

  @override
  State<AIProfileScreen> createState() =>
      _AIProfileScreenState();
}


class _AIProfileScreenState
    extends State<AIProfileScreen> {


  final Color background =
      const Color(0xFF050816);

  final Color card =
      const Color(0xFF0D1528);

  final Color cyan =
      const Color(0xFF00D9FF);

  final Color purple =
      const Color(0xFF8A2EFF);



  bool aiAssistant = true;
  bool smartReplies = true;
  bool memory = false;
  bool scamDetection = true;



  String personality = "Advanced";



  @override
  Widget build(BuildContext context) {


    return Scaffold(

      backgroundColor: background,


      appBar: AppBar(

        backgroundColor: background,

        elevation:0,


        title: const Text(

          "ChatEx AI Identity",

          style: TextStyle(

            color:Colors.white,

            fontWeight:
            FontWeight.bold,

          ),

        ),


        iconTheme:
        IconThemeData(
          color:cyan,
        ),

      ),




      body: SingleChildScrollView(

        padding:
        const EdgeInsets.all(20),


        child: Column(

          children:[



            _aiHeader(),



            const SizedBox(height:20),




            _toggleCard(

              Icons.smart_toy,

              "AI Assistant",

              "Enable your personal ChatEx AI",

              aiAssistant,

                  (value){

                setState(() {

                  aiAssistant=value;

                });

              },

            ),




            _toggleCard(

              Icons.flash_on,

              "Smart Replies",

              "AI suggests faster responses",

              smartReplies,

                  (value){

                setState(() {

                  smartReplies=value;

                });

              },

            ),




            _toggleCard(

              Icons.psychology,

              "AI Memory",

              "Allow AI to remember preferences",

              memory,

                  (value){

                setState(() {

                  memory=value;

                });

              },

            ),




            _toggleCard(

              Icons.security,

              "AI Scam Protection",

              "Detect suspicious messages",

              scamDetection,

                  (value){

                setState(() {

                  scamDetection=value;

                });

              },

            ),





            const SizedBox(height:20),




            _personalityCard(),




            const SizedBox(height:20),




            _featureCard(

              Icons.auto_awesome,

              "AI Profile Optimizer",

              "AI improves your digital identity",

            ),




            _featureCard(

              Icons.summarize,

              "Conversation Intelligence",

              "Generate summaries and insights",

            ),




            _featureCard(

              Icons.translate,

              "Universal Translator",

              "Communicate in any language",

            ),



          ],

        ),

      ),

    );

  }






  Widget _aiHeader(){


    return Container(

      width:
      double.infinity,


      padding:
      const EdgeInsets.all(25),


      decoration:
      BoxDecoration(

        borderRadius:
        BorderRadius.circular(30),


        gradient:
        LinearGradient(

          colors:[

            cyan.withValues(alpha:.20),

            purple.withValues(alpha:.20),

          ],

        ),

        border:
        Border.all(

          color:cyan,

        ),

      ),



      child:Column(

        children:[


          Container(

            padding:
            const EdgeInsets.all(20),


            decoration:
            BoxDecoration(

              shape:
              BoxShape.circle,


              color:
              cyan.withValues(alpha:.15),

            ),



            child:Icon(

              Icons.smart_toy,

              size:55,

              color:cyan,

            ),

          ),




          const SizedBox(height:15),




          const Text(

            "Your AI Companion",

            style:TextStyle(

              color:Colors.white,

              fontSize:22,

              fontWeight:
              FontWeight.bold,

            ),

          ),




          const SizedBox(height:8),




          const Text(

            "Customize how ChatEx AI helps you",

            style:TextStyle(

              color:Colors.white70,

            ),

          ),


        ],

      ),

    );

  }







  Widget _toggleCard(

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

        color:card,

        borderRadius:
        BorderRadius.circular(20),

      ),



      child:
      SwitchListTile(

        activeThumbColor:cyan,


        value:value,


        onChanged:onChanged,


        secondary:
        Icon(

          icon,

          color:cyan,

        ),



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

      ),

    );

  }







  Widget _personalityCard(){


    return Container(

      padding:
      const EdgeInsets.all(20),


      decoration:
      BoxDecoration(

        color:card,

        borderRadius:
        BorderRadius.circular(20),

      ),



      child:Column(

        crossAxisAlignment:
        CrossAxisAlignment.start,


        children:[



          const Text(

            "AI Personality",

            style:TextStyle(

              color:Colors.white,

              fontSize:18,

              fontWeight:
              FontWeight.bold,

            ),

          ),



          const SizedBox(height:15),



          DropdownButtonFormField<String>(

            initialValue:personality,


            dropdownColor:
            card,


            items:[

              "Friendly",

              "Professional",

              "Creative",

              "Advanced",

            ].map((e)=>DropdownMenuItem(

              value:e,

              child:Text(

                e,

                style:
                const TextStyle(

                  color:Colors.white,

                ),

              ),

            )).toList(),



            onChanged:(value){

              setState(() {

                personality=value!;

              });

            },


          )


        ],

      ),

    );

  }







  Widget _featureCard(

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

        color:card,

        borderRadius:
        BorderRadius.circular(20),

      ),



      child:Row(

        children:[


          Icon(

            icon,

            color:cyan,

            size:30,

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

                  subtitle,

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