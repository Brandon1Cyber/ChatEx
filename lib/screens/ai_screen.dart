import 'package:flutter/material.dart';
import '../services/ai_service.dart';

class AIScreen extends StatefulWidget {
  const AIScreen({super.key});

  @override
  State<AIScreen> createState() => _AIScreenState();
}

class _AIScreenState extends State<AIScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final AIService _aiService = AIService();

bool _isLoading = false;

  final List<Map<String, dynamic>> messages = [
    {
      "isUser": false,
      "text":
          "👋 Hi! I'm ChatEx AI.\n\nI can answer questions, help you write, translate, summarize and much more.\n\nHow can I help you today?"
    }
  ];

 Future<void> _sendMessage() async {
  if (_controller.text.trim().isEmpty) return;

  final userMessage = _controller.text.trim();

  setState(() {
    messages.add({
      "isUser": true,
      "text": userMessage,
    });

    _isLoading = true;
  });

  _controller.clear();

  _scrollController.animateTo(
    _scrollController.position.maxScrollExtent + 300,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOut,
  );

  final aiReply = await _aiService.sendMessage(userMessage);

  setState(() {
    messages.add({
      "isUser": false,
      "text": aiReply,
    });

    _isLoading = false;
  });

  Future.delayed(const Duration(milliseconds: 100), () {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 300,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050816),

      appBar: AppBar(
        backgroundColor: const Color(0xFF050816),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "ChatEx AI",
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "Always ready",
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),

      body: Column(
        children: [

          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: messages.length,
              itemBuilder: (context, index) {

                final msg = messages[index];
                final me = msg["isUser"];

                return Align(
                  alignment: me
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    constraints: BoxConstraints(
                      maxWidth:
                          MediaQuery.of(context).size.width * .75,
                    ),
                    decoration: BoxDecoration(
                      gradient: me
                          ? const LinearGradient(
                              colors: [
                                Color(0xFF7B2FF7),
                                Color(0xFFC026FF),
                              ],
                            )
                          : const LinearGradient(
                              colors: [
                                Color(0xFF121A2F),
                                Color(0xFF1B2340),
                              ],
                            ),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Text(
                      msg["text"],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          if (_isLoading)
  const Padding(
    padding: EdgeInsets.only(left: 16, bottom: 8),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF00D9FF),
            ),
          ),
          SizedBox(width: 10),
          Text(
            "ChatEx AI is typing...",
            style: TextStyle(
              color: Color(0xFF00D9FF),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    ),
  ),

          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF111827),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [

                  const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFF00D9FF),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: "Ask ChatEx AI...",
                        hintStyle: TextStyle(
                          color: Colors.white54,
                        ),
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed: _sendMessage,
                    icon: const Icon(
                      Icons.send_rounded,
                      color: Color(0xFF00D9FF),
                    ),
                  ),

                ],
              ),
            ),
          ),

        ],
      ),
    );
  }
}