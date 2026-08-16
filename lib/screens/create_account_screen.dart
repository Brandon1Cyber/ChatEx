import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'terms_of_service_screen.dart';
import 'privacy_policy_screen.dart';

class CreateAccountScreen extends StatefulWidget {
  const CreateAccountScreen({super.key});

  @override
  State<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState
    extends State<CreateAccountScreen> {
  bool _hidePassword = true;
  bool _hideConfirmPassword = true;
  bool _agree = false;
  bool _isLoading = false;

  DateTime? _birthday;

  final TextEditingController _nameController =
      TextEditingController();

  final TextEditingController _usernameController =
      TextEditingController();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(
        const Duration(days: 365 * 18),
      ),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _birthday = picked;
      });
    }
  }

  int get _age {
    if (_birthday == null) return 0;

    final today = DateTime.now();

    int age = today.year - _birthday!.year;

    if (today.month < _birthday!.month ||
        (today.month == _birthday!.month &&
            today.day < _birthday!.day)) {
      age--;
    }

    return age;
  }

  Widget buildField({
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    bool obscure = false,
    VoidCallback? toggle,
    TextInputType keyboard =
        TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: ClipRRect(
        borderRadius:
            BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 18,
            sigmaY: 18,
          ),
          child: Container(
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withValues(
                alpha: .08,
              ),
              borderRadius:
                  BorderRadius.circular(22),
              border: Border.all(
                color: const Color(
                  0xFF00D9FF,
                ).withValues(alpha: .35),
              ),
            ),
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboard,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hint,
                hintStyle:
                    const TextStyle(
                  color: Colors.white70,
                ),
                prefixIcon: Icon(
                  icon,
                  color: const Color(
                    0xFF7B2FF7,
                  ),
                ),
                suffixIcon: toggle == null
                    ? null
                    : IconButton(
                        onPressed: toggle,
                        icon: Icon(
                          obscure
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color:
                              Colors.white70,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget birthdayField() {
    return GestureDetector(
      onTap: _pickBirthday,
      child: Container(
        height: 62,
        margin:
            const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(
            alpha: .08,
          ),
          borderRadius:
              BorderRadius.circular(22),
          border: Border.all(
            color: const Color(
              0xFF00D9FF,
            ).withValues(alpha: .35),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 18),

            const Icon(
              Icons.cake_outlined,
              color: Color(0xFF7B2FF7),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Text(
                _birthday == null
                    ? "Birthday"
                    : "${_birthday!.day}/${_birthday!.month}/${_birthday!.year}",
                style: TextStyle(
                  color: _birthday == null
                      ? Colors.white70
                      : Colors.white,
                  fontSize: 16,
                ),
              ),
            ),

            const Padding(
              padding:
                  EdgeInsets.only(right: 18),
              child: Icon(
                Icons.calendar_month,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
  @override
Widget build(BuildContext context) {
  return Scaffold(
    body: Stack(
      children: [

        Positioned.fill(
          child: Image.asset(
            "assets/login_background.jpeg",
            fit: BoxFit.cover,
          ),
        ),

        Container(
          color: Colors.black.withValues(alpha: .60),
        ),

        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 18,
            ),
            child: Column(
              children: [

                Align(
                  alignment: Alignment.centerLeft,
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white12,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                Image.asset(
                  "assets/chatex_logoo.png",
                  height: 120,
                ),

                const SizedBox(height: 15),

                const Text(
                  "Create ChattªX Account",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  "Messaging Beyond Tomorrow",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 28),

                ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 20,
                      sigmaY: 20,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0xFF00D9FF)
                              .withValues(alpha: .35),
                        ),
                      ),
                      child: Column(
                        children: [

                          buildField(
                            hint: "Full Name",
                            icon: Icons.person_outline,
                            controller: _nameController,
                          ),

                          buildField(
                            hint: "Username",
                            icon: Icons.alternate_email,
                            controller: _usernameController,
                          ),

                          birthdayField(),

                          buildField(
                            hint: "Email Address",
                            icon: Icons.email_outlined,
                            controller: _emailController,
                            keyboard: TextInputType.emailAddress,
                          ),

                          buildField(
                            hint: "Password",
                            icon: Icons.lock_outline,
                            controller: _passwordController,
                            obscure: _hidePassword,
                            toggle: () {
                              setState(() {
                                _hidePassword =
                                    !_hidePassword;
                              });
                            },
                          ),

                          buildField(
                            hint: "Confirm Password",
                            icon: Icons.lock_outline,
                            controller:
                                _confirmPasswordController,
                            obscure:
                                _hideConfirmPassword,
                            toggle: () {
                              setState(() {
                                _hideConfirmPassword =
                                    !_hideConfirmPassword;
                              });
                            },
                          ),
                          Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: _agree,
                                activeColor:
                                    const Color(0xFF00D9FF),
                                checkColor: Colors.black,
                                onChanged: (value) {
                                  setState(() {
                                    _agree = value ?? false;
                                  });
                                },
                              ),

                              Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.only(
                                    top: 12,
                                  ),
                                  child: Wrap(
                                    children: [

                                      const Text(
                                        "I agree to the ",
                                        style: TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),

                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const TermsOfServiceScreen(),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          "Terms of Service",
                                          style: TextStyle(
                                            color: Color(0xFF00D9FF),
                                            fontWeight:
                                                FontWeight.bold,
                                            decoration:
                                                TextDecoration
                                                    .underline,
                                          ),
                                        ),
                                      ),

                                      const Text(
                                        " and ",
                                        style: TextStyle(
                                          color: Colors.white70,
                                        ),
                                      ),

                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  PrivacyPolicyScreen(),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          "Privacy Policy",
                                          style: TextStyle(
                                            color: Color(0xFF00D9FF),
                                            fontWeight:
                                                FontWeight.bold,
                                            decoration:
                                                TextDecoration
                                                    .underline,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 25),

                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              onPressed: !_agree || _isLoading
                                  ? null
                                  : () async {

                                      if (_birthday == null) {
                                        ScaffoldMessenger.of(
                                                context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Please select your birthday.",
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      if (_age < 10) {
                                        ScaffoldMessenger.of(
                                                context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "You must be at least 10 years old to create a ChattªX account.",
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      if (_nameController.text
                                          .trim()
                                          .isEmpty) {
                                        ScaffoldMessenger.of(
                                                context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Enter your full name.",
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      if (_usernameController
                                          .text
                                          .trim()
                                          .isEmpty) {
                                        ScaffoldMessenger.of(
                                                context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Choose a username.",
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      if (_emailController.text
                                          .trim()
                                          .isEmpty) {
                                        ScaffoldMessenger.of(
                                                context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Enter your email.",
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      if (_passwordController
                                              .text !=
                                          _confirmPasswordController
                                              .text) {
                                        ScaffoldMessenger.of(
                                                context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              "Passwords do not match.",
                                            ),
                                          ),
                                        );
                                        return;
                                      }

                                      setState(() {
                                        _isLoading = true;
                                      });

                                      try {
                                        final credential =
                                            await FirebaseAuth
                                                .instance
                                                .createUserWithEmailAndPassword(
                                          email:
                                              _emailController.text
                                                  .trim(),
                                          password:
                                              _passwordController
                                                  .text,
                                        );

                                        await FirebaseFirestore
                                            .instance
                                            .collection("users")
                                            .doc(credential
                                                .user!.uid)
                                            .set({
                                          "uid": credential.user!.uid,
                                          "name":
                                              _nameController.text
                                                  .trim(),
                                          "username":
                                              _usernameController
                                                  .text
                                                  .trim(),
                                          "email":
                                              _emailController.text
                                                  .trim(),
                                          "birthday":
                                              Timestamp.fromDate(
                                                  _birthday!),
                                          "age": _age,
                                          "photoUrl": "",
                                          "about":
                                              "Hey! I'm using ChattªX.",
                                          "isOnline": true,
                                          "createdAt":
                                              FieldValue
                                                  .serverTimestamp(),
                                        });

                                        if (!mounted) return;

                                        Navigator.pop(context);

                                      } on FirebaseAuthException catch (e) {

                                        ScaffoldMessenger.of(
                                                context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              e.message ??
                                                  e.code,
                                            ),
                                          ),
                                        );

                                      } finally {

                                        if (mounted) {
                                          setState(() {
                                            _isLoading =
                                                false;
                                          });
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    const Color(0xFF00D9FF),
                                foregroundColor:
                                    Colors.black,
                                disabledBackgroundColor:
                                    Colors.grey.shade700,
                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                          35),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(
                                      color: Colors.white,
                                    )
                                  : const Text(
                                      "CREATE ACCOUNT",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight:
                                            FontWeight.bold,
                                        letterSpacing: 2,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 18),

                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              const Text(
                                "Already have a ChattªX account?",
                                style: TextStyle(
                                  color: Colors.white70,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: const Text(
                                  "Log In",
                                  style: TextStyle(
                                    color: Color(0xFF00D9FF),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
}