import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/cloudinary_service.dart';
import '../services/chat_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final Color background = const Color(0xFF050816);
  final Color card = const Color(0xFF0D1528);
  final Color cyan = const Color(0xFF00D9FF);

  final TextEditingController nameController =
      TextEditingController();

  final TextEditingController bioController =
      TextEditingController();

  final ImagePicker _picker = ImagePicker();

  File? _profileImage;

  String? _currentPhotoUrl;

  String selectedTheme = "Cyber Blue";

  bool creatorMode = false;
  bool verifiedRequest = false;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ============================================================
  // LOAD CURRENT PROFILE
  // ============================================================

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
      return;
    }

    try {
      await user.reload();

      final refreshedUser =
          FirebaseAuth.instance.currentUser;

      final doc = await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .get();

      final data = doc.data() ?? {};

      if (!mounted) return;

      setState(() {
        nameController.text =
            data["name"] ??
            refreshedUser?.displayName ??
            "";

        bioController.text =
            data["bio"] ??
            "";

        _currentPhotoUrl =
            data["photoUrl"] ??
            refreshedUser?.photoURL;

        selectedTheme =
            data["theme"] ??
            "Cyber Blue";

        creatorMode =
            data["creatorMode"] ??
            false;

        verifiedRequest =
            data["verifiedRequest"] ??
            false;

        _loading = false;
      });
    } catch (e) {
      debugPrint("Profile load error: $e");

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // PICK IMAGE
  // ============================================================

  Future<void> _pickImage() async {
    final XFile? image =
        await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (image == null) return;

    setState(() {
      _profileImage = File(image.path);
    });
  }

  // ============================================================
  // UPLOAD IMAGE
  // ============================================================

  Future<String?> _uploadProfileImage() async {
    if (_profileImage == null) {
      // IMPORTANT:
      // Keep the existing picture instead of erasing it.
      return _currentPhotoUrl;
    }

    try {
      final photoUrl =
          await CloudinaryService.uploadImage(
        _profileImage!,
      );

      if (photoUrl == null ||
          photoUrl.isEmpty) {
        return _currentPhotoUrl;
      }

      return photoUrl;
    } catch (e) {
      debugPrint(
        "Cloudinary upload error: $e",
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("Image upload failed: $e"),
          ),
        );
      }

      return _currentPhotoUrl;
    }
  }

  // ============================================================
  // SAVE PROFILE
  // ============================================================

  Future<void> _saveProfile() async {
    if (_saving) return;

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final name =
        nameController.text.trim();

    final bio =
        bioController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("Please enter your name"),
        ),
      );
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      // --------------------------------------------------------
      // UPLOAD NEW PHOTO IF SELECTED
      // --------------------------------------------------------

      final photoUrl =
          await _uploadProfileImage();

      // --------------------------------------------------------
      // UPDATE FIREBASE AUTH
      // --------------------------------------------------------

      await user.updateDisplayName(name);

      if (photoUrl != null &&
          photoUrl.isNotEmpty) {
        await user.updatePhotoURL(photoUrl);
      }

      // --------------------------------------------------------
      // UPDATE FIRESTORE USER DOCUMENT
      // --------------------------------------------------------

      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .set(
        {
          "uid": user.uid,
          "name": name,
          "bio": bio,
          "photoUrl":
              photoUrl ?? "",
          "theme": selectedTheme,
          "creatorMode": creatorMode,
          "verifiedRequest": verifiedRequest,
          "updatedAt":
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // --------------------------------------------------------
      // REFRESH FIREBASE AUTH USER
      // --------------------------------------------------------

      await user.reload();

      // --------------------------------------------------------
      // UPDATE EXISTING CHAT ROOMS
      // --------------------------------------------------------

      await ChatService()
          .syncProfileChanges(
        name: name,
        photoUrl: photoUrl ?? "",
      );

      if (!mounted) return;

      setState(() {
        _currentPhotoUrl =
            photoUrl;
        _profileImage = null;
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "ChattªX Identity Updated",
          ),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint(
        "Save profile error: $e",
      );

      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("Profile update failed: $e"),
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: background,
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00D9FF),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: background,

      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,

        title: const Text(
          "Edit ChattªX Identity",
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
        padding:
            const EdgeInsets.all(20),

        child: Column(
          children: [
            _avatarEditor(),

            const SizedBox(height: 25),

            _inputBox(
              "Display Name",
              nameController,
              Icons.person,
            ),

            _inputBox(
              "Bio",
              bioController,
              Icons.description,
            ),

            _themeSelector(),

            const SizedBox(height: 15),

            _switchCard(
              Icons.person,
              "Creator Mode",
              "Unlock advanced creator tools",
              creatorMode,
              (value) {
                setState(() {
                  creatorMode = value;
                });
              },
            ),

            _switchCard(
              Icons.verified,
              "Verification Request",
              "Request official ChattªX verification",
              verifiedRequest,
              (value) {
                setState(() {
                  verifiedRequest = value;
                });
              },
            ),

            const SizedBox(height: 20),

            _saveButton(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // AVATAR
  // ============================================================

  Widget _avatarEditor() {
    ImageProvider? image;

    if (_profileImage != null) {
      image = FileImage(_profileImage!);
    } else if (_currentPhotoUrl != null &&
        _currentPhotoUrl!.isNotEmpty) {
      image = NetworkImage(_currentPhotoUrl!);
    }

    return Container(
      padding:
          const EdgeInsets.all(25),

      decoration:
          BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(30),
      ),

      child: Column(
        children: [
          Stack(
            children: [
              Container(
                padding:
                    const EdgeInsets.all(5),

                decoration:
                    BoxDecoration(
                  shape:
                      BoxShape.circle,

                  border:
                      Border.all(
                    color: cyan,
                    width: 3,
                  ),
                ),

                child: CircleAvatar(
                  radius: 55,

                  backgroundColor:
                      const Color(
                    0xFF111827,
                  ),

                  backgroundImage:
                      image,

                  child: image == null
                      ? const Icon(
                          Icons.person,
                          size: 60,
                          color:
                              Colors.white,
                        )
                      : null,
                ),
              ),

              Positioned(
                bottom: 0,
                right: 0,

                child: GestureDetector(
                  onTap: _pickImage,

                  child: Container(
                    padding:
                        const EdgeInsets.all(8),

                    decoration:
                        BoxDecoration(
                      color: cyan,
                      shape:
                          BoxShape.circle,
                    ),

                    child: const Icon(
                      Icons.edit,
                      color:
                          Colors.black,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          const Text(
            "Customize Avatar",
            style: TextStyle(
              color: Colors.white,
              fontWeight:
                  FontWeight.bold,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INPUT
  // ============================================================

  Widget _inputBox(
    String hint,
    TextEditingController controller,
    IconData icon,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 15,
      ),

      child: TextField(
        controller: controller,

        style:
            const TextStyle(
          color: Colors.white,
        ),

        decoration:
            InputDecoration(
          prefixIcon:
              Icon(
            icon,
            color: cyan,
          ),

          hintText: hint,

          hintStyle:
              const TextStyle(
            color: Colors.white54,
          ),

          filled: true,

          fillColor: card,

          border:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(20),
            borderSide:
                BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // THEME
  // ============================================================

  Widget _themeSelector() {
    return Container(
      padding:
          const EdgeInsets.all(20),

      decoration:
          BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(22),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          const Text(
            "Profile Theme",
            style: TextStyle(
              color: Colors.white,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          DropdownButton<String>(
            value: selectedTheme,

            dropdownColor: card,

            items: [
              "Cyber Blue",
              "Neon Purple",
              "Dark Quantum",
              "Future Glass",
            ]
                .map(
                  (e) =>
                      DropdownMenuItem(
                    value: e,
                    child: Text(
                      e,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                      ),
                    ),
                  ),
                )
                .toList(),

            onChanged: (value) {
              if (value == null) return;

              setState(() {
                selectedTheme = value;
              });
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SWITCH
  // ============================================================

  Widget _switchCard(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    Function(bool) changed,
  ) {
    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),

      decoration:
          BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(20),
      ),

      child: SwitchListTile(
        activeThumbColor: cyan,

        value: value,

        onChanged: changed,

        secondary:
            Icon(
          icon,
          color: cyan,
        ),

        title: Text(
          title,
          style:
              const TextStyle(
            color: Colors.white,
            fontWeight:
                FontWeight.bold,
          ),
        ),

        subtitle: Text(
          subtitle,
          style:
              const TextStyle(
            color: Colors.white54,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SAVE BUTTON
  // ============================================================

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,

      child: ElevatedButton(
        style:
            ElevatedButton.styleFrom(
          backgroundColor: cyan,

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(30),
          ),
        ),

        onPressed:
            _saving
                ? null
                : _saveProfile,

        child: _saving
            ? const SizedBox(
                width: 24,
                height: 24,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.black,
                ),
              )
            : const Text(
                "Save ChattªX Identity",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    nameController.dispose();
    bioController.dispose();
    super.dispose();
  }
}