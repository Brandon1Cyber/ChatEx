import 'dart:math';
import 'package:flutter/material.dart';

class TreasureVaultScreen extends StatefulWidget {
  const TreasureVaultScreen({super.key});

  @override
  State<TreasureVaultScreen> createState() =>
      _TreasureVaultScreenState();
}

class _TreasureVaultScreenState
    extends State<TreasureVaultScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  bool opened = false;
bool jackpot = false;
String reward = "";

int chatCoins = 1250;
int vaultKeys = 3;
int vaultLevel = 1;

  final List<String> rewards = [
    "🪙 50 ChatCoins",
    "🪙 100 ChatCoins",
    "🪙 250 ChatCoins",
    "🪙 500 ChatCoins",
    "🪙 1,000 ChatCoins",
    "🤖 100 AI Credits",
    "👑 Premium for 1 Day",
    "🎨 Rare Profile Frame",
  ];

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> openVault() async {
  if (opened) return;

  await _controller.forward();
  await _controller.reverse();

  if (Random().nextInt(100) < 5) {
  jackpot = true;
  reward = "💎 JACKPOT! 10,000 ChatCoins";
} else {
  jackpot = false;
  reward = rewards[Random().nextInt(rewards.length)];
}

  setState(() {
  opened = true;
  vaultKeys--;

  if (vaultKeys <= 0) {
    vaultKeys = 5;
    vaultLevel++;
  }
});
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050816),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Treasure Vault",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 25),
            Container(
  width: double.infinity,
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: const Color(0xFF11162A),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: const Color(0xFF00D9FF),
      width: 1.5,
    ),
  ),
  child: Column(
    children: [
      const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.monetization_on,
            color: Color(0xFFFFD700),
            size: 26,
          ),
          SizedBox(width: 8),
          Text(
            "ChatCoins Balance",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ],
      ),

      const SizedBox(height: 10),

      Text(
        "$chatCoins",
        style: const TextStyle(
          color: Color(0xFF00D9FF),
          fontSize: 34,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  ),
),

const SizedBox(height: 25),

            GestureDetector(
  onTap: openVault,
  child: AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final angle = sin(_controller.value * 25) * 0.08;

      return Transform.rotate(
        angle: angle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  color: opened
                      ? Colors.amber
                      : const Color(0xFF11162A),
                  borderRadius:
                      BorderRadius.circular(35),
                  boxShadow: [
                    BoxShadow(
                      color: opened
                          ? Colors.amber.withValues(alpha: 0.7)
                          : const Color(0x6600D9FF),
                      blurRadius: 35,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    opened
                        ? Icons.lock_open_rounded
                        : Icons.inventory_2_rounded,
                    color: Colors.white,
                    size: 90,
                  ),
                ),
        ),
      );
    },
  ),

            ),
            const SizedBox(height: 30),

            const Text(
              "Tap the Treasure Vault to unlock a surprise reward.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),

            const SizedBox(height: 25),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.key,
                    color: Color(0xFF00D9FF), size: 34),
                SizedBox(width: 8),
                Icon(Icons.key,
                    color: Color(0xFF00D9FF), size: 34),
                SizedBox(width: 8),
                Icon(Icons.key,
                    color: Color(0xFF00D9FF), size: 34),
                SizedBox(width: 8),
                Icon(Icons.key_outlined,
                    color: Colors.white24, size: 34),
                SizedBox(width: 8),
                Icon(Icons.key_outlined,
                    color: Colors.white24, size: 34),
              ],
            ),

            const SizedBox(height: 12),

          Text(
  "$vaultKeys / 5 Vault Keys",
  style: const TextStyle(
    color: Color(0xFF00D9FF),
    fontSize: 20,
    fontWeight: FontWeight.bold,
  ),
),

const SizedBox(height: 8),

Text(
  "Vault Level $vaultLevel",
  style: const TextStyle(
    color: Colors.white70,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  ),
),

            const SizedBox(height: 30),

            if (opened)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF11162A),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF00D9FF),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    Text(
  jackpot ? "💎 JACKPOT WINNER! 💎" : "🎉 Congratulations!",
  style: TextStyle(
    color: jackpot ? Colors.amber : Colors.white,
    fontSize: jackpot ? 30 : 24,
    fontWeight: FontWeight.bold,
    shadows: jackpot
        ? [
            Shadow(
              color: Colors.amber,
              blurRadius: 25,
            ),
          ]
        : [],
  ),
),

                    const SizedBox(height: 18),

                    Text(
  reward,
  textAlign: TextAlign.center,
  style: TextStyle(
    color: jackpot ? Colors.amber : const Color(0xFF00D9FF),
    fontSize: jackpot ? 32 : 26,
    fontWeight: FontWeight.bold,
  ),
),

                    const SizedBox(height: 25),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: () {
  int coins = 0;

  if (reward.contains("50 ChatCoins")) {
    coins = 50;
  } else if (reward.contains("100 ChatCoins")) {
    coins = 100;
  } else if (reward.contains("250 ChatCoins")) {
    coins = 250;
  } else if (reward.contains("500 ChatCoins")) {
    coins = 500;
  } else if (reward.contains("1,000 ChatCoins")) {
    coins = 1000;
  }

  setState(() {
    chatCoins += coins;
    opened = false;
    reward = "";
  });

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: const Color(0xFF11162A),
      content: Text(
        coins > 0
            ? "🎉 You collected $coins ChatCoins!"
            : "🎁 Reward collected!",
      ),
    ),
  );
},
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color(0xFF00D9FF),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          "Collect Reward",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color: Color(0xFF00D9FF),
                    width: 2,
                  ),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "Back",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}