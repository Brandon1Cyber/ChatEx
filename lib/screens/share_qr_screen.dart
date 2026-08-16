import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'generate_qr_screen.dart';
import 'scan_qr_screen.dart';


class ShareQrScreen extends StatefulWidget {
  const ShareQrScreen({super.key});

  @override
  State<ShareQrScreen> createState() =>
      _ShareQrScreenState();
}


class _ShareQrScreenState extends State<ShareQrScreen> {

  List<PlatformFile> selectedFiles = [];


  Future<void> _pickFiles() async {

    final result =
        await FilePicker.platform.pickFiles(
      allowMultiple: true,
    );


    if (result != null) {

      setState(() {

        selectedFiles = result.files;

      });

    }

  }



  void _removeFile(int index) {

    setState(() {

      selectedFiles.removeAt(index);

    });

  }



  String _formatSize(int bytes) {

    if (bytes < 1024) {
      return "$bytes B";
    }


    if (bytes < 1024 * 1024) {

      return
          "${(bytes / 1024).toStringAsFixed(1)} KB";

    }


    if (bytes < 1024 * 1024 * 1024) {

      return
          "${(bytes / 1024 / 1024).toStringAsFixed(1)} MB";

    }


    return
        "${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB";

  }



  int get totalSize {

    int total = 0;

    for (final file in selectedFiles) {

      total += file.size;

    }

    return total;

  }



  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
          const Color(0xFF050816),


      appBar: AppBar(

        backgroundColor:
            const Color(0xFF050816),

        elevation: 0,

        centerTitle: true,


        title: const Text(

          "ChattªX Transfer",

          style: TextStyle(

            color: Colors.white,

            fontSize: 22,

            fontWeight:
                FontWeight.bold,

          ),

        ),

      ),


      body: SingleChildScrollView(

        physics:
            const BouncingScrollPhysics(),


        padding:
            const EdgeInsets.all(18),


        child: Column(

          children: [


            _buildHeroCard(),


            const SizedBox(height: 20),


            _buildSendCard(),


            const SizedBox(height: 20),


            if (selectedFiles.isNotEmpty)
              _buildSelectedFiles(),


            const SizedBox(height: 20),


            _buildReceiveCard(),


            const SizedBox(height: 25),


            _buildRecentTransfers(),


            const SizedBox(height: 30),


          ],

        ),

      ),

    );

  }
  Widget _buildHeroCard() {

    return Container(

      width: double.infinity,

      padding:
          const EdgeInsets.all(20),


      decoration: BoxDecoration(

        gradient: const LinearGradient(

          begin:
              Alignment.topLeft,

          end:
              Alignment.bottomRight,


          colors: [

            Color(0xFF7B2FF7),

            Color(0xFF111827),

          ],

        ),


        borderRadius:
            BorderRadius.circular(24),


        border: Border.all(

          color:
              Colors.white10,

        ),

      ),


      child: Column(

        crossAxisAlignment:
            CrossAxisAlignment.start,


        children: [


          Row(

            children: [


              Container(

                width: 55,

                height: 55,


                decoration: BoxDecoration(

                  color:
                      Colors.white
                          .withValues(
                            alpha: 0.12,
                          ),


                  borderRadius:
                      BorderRadius.circular(18),

                ),


                child: const Icon(

                  Icons.qr_code_2_rounded,

                  color:
                      Colors.white,

                  size: 32,

                ),

              ),


              const SizedBox(width: 14),


              const Expanded(

                child: Text(

                  "ChattªX Share",

                  style: TextStyle(

                    color:
                        Colors.white,

                    fontSize:
                        24,

                    fontWeight:
                        FontWeight.w900,

                  ),

                ),

              ),

            ],

          ),


          const SizedBox(height: 15),


          const Text(

            "Fast, secure and simple transfers using ChattªX QR technology.",

            style: TextStyle(

              color:
                  Colors.white70,

              fontSize:
                  14,

            ),

          ),


        ],

      ),

    );

  }





  Widget _buildSendCard() {

    return Container(

      padding:
          const EdgeInsets.all(20),


      decoration: BoxDecoration(

        color:
            const Color(0xFF111827),


        borderRadius:
            BorderRadius.circular(22),


        border: Border.all(

          color:
              Colors.white10,

        ),

      ),


      child: Column(

        children: [


          const Icon(

            Icons.upload_file_rounded,

            color:
                Color(0xFF7B2FF7),

            size:
                50,

          ),


          const SizedBox(height: 12),


          const Text(

            "Send Files",

            style: TextStyle(

              color:
                  Colors.white,

              fontSize:
                  22,

              fontWeight:
                  FontWeight.bold,

            ),

          ),


          const SizedBox(height: 8),


          const Text(

            "Select photos, videos, documents or any file.",

            textAlign:
                TextAlign.center,


            style: TextStyle(

              color:
                  Colors.white60,

              fontSize:
                  14,

            ),

          ),


          const SizedBox(height: 20),


          SizedBox(

            width:
                double.infinity,

            height:
                55,


            child:
                ElevatedButton.icon(

              onPressed:
                  _pickFiles,


              icon:
                  const Icon(
                    Icons.folder_open_rounded,
                  ),


              label:
                  const Text(
                    "Choose Files",
                  ),


              style:
                  ElevatedButton.styleFrom(


                backgroundColor:
                    const Color(0xFF7B2FF7),


                foregroundColor:
                    Colors.white,


                shape:
                    RoundedRectangleBorder(

                  borderRadius:
                      BorderRadius.circular(16),

                ),

              ),

            ),

          ),


        ],

      ),

    );

  }





  Widget _buildSelectedFiles() {

    return Column(

      crossAxisAlignment:
          CrossAxisAlignment.start,


      children: [


        Container(

          padding:
              const EdgeInsets.all(16),


          decoration: BoxDecoration(

            color:
                const Color(0xFF111827),


            borderRadius:
                BorderRadius.circular(18),

          ),


          child: Column(

            crossAxisAlignment:
                CrossAxisAlignment.start,


            children: [


              Text(

                "${selectedFiles.length} File(s) Selected",

                style: const TextStyle(

                  color:
                      Colors.white,

                  fontSize:
                      18,

                  fontWeight:
                      FontWeight.bold,

                ),

              ),


              const SizedBox(height: 5),


              Text(

                "Total Size: ${_formatSize(totalSize)}",

                style: const TextStyle(

                  color:
                      Color(0xFF00D9FF),

                  fontWeight:
                      FontWeight.bold,

                ),

              ),

            ],

          ),

        ),


        const SizedBox(height: 15),


        ...selectedFiles.asMap().entries.map((entry) {


          final index =
              entry.key;


          final file =
              entry.value;


          return Container(

            margin:
                const EdgeInsets.only(
                  bottom: 12,
                ),


            decoration: BoxDecoration(

              color:
                  const Color(0xFF111827),


              borderRadius:
                  BorderRadius.circular(18),

            ),


            child: ListTile(

              leading:
                  const CircleAvatar(

                backgroundColor:
                    Color(0xFF00D9FF),


                child: Icon(

                  Icons.insert_drive_file,

                  color:
                      Colors.white,

                ),

              ),


              title:
                  Text(

                file.name,

                maxLines:
                    1,

                overflow:
                    TextOverflow.ellipsis,


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

                _formatSize(file.size),

                style:
                    const TextStyle(

                  color:
                      Colors.white60,

                ),

              ),


              trailing:
                  IconButton(

                icon:
                    const Icon(

                  Icons.delete_outline,

                  color:
                      Colors.redAccent,

                ),


                onPressed:
                    () => _removeFile(index),

              ),

            ),

          );


        }),


        const SizedBox(height: 10),


        SizedBox(

          width:
              double.infinity,

          height:
              55,


          child:
              ElevatedButton.icon(

            onPressed: () async {


  for (final file in selectedFiles) {


    await FirebaseFirestore.instance
        .collection("file_transfers")
        .add({

      "userId":
          FirebaseAuth.instance.currentUser!.uid,


      "fileName":
          file.name,


      "size":
          _formatSize(file.size),


      "type":

          file.extension == "jpg" ||
          file.extension == "png" ||
          file.extension == "jpeg"

          ? "image"

          : "file",


      "status":
          "Sent",


      "createdAt":
          FieldValue.serverTimestamp(),

    });


  }



  Navigator.push(

    context,

    MaterialPageRoute(

      builder: (_) =>
          const GenerateQrScreen(),

    ),

  );


},


            icon:
                const Icon(
                  Icons.qr_code_2,
                ),


            label:
                const Text(
                  "Create ChattªX QR",
                ),


            style:
                ElevatedButton.styleFrom(

              backgroundColor:
                  const Color(0xFF00D9FF),


              foregroundColor:
                  Colors.white,


              shape:
                  RoundedRectangleBorder(

                borderRadius:
                    BorderRadius.circular(16),

              ),

            ),

          ),

        ),

      ],

    );

  }
  Widget _buildReceiveCard() {

    return Container(

      padding:
          const EdgeInsets.all(20),


      decoration: BoxDecoration(

        color:
            const Color(0xFF111827),


        borderRadius:
            BorderRadius.circular(22),


        border:
            Border.all(

          color:
              Colors.white10,

        ),

      ),


      child: Column(

        children: [


          const Icon(

            Icons.qr_code_scanner_rounded,

            color:
                Color(0xFF00D9FF),

            size:
                50,

          ),


          const SizedBox(height: 12),


          const Text(

            "Receive Files",

            style: TextStyle(

              color:
                  Colors.white,

              fontSize:
                  22,

              fontWeight:
                  FontWeight.bold,

            ),

          ),


          const SizedBox(height: 8),


          const Text(

            "Scan another user's ChattªX QR code to receive files securely.",

            textAlign:
                TextAlign.center,


            style: TextStyle(

              color:
                  Colors.white60,

              fontSize:
                  14,

            ),

          ),


          const SizedBox(height: 20),


          SizedBox(

            width:
                double.infinity,

            height:
                55,


            child:
                OutlinedButton.icon(

              onPressed: () {


                Navigator.push(

                  context,

                  MaterialPageRoute(

                    builder: (_) =>
                        const ScanQrScreen(),

                  ),

                );


              },


              icon:
                  const Icon(

                Icons.qr_code_scanner,

              ),


              label:
                  const Text(

                "Scan ChattªX QR",

              ),


              style:
                  OutlinedButton.styleFrom(

                foregroundColor:
                    const Color(0xFF00D9FF),


                side:
                    const BorderSide(

                  color:
                      Color(0xFF00D9FF),

                ),


                shape:
                    RoundedRectangleBorder(

                  borderRadius:
                      BorderRadius.circular(16),

                ),

              ),

            ),

          ),

        ],

      ),

    );

  }






  Widget _buildRecentTransfers() {

  final user = FirebaseAuth.instance.currentUser;


  return Column(

    crossAxisAlignment:
        CrossAxisAlignment.start,


    children: [

      const Text(

        "Recent Transfers",

        style: TextStyle(

          color: Colors.white,

          fontSize: 20,

          fontWeight: FontWeight.bold,

        ),

      ),


      const SizedBox(height: 15),



      StreamBuilder<QuerySnapshot>(

        stream:

        FirebaseFirestore.instance
            .collection("file_transfers")
            .where(
              "userId",
              isEqualTo: user?.uid,
            )
            .orderBy(
              "createdAt",
              descending: true,
            )
            .limit(10)
            .snapshots(),



        builder: (context, snapshot) {


          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {


            return Container(

              padding:
                  const EdgeInsets.all(20),


              decoration:
                  BoxDecoration(

                color:
                    const Color(0xFF111827),

                borderRadius:
                    BorderRadius.circular(18),

              ),


              child: const Center(

                child: Text(

                  "No recent files",

                  style:
                      TextStyle(

                    color:
                        Colors.white54,

                  ),

                ),

              ),

            );

          }



          return Column(

            children:

            snapshot.data!.docs.map((doc) {


              final data =
                  doc.data()
                  as Map<String,dynamic>;



              return _TransferTile(

                icon:

                data["type"] == "image"

                ? Icons.image_rounded

                : data["type"] == "video"

                ? Icons.video_file_rounded

                : Icons.insert_drive_file_rounded,



                title:

                data["fileName"] ??
                    "Unknown File",



                subtitle:

                "${data["status"] ?? "Sent"} • ${data["size"] ?? ""}",

              );


            }).toList(),

          );


        },

      ),

    ],

  );

}
}




class _TransferTile extends StatelessWidget {

  final IconData icon;

  final String title;

  final String subtitle;



  const _TransferTile({

    required this.icon,

    required this.title,

    required this.subtitle,

  });



  @override
  Widget build(BuildContext context) {


    return Container(

      margin:
          const EdgeInsets.only(
            bottom: 12,
          ),


      decoration: BoxDecoration(

        color:
            const Color(0xFF111827),


        borderRadius:
            BorderRadius.circular(18),


        border:
            Border.all(

          color:
              Colors.white10,

        ),

      ),


      child: ListTile(

        contentPadding:
            const EdgeInsets.symmetric(

          horizontal:
              18,

          vertical:
              8,

        ),


        leading:
            CircleAvatar(

          radius:
              24,


          backgroundColor:
              const Color(0xFF7B2FF7),


          child:
              Icon(

            icon,

            color:
                Colors.white,

          ),

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
                Colors.white60,

          ),

        ),


        trailing:
            const Icon(

          Icons.chevron_right,

          color:
              Colors.white54,

        ),

      ),

    );

  }

}