import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050816),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Terms of Service",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: SelectableText(
          '''
ChatEx Terms of Service

Effective Date: July 15, 2026

Welcome to ChatEx. These Terms of Service ("Terms") govern your access to and use of the ChatEx application, website, and related services ("Service"). By creating an account or using ChatEx, you agree to these Terms.

1. Eligibility

You must be at least 13 years old, or the minimum legal age required in your country, to use ChatEx. If you are under the age of majority, you must have permission from a parent or legal guardian.

2. Your Account

• You are responsible for keeping your account and password secure.

• You must provide accurate information when creating an account.

• You are responsible for all activity that occurs under your account.

3. Acceptable Use

You agree not to:

• Harass, threaten, or abuse others.

• Share illegal, harmful, or fraudulent content.

• Upload viruses or malicious software.

• Attempt to hack, disrupt, or interfere with ChatEx or other users.

• Impersonate another person or organization.

• Violate any applicable laws or regulations.

4. User Content

You retain ownership of the content you create and share on ChatEx.

By using the Service, you grant ChatEx a limited license to store, process, and transmit your content solely for the purpose of operating and improving the Service.

You are responsible for ensuring that the content you post does not infringe on the rights of others.

5. Privacy

Your use of ChatEx is also governed by the ChatEx Privacy Policy, which explains how we collect, use, and protect your information.

6. AI Features

Some ChatEx features may use artificial intelligence to assist with conversations, recommendations, translations, or other functions.

AI-generated responses may occasionally be inaccurate or incomplete and should not be relied upon as professional advice.

7. Safety

We work to provide a safe environment for everyone. We may investigate reports of abuse and remove content or suspend accounts that violate these Terms.

8. Community Guidelines

Users must not:

• Post hate speech or discrimination.

• Share terrorist or extremist content.

• Share child exploitation material.

• Promote violence or criminal activity.

• Scam, spam, or impersonate others.

Violation of these rules may result in temporary or permanent account suspension.

9. Intellectual Property

The ChatEx name, logo, design, software, and other intellectual property belong to ChatEx or its licensors and are protected by applicable laws.

You may not copy, modify, distribute, reverse engineer, or sell any part of the Service without permission.

10. Service Availability

We strive to keep ChatEx available at all times but cannot guarantee uninterrupted or error-free service.

Features may change, be updated, or be discontinued without notice.

11. Account Suspension or Termination

We may suspend or terminate your account if you violate these Terms, engage in illegal activity, or use the Service in a way that harms others or ChatEx.

You may stop using ChatEx and delete your account at any time.

12. Disclaimer

ChatEx is provided "as is" and "as available" without warranties of any kind, whether express or implied, except where required by law.

13. Limitation of Liability

To the fullest extent permitted by law, ChatEx and its owners shall not be liable for indirect, incidental, special, consequential, or punitive damages arising from your use of the Service.

14. Changes to These Terms

We may update these Terms from time to time. When we do, we will update the Effective Date. Continued use of ChatEx after changes become effective means you accept the updated Terms.

15. Governing Law

These Terms are governed by the laws of the Republic of South Africa, unless applicable law requires otherwise.

16. Reporting Violations

Users may report messages, accounts, or content that violate these Terms. ChatEx may investigate reports and take appropriate action.

17. Contact Us

If you have any questions about these Terms of Service, please contact the ChatEx support team through the contact information provided within the app or on the official ChatEx website.

----------------------------------------------------

By creating an account or using ChatEx, you acknowledge that you have read, understood, and agreed to these Terms of Service.
''',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            height: 1.8,
          ),
        ),
      ),
    );
  }
}