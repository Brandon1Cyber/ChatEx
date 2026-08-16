import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BirthdaysScreen extends StatefulWidget {
  const BirthdaysScreen({super.key});

  @override
  State<BirthdaysScreen> createState() => _BirthdaysScreenState();
}

class _BirthdaysScreenState extends State<BirthdaysScreen>
    with SingleTickerProviderStateMixin {

  final TextEditingController _searchController =
      TextEditingController();

  String search = "";

  late AnimationController _animationController;


  @override
  void initState() {
    super.initState();

    _animationController =
        AnimationController(
          vsync: this,
          duration: const Duration(seconds: 2),
        )
        ..repeat();
  }


  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }



  bool _isToday(Timestamp? birthday) {

    if (birthday == null) return false;

    final date = birthday.toDate();
    final now = DateTime.now();


    return date.day == now.day &&
        date.month == now.month;
  }



  int _calculateAge(Timestamp? birthday) {

    if (birthday == null) return 0;


    final birth = birthday.toDate();
    final now = DateTime.now();


    int age = now.year - birth.year;


    if(now.month < birth.month ||
        (now.month == birth.month &&
        now.day < birth.day)) {

      age--;
    }


    return age;
  }



  int _daysUntilBirthday(Timestamp? birthday) {

    if(birthday == null) return 999;


    final birth = birthday.toDate();
    final now = DateTime.now();


    DateTime next =
        DateTime(
          now.year,
          birth.month,
          birth.day,
        );


    if(next.isBefore(now)) {

      next =
          DateTime(
            now.year + 1,
            birth.month,
            birth.day,
          );
    }


    return next
        .difference(now)
        .inDays;
  }




  void _sendWish(String name) {

    ScaffoldMessenger.of(context)
        .showSnackBar(

      SnackBar(
        backgroundColor:
            const Color(0xFF111827),

        content: Text(
          "🎂 Birthday wish sent to $name",
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
      ),
    );
  }





  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
          const Color(0xFF050816),


      appBar: AppBar(

        backgroundColor:
            Colors.transparent,

        elevation: 0,

        centerTitle: true,


        title: const Text(
          "🎂 ChattªX Birthdays",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),



      body: Column(

        children: [


          Padding(
            padding:
                const EdgeInsets.all(16),

            child: Container(

              decoration:
                  BoxDecoration(

                color:
                    const Color(0xFF111827),

                borderRadius:
                    BorderRadius.circular(20),
              ),


              child: TextField(

                controller:
                    _searchController,


                style:
                    const TextStyle(
                      color: Colors.white,
                    ),


                onChanged:(value){

                  setState(() {
                    search=value
                        .toLowerCase();
                  });

                },


                decoration:
                    const InputDecoration(

                  hintText:
                      "Search birthdays...",


                  hintStyle:
                      TextStyle(
                        color:
                          Colors.white54,
                      ),


                  prefixIcon:
                      Icon(
                        Icons.search,
                        color:
                          Color(0xFF00D9FF),
                      ),


                  border:
                      InputBorder.none,

                  contentPadding:
                      EdgeInsets.all(16),
                ),
              ),
            ),
          ),



          Expanded(

            child:
            StreamBuilder<QuerySnapshot>(

              stream:
                  FirebaseFirestore
                  .instance
                  .collection("users")
                  .snapshots(),


              builder:(context,snapshot){


                if(!snapshot.hasData){

                  return const Center(

                    child:
                    CircularProgressIndicator(
                      color:
                      Color(0xFF00D9FF),
                    ),
                  );
                }



                List<QueryDocumentSnapshot>
                users =
                    snapshot.data!.docs
                    .where((doc){

                  final data =
                  doc.data()
                  as Map<String,dynamic>;


                  final name =
                  (data["name"] ??
                      "")
                      .toString()
                      .toLowerCase();


                  return name
                      .contains(search);

                }).toList();




                users.sort((a,b){


                  final aData =
                  a.data()
                  as Map<String,dynamic>;


                  final bData =
                  b.data()
                  as Map<String,dynamic>;



                  return _daysUntilBirthday(
                      aData["birthday"])
                      .compareTo(
                    _daysUntilBirthday(
                        bData["birthday"]),
                  );

                });




                if(users.isEmpty){

                  return const Center(

                    child:
                    Text(
                      "No birthdays found 🎂",
                      style:
                      TextStyle(
                        color:
                        Colors.white70,
                        fontSize:18,
                      ),
                    ),
                  );
                }



                return ListView.builder(

                  padding:
                  const EdgeInsets.all(16),


                  itemCount:
                  users.length,


                  itemBuilder:(context,index){

                    return _birthdayCard(users[index]);

                  },
                );

              },

            ),
          ),

        ],
      ),
    );
  }
  Widget _birthdayCard(QueryDocumentSnapshot user) {

    final data =
        user.data() as Map<String, dynamic>;


    final String name =
        data["name"] ?? "Unknown User";


    final String photoUrl =
        data["photoUrl"] ?? "";


    final Timestamp? birthday =
        data["birthday"];


    final bool isToday =
        _isToday(birthday);


    final int age =
        _calculateAge(birthday);


    final int daysLeft =
        _daysUntilBirthday(birthday);



    return AnimatedContainer(

      duration:
          const Duration(milliseconds:500),


      margin:
          const EdgeInsets.only(
            bottom:16,
          ),


      padding:
          const EdgeInsets.all(16),


      decoration:
          BoxDecoration(

        color:
            const Color(0xFF111827),


        borderRadius:
            BorderRadius.circular(24),


        border:
            Border.all(

          color:
          isToday
              ? const Color(0xFFFFB300)
              : const Color(0xFF26314D),


          width:
          isToday ? 2 : 1,

        ),



        boxShadow:
        isToday
            ? [

          BoxShadow(

            color:
            Colors.orange
                .withValues(alpha: .25),

            blurRadius:20,

          )

        ]

            : [],

      ),



      child:
      Column(

        children:[


          Row(

            children:[



              Stack(

                children:[

                  CircleAvatar(

                    radius:35,


                    backgroundColor:
                    const Color(
                        0xFF1B2338),


                    backgroundImage:
                    photoUrl.isNotEmpty
                        ? NetworkImage(photoUrl)
                        : null,


                    child:
                    photoUrl.isEmpty

                        ? const Icon(

                      Icons.person,

                      size:35,

                      color:
                      Colors.white,

                    )

                        : null,

                  ),



                  if(isToday)

                    Positioned(

                      right:-2,

                      bottom:-2,

                      child:
                      Container(

                        padding:
                        const EdgeInsets.all(5),


                        decoration:
                        const BoxDecoration(

                          color:
                          Colors.orange,

                          shape:
                          BoxShape.circle,

                        ),


                        child: const Text(
  "🎂",
  style: TextStyle(
    fontSize: 16,
  ),
),

                      ),

                    ),

                ],

              ),



              const SizedBox(
                  width:16
              ),




              Expanded(

                child:
                Column(

                  crossAxisAlignment:
                  CrossAxisAlignment.start,


                  children:[


                    Row(

                      children:[

                        Expanded(

                          child:
                          Text(

                            name,

                            overflow:
                            TextOverflow.ellipsis,


                            style:
                            const TextStyle(

                              color:
                              Colors.white,

                              fontSize:18,

                              fontWeight:
                              FontWeight.bold,

                            ),

                          ),

                        ),



                        if(isToday)

                          const Text(

                            "🎉🎉",

                            style:
                            TextStyle(
                              fontSize:22,
                            ),

                          ),

                      ],

                    ),



                    const SizedBox(
                        height:6
                    ),



                    Text(

                      isToday

                          ? "Happy Birthday! Turning $age today 🎂"

                          : "Turning $age in $daysLeft day${daysLeft == 1 ? "" : "s"}",

                      style:
                      const TextStyle(

                        color:
                        Colors.white70,

                        fontSize:14,

                      ),

                    ),


                  ],

                ),

              ),

            ],

          ),



          const SizedBox(
              height:16
          ),



          Row(

            children:[



              Container(

                padding:
                const EdgeInsets.symmetric(

                  horizontal:14,

                  vertical:7,

                ),


                decoration:
                BoxDecoration(

                  color:
                  isToday

                      ? Colors.orange

                      : const Color(
                      0xFF7B2FF7),


                  borderRadius:
                  BorderRadius.circular(20),

                ),


                child:
                Text(

                  isToday

                      ? "Birthday Today"

                      : "$daysLeft Days Left",


                  style:
                  const TextStyle(

                    color:
                    Colors.white,

                    fontWeight:
                    FontWeight.bold,

                    fontSize:12,

                  ),

                ),

              ),




              const Spacer(),



              GestureDetector(

                onTap:(){

                  _sendWish(name);

                },


                child:
                Container(

                  padding:
                  const EdgeInsets.symmetric(

                    horizontal:15,

                    vertical:8,

                  ),


                  decoration:
                  BoxDecoration(

                    gradient:
                    const LinearGradient(

                      colors:[

                        Color(0xFF00D9FF),

                        Color(0xFF8A2EFF),

                      ],

                    ),


                    borderRadius:
                    BorderRadius.circular(20),

                  ),


                  child:
                  const Row(

                    children:[

                      Icon(

                        Icons.send,

                        size:15,

                        color:
                        Colors.white,

                      ),


                      SizedBox(
                          width:5
                      ),


                      Text(

                        "Wish",

                        style:
                        TextStyle(

                          color:
                          Colors.white,

                          fontWeight:
                          FontWeight.bold,

                        ),

                      ),

                    ],

                  ),

                ),

              ),

            ],

          ),



          if(isToday)

            Padding(

              padding:
              const EdgeInsets.only(
                  top:14
              ),


              child:
              AnimatedBuilder(

                animation:
                _animationController,


                builder:(context,child){


                  return Transform.rotate(

                    angle:
                    _animationController.value
                    * 6.28,


                    child:
                    const Text(

                      "✨🎈🎂✨",

                      style:
                      TextStyle(
                        fontSize:30,
                      ),

                    ),

                  );

                },

              ),

            ),

        ],

      ),

    );

  }
    }