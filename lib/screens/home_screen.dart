import 'package:flutter/material.dart';
import 'login_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
  width: double.infinity,
  height: double.infinity,
  decoration: const BoxDecoration(
    image: DecorationImage(
      image: AssetImage('assets/login_background.jpeg'),
      fit: BoxFit.cover,
    ),
  ),
  child: Center(
    child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TweenAnimationBuilder<double>(
  tween: Tween(begin: 0.95, end: 1.05),
  duration: const Duration(seconds: 2),
  curve: Curves.easeInOut,
  builder: (context, value, child) {
    return Transform.scale(
      scale: value,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.cyanAccent.withValues(alpha:0.4),
              blurRadius: 35,
              spreadRadius: 8,
            ),
          ],
        ),
        child: Image.asset(
          'assets/chatex_logo.png',
          width: 170,
        ),
      ),
    );
  },
),
            const SizedBox(height: 20),
            const Text(
              "ChatEx",
              style: TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Messaging Beyond Tomorrow",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 50),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(),
                  ),
                );
              },
              child: const Text("Get Started"),
            ),
          ],
        ),
      ),
      ),
    );
  }
}