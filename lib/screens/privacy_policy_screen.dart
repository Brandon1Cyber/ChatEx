import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const Color background = Color(0xFF050816);
  static const Color card = Color(0xFF0D1528);
  static const Color cyan = Color(0xFF00D9FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: cyan,
        ),
        title: const Text(
          "Privacy Policy",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: card,
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: cyan.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Icon(
                  Icons.privacy_tip_rounded,
                  color: cyan,
                  size: 70,
                ),
              ),

              SizedBox(height: 20),

              Center(
                child: Text(
                  "CHATTªX PRIVACY POLICY",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cyan,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              SizedBox(height: 8),

              Center(
                child: Text(
                  "Last Updated: July 2026",
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ),

              SizedBox(height: 30),

              Text(
                "Welcome to ChattªX",
                style: TextStyle(
                  color: cyan,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 12),

              Text(
                "Welcome to ChattªX, a modern messaging platform built to connect people securely and efficiently. We respect your privacy and are committed to protecting your personal information.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.7,
                ),
              ),

              SizedBox(height: 18),

              Text(
                "This Privacy Policy explains what information we collect, how we use it, how we protect it, and the choices available to you while using ChattªX.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.7,
                ),
              ),

              SizedBox(height: 18),

              Text(
                "By creating a ChattªX account or continuing to use our services, you acknowledge that you have read and understood this Privacy Policy and agree to its terms.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.7,
                ),
              ),

              SizedBox(height: 35),

              Text(
                "1. Information We Collect",
                style: TextStyle(
                  color: cyan,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 15),

              Text(
                "To provide our services, ChattªX may collect the following information:",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.7,
                ),
              ),

              SizedBox(height: 15),

              Text(
                "• Full Name\n"
                "• Email Address\n"
                "• Phone Number\n"
                "• Username\n"
                "• Profile Picture\n"
                "• Device Information\n"
                "• IP Address\n"
                "• Language & Region\n"
                "• Contacts (only with your permission)\n"
                "• App Usage Statistics\n"
                "• Crash Reports",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.8,
                ),
              ),
              SizedBox(height: 35),

              Text(
                "2. Your Messages",
                style: TextStyle(
                  color: cyan,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 15),

              Text(
                "Your conversations are important to us. ChattªX is designed with privacy and security in mind. Where supported, your messages are encrypted during transmission to help protect them from unauthorized access.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.7,
                ),
              ),

              SizedBox(height: 15),

              Text(
                "We do not access the contents of your private conversations unless required by applicable law or when necessary to investigate abuse, fraud, or threats to the safety and security of our platform.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.7,
                ),
              ),

              SizedBox(height: 35),

              Text(
                "3. How We Use Your Information",
                style: TextStyle(
                  color: cyan,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 15),

              Text(
                "Your information helps us provide and improve ChattªX. We may use it to:",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.7,
                ),
              ),

              SizedBox(height: 15),

              Text(
                "• Create and manage your account\n"
                "• Deliver messages and notifications\n"
                "• Synchronize your contacts (with permission)\n"
                "• Improve app performance\n"
                "• Develop new features\n"
                "• Detect spam and fake accounts\n"
                "• Prevent fraud and abuse\n"
                "• Provide customer support\n"
                "• Improve security across the platform",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.8,
                ),
              ),

              SizedBox(height: 35),

              Text(
                "4. Information Sharing",
                style: TextStyle(
                  color: cyan,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 15),

              Text(
                "ChattªX does not sell your personal information to third parties. We may share limited information only when necessary to operate the service, comply with legal obligations, protect users, or work with trusted service providers that help us deliver the platform.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.7,
                ),
              ),

              SizedBox(height: 35),

              Text(
                "5. Your Privacy Controls",
                style: TextStyle(
                  color: cyan,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 15),

              Text(
                "You control many aspects of your privacy within ChattªX, including:",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.7,
                ),
              ),

              SizedBox(height: 15),

              Text(
                "• Profile photo visibility\n"
                "• Online status\n"
                "• Last seen visibility\n"
                "• Read receipts\n"
                "• Typing indicators\n"
                "• Blocking unwanted users\n"
                "• Reporting abusive accounts\n"
                "• Managing who can contact you",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.8,
                ),
              ),
              SizedBox(height: 35),

              Text(
                "6. AI Safety & Security",
                style: TextStyle(
                  color: cyan,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 15),

              Text(
                "ChattªX may use artificial intelligence to help keep our community safe. AI systems may detect spam, scams, fake accounts, malicious links, impersonation attempts and other harmful activity. These systems are designed to improve platform safety and do not replace human review where appropriate.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.7,
                ),
              ),

              SizedBox(height: 35),

              Text(
                "7. Security",
                style: TextStyle(
                  color: cyan,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 15),

              Text(
                "We use industry-standard security measures to help protect your information, including secure connections, account authentication, fraud detection and continuous monitoring of our systems. While we work hard to protect your information, no online service can guarantee absolute security.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.7,
                ),
              ),

              SizedBox(height: 35),

              Text(
                "8. Children's Privacy",
                style: TextStyle(
                  color: cyan,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 15),

              Text(
                "ChattªX is intended for users who meet the minimum age required by the laws of their country. If we discover that an account was created in violation of applicable age requirements, we may suspend or remove that account.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.7,
                ),
              ),

              SizedBox(height: 35),

              Text(
                "9. Third-Party Services",
                style: TextStyle(
                  color: cyan,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 15),

              Text(
                "ChattªX may rely on trusted third-party service providers to operate certain features of the platform, such as cloud hosting, notifications, analytics, authentication and payment processing. These providers are expected to handle information in accordance with their own privacy policies and applicable laws.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.7,
                ),
              ),

              SizedBox(height: 35),

              Text(
                "10. Account Deletion",
                style: TextStyle(
                  color: cyan,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 15),

              Text(
                "You may delete your ChattªX account at any time through the app when this feature is available. Deleting your account may permanently remove your profile, messages stored by ChattªX, media, settings and other associated information, subject to legal obligations and backup retention periods.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.7,
                ),
              ),

              SizedBox(height: 35),

              Text(
                "11. Changes to this Privacy Policy",
                style: TextStyle(
                  color: cyan,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 15),

              Text(
                "We may update this Privacy Policy from time to time to reflect improvements to ChattªX, changes in our services or changes in applicable laws. If we make significant changes, we will notify you through the app or by other appropriate means.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.7,
                ),
              ),

              SizedBox(height: 35),

              Text(
                "12. Contact Us",
                style: TextStyle(
                  color: cyan,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              SizedBox(height: 15),

              Text(
                "If you have questions, concerns or requests regarding this Privacy Policy or your personal information, please contact the ChattªX Support Team through the official support channels available within the app.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.7,
                ),
              ),

              SizedBox(height: 40),

              Divider(
                color: Colors.white24,
              ),

              SizedBox(height: 20),

              Center(
                child: Text(
                  "Thank you for choosing ChattªX.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cyan,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              SizedBox(height: 12),

              Center(
                child: Text(
                  "Your privacy, your conversations and your trust are important to us.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
              ),

              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
