import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String otherUserName;
  final String otherUserId;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.otherUserName,
    required this.otherUserId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  var messageController = TextEditingController();
  var currentUser = FirebaseAuth.instance.currentUser;
  var scrollController = ScrollController();

  bool isSending = false;

  @override
  void initState() {
    super.initState();
    markMessagesAsRead();
  }

  void markMessagesAsRead() {
    FirebaseFirestore.instance
        .collection("tbl_messages")
        .doc(widget.conversationId)
        .update({
      "unreadCount": 0,
    });
  }

  void scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 200), () {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> sendMessage() async {
    var text = messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      isSending = true;
    });

    messageController.clear();

    try {
      await FirebaseFirestore.instance
          .collection("tbl_messages")
          .doc(widget.conversationId)
          .collection("chats")
          .add({
        "message": text,
        "senderUid": currentUser!.uid,
        "senderName": currentUser!.displayName ?? "User",
        "isRead": false,
        "createdAt": FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection("tbl_messages")
          .doc(widget.conversationId)
          .update({
        "lastMessage": text,
        "lastMessageAt": FieldValue.serverTimestamp(),
        "unreadCount": FieldValue.increment(1),
      });

      scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }

    setState(() {
      isSending = false;
    });
  }

  Widget buildMessage(DocumentSnapshot msg) {
    bool isMe = msg['senderUid'] == currentUser!.uid;
    var text = msg['message'] ?? "";
    var date = msg['createdAt']?.toDate();
    var timeStr = date != null
        ? "${date.hour}:${date.minute.toString().padLeft(2, '0')}"
        : "";
    bool isRead = msg['isRead'] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFF5865F2),
              child: Icon(Icons.person, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 6),
          ],
          Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.65,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? const Color(0xFF5865F2) : const Color(0xFF2B2D31),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                    bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                  ),
                ),
                child: Text(
                  text,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(height: 3),
              Row(
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(color: Colors.grey[600], fontSize: 10),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 4),
                    Icon(
                      isRead ? Icons.done_all : Icons.done,
                      size: 12,
                      color: isRead ? const Color(0xFF5865F2) : Colors.grey[600],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1F22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2B2D31),
        title: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF5865F2),
              child: Icon(Icons.person, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.otherUserName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  "Online",
                  style: TextStyle(color: Colors.green[400], fontSize: 11),
                ),
              ],
            ),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("tbl_messages")
                  .doc(widget.conversationId)
                  .collection("chats")
                  .orderBy("createdAt", descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF5865F2)),
                  );
                }

                var messages = snapshot.data!.docs;

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, color: Colors.grey[600], size: 48),
                        const SizedBox(height: 12),
                        Text(
                          "No messages yet",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Say hi to ${widget.otherUserName}! 👋",
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) => scrollToBottom());

                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return buildMessage(messages[index]);
                  },
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: const Color(0xFF2B2D31),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: messageController,
                    style: const TextStyle(color: Colors.white),
                    onSubmitted: (_) => sendMessage(),
                    decoration: InputDecoration(
                      hintText: "Message ${widget.otherUserName}...",
                      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF1E1F22),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.emoji_emotions_outlined, color: Colors.grey[500]),
                        onPressed: () {},
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: isSending ? null : sendMessage,
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: const Color(0xFF5865F2),
                    child: isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
