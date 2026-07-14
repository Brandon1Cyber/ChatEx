import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'create_account_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/login_background.jpeg"),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  const SizedBox(height: 20),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [
                            Colors.white,
                            Color(0xFF6EE7FF),
                            Color(0xFFB026FF),
                          ],
                        ).createShader(bounds),
                        child: const Text(
                          "Welcome Back",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.5,
                            height: 1.1,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Container(
                        width: 220,
                        height: 2,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Colors.transparent,
                              Color(0xFF00E5FF),
                              Color(0xFFB026FF),
                              Colors.transparent,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),

                      const SizedBox(height: 15),

                      const Text(
                        "Think Bigger - Chat Smarter",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 17,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.8,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 45),

                  Container(
  decoration: BoxDecoration(
    color: Colors.white.withValues(alpha: 0.08),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: const Color(0xFF00D9FF).withValues(alpha: 0.35),
      width: 1.2,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF00D9FF).withValues(alpha: 0.08),
        blurRadius: 15,
      ),
    ],
  ),
  child: const TextField(
    style: TextStyle(color: Colors.white),
    decoration: InputDecoration(
      hintText: "Email",
      hintStyle: TextStyle(color: Colors.white54),
      prefixIcon: Icon(
        Icons.email_outlined,
        color: Color(0xFF00D9FF),
      ),
      border: InputBorder.none,
      contentPadding: EdgeInsets.symmetric(vertical: 18),
    ),
  ),
),

                  const SizedBox(height: 20),

                  Container(
  decoration: BoxDecoration(
    color: Colors.white.withValues(alpha: 0.08),
    borderRadius: BorderRadius.circular(18),
    border: Border.all(
      color: const Color(0xFF00D9FF).withValues(alpha: 0.35),
      width: 1.2,
    ),
    boxShadow: [
      BoxShadow(
        color: const Color(0xFF00D9FF).withValues(alpha: 0.08),
        blurRadius: 15,
      ),
    ],
  ),
  child: TextField(
    obscureText: _obscurePassword,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(
      hintText: "Password",
      hintStyle: const TextStyle(color: Colors.white54),
      prefixIcon: const Icon(
        Icons.lock_outline,
        color: Color(0xFF00D9FF),
      ),
      suffixIcon: IconButton(
        icon: Icon(
          _obscurePassword
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: Colors.white70,
        ),
        onPressed: () {
          setState(() {
            _obscurePassword = !_obscurePassword;
          });
        },
      ),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(vertical: 18),
    ),
  ),
),

                  const SizedBox(height: 30),

                  TweenAnimationBuilder<double>(
  tween: Tween(begin: 0.98, end: 1.02),
  duration: const Duration(seconds: 2),
  curve: Curves.easeInOut,
  builder: (context, value, child) {
    return Transform.scale(
      scale: value,
      child: child,
    );
  },
  child: SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const HomeScreen(),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D9FF),
                        foregroundColor: Colors.white,
                        elevation: 8,
shadowColor: const Color(0xFF00D9FF).withValues(alpha: 0.25),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: const Text(
                        "LOGIN",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                  ),

                  const SizedBox(height: 20),

                  TextButton(
  onPressed: () {},
  child: const Text(
    "Forgot Password?",
    style: TextStyle(
      color: Color(0xFF00D9FF),
    ),
  ),
),

const SizedBox(height: 20),

OutlinedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateAccountScreen(),
      ),
    );
  },
  style: OutlinedButton.styleFrom(
    side: const BorderSide(
      color: Color(0xFF00D9FF),
      width: 2,
    ),
    foregroundColor: Colors.white,
    minimumSize: const Size(double.infinity, 58),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(30),
    ),
  ),
  child: const Text(
    "CREATE ACCOUNT",
    style: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      letterSpacing: 2,
    ),
  ),
),

],
              ),
            ),
          ),
        ),
      ),
    );
  }
}