import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'profile.dart';

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
  bool isBlockedByMe = false;
  bool isBlockedByOther = false;
  StreamSubscription<QuerySnapshot>? blockByMeSub;
  StreamSubscription<QuerySnapshot>? blockByOtherSub;
  XFile? selectedMessageImage;
  Uint8List? selectedMessageImageBytes;

  void openProfile(String userId) {
    if (userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(userId: userId),
      ),
    );
  }

  Widget buildUserAvatar(String userId, {double radius = 16}) {
    if (userId.isEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: const Color(0xFF5865F2),
        child: Icon(Icons.person, color: Colors.white, size: radius),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("tbl_users")
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        var imageUrl = "";
        if (snapshot.hasData && snapshot.data != null) {
          var data = snapshot.data!.data() as Map<String, dynamic>?;
          imageUrl = data?['profilepic'] ?? "";
        }

        return CircleAvatar(
          radius: radius,
          backgroundColor: const Color(0xFF5865F2),
          backgroundImage: imageUrl.toString().isNotEmpty ? NetworkImage(imageUrl) : null,
          child: imageUrl.toString().isNotEmpty
              ? null
              : Icon(Icons.person, color: Colors.white, size: radius),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    markMessagesAsRead();
    listenForBlockStatus();
  }

  @override
  void dispose() {
    blockByMeSub?.cancel();
    blockByOtherSub?.cancel();
    messageController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  void listenForBlockStatus() {
    var myId = currentUser?.uid;
    if (myId == null) return;

    blockByMeSub = FirebaseFirestore.instance
        .collection("tbl_blocks")
        .where("blockerUid", isEqualTo: myId)
        .where("blockedUid", isEqualTo: widget.otherUserId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        isBlockedByMe = snapshot.docs.isNotEmpty;
      });
    });

    blockByOtherSub = FirebaseFirestore.instance
        .collection("tbl_blocks")
        .where("blockerUid", isEqualTo: widget.otherUserId)
        .where("blockedUid", isEqualTo: myId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        isBlockedByOther = snapshot.docs.isNotEmpty;
      });
    });
  }

  Future<void> unblockUser() async {
    var myId = currentUser?.uid;
    if (myId == null) return;

    try {
      var snapshot = await FirebaseFirestore.instance
          .collection("tbl_blocks")
          .where("blockerUid", isEqualTo: myId)
          .where("blockedUid", isEqualTo: widget.otherUserId)
          .get();
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User unblocked")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  String formatTime(DateTime? date) {
    if (date == null) return "";
    var hour = date.hour;
    var minute = date.minute.toString().padLeft(2, '0');
    var period = hour >= 12 ? "PM" : "AM";
    var hour12 = hour % 12;
    if (hour12 == 0) hour12 = 12;
    return "$hour12:$minute $period";
  }

  Future<void> pickMessageImage() async {
    var file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (file == null) return;

    var bytes = await file.readAsBytes();
    setState(() {
      selectedMessageImage = file;
      selectedMessageImageBytes = bytes;
    });
  }

  void clearMessageImage() {
    setState(() {
      selectedMessageImage = null;
      selectedMessageImageBytes = null;
    });
  }

  Future<String?> uploadMessageImage() async {
    if (selectedMessageImage == null || selectedMessageImageBytes == null) return null;

    var fileName = selectedMessageImage!.name;
    var storageRef = FirebaseStorage.instance
        .ref()
        .child("message_images")
        .child("${currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}_$fileName");

    await storageRef.putData(selectedMessageImageBytes!);
    return storageRef.getDownloadURL();
  }

  Future<void> markMessagesAsRead() async {
    var convoRef = FirebaseFirestore.instance
        .collection("tbl_messages")
        .doc(widget.conversationId);

    await convoRef.update({
      "unreadCount": 0,
      "unreadCounts.${currentUser!.uid}": 0,
    });

    var unreadSnap = await convoRef
        .collection("chats")
        .where("isRead", isEqualTo: false)
        .get();

    var batch = FirebaseFirestore.instance.batch();
    var hasUpdates = false;
    for (var doc in unreadSnap.docs) {
      if (doc['senderUid'] != currentUser!.uid) {
        batch.update(doc.reference, {"isRead": true});
        hasUpdates = true;
      }
    }
    if (hasUpdates) {
      await batch.commit();
    }
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
    if (isBlockedByMe || isBlockedByOther) return;
    var text = messageController.text.trim();
    if (text.isEmpty && selectedMessageImageBytes == null) return;

    setState(() {
      isSending = true;
    });

    messageController.clear();

    try {
      var imageUrl = await uploadMessageImage();

      await FirebaseFirestore.instance
          .collection("tbl_messages")
          .doc(widget.conversationId)
          .collection("chats")
          .add({
        "message": text,
        if (imageUrl != null && imageUrl.isNotEmpty) "imageUrl": imageUrl,
        "senderUid": currentUser!.uid,
        "senderName": currentUser!.displayName ?? "User",
        "isRead": false,
        "createdAt": FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance
          .collection("tbl_messages")
          .doc(widget.conversationId)
          .update({
        "lastMessage": text.isNotEmpty ? text : "Photo",
        "lastMessageAt": FieldValue.serverTimestamp(),
        "lastSenderId": currentUser!.uid,
        "unreadCounts.${widget.otherUserId}": FieldValue.increment(1),
        "unreadCounts.${currentUser!.uid}": 0,
        "unreadCount": FieldValue.increment(1),
      });

      clearMessageImage();
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
    var msgData = msg.data() as Map<String, dynamic>;
    bool isMe = msg['senderUid'] == currentUser!.uid;
    var text = msg['message'] ?? "";
    var imageUrl = msgData['imageUrl'] ?? "";
    var date = msg['createdAt']?.toDate();
    var timeStr = formatTime(date);
    bool isRead = msg['isRead'] ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            GestureDetector(
              onTap: () => openProfile(widget.otherUserId),
              child: buildUserAvatar(widget.otherUserId, radius: 14),
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
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    if (imageUrl.toString().isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          imageUrl,
                          height: 180,
                          width: 180,
                          fit: BoxFit.cover,
                        ),
                      ),
                    if (imageUrl.toString().isNotEmpty && text.toString().isNotEmpty)
                      const SizedBox(height: 8),
                    if (text.toString().isNotEmpty)
                      Text(
                        text,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                      ),
                  ],
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
    var isBlocked = isBlockedByMe || isBlockedByOther;
    return Scaffold(
      backgroundColor: const Color(0xFF1E1F22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2B2D31),
        title: Row(
          children: [
            GestureDetector(
              onTap: () => openProfile(widget.otherUserId),
              child: buildUserAvatar(widget.otherUserId, radius: 16),
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
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF5865F2)),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Failed to load messages",
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data == null) {
                  return const SizedBox.shrink();
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

                var hasUnread = messages.any((msg) {
                  var isRead = msg['isRead'] ?? false;
                  return !isRead && msg['senderUid'] != currentUser!.uid;
                });

                if (hasUnread) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    markMessagesAsRead();
                  });
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

          if (isBlocked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              color: const Color(0xFF2B2D31),
              child: Row(
                children: [
                  Icon(Icons.block, color: Colors.red[300], size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isBlockedByMe
                          ? "You blocked this user. Unblock to send messages."
                          : "You cannot message this user because you were blocked.",
                      style: TextStyle(color: Colors.grey[300], fontSize: 13),
                    ),
                  ),
                  if (isBlockedByMe)
                    TextButton(
                      onPressed: unblockUser,
                      child: const Text(
                        "Unblock",
                        style: TextStyle(color: Color(0xFF5865F2)),
                      ),
                    ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              color: const Color(0xFF2B2D31),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selectedMessageImageBytes != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              selectedMessageImageBytes!,
                              height: 90,
                              width: 90,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 10),
                          TextButton(
                            onPressed: clearMessageImage,
                            child: const Text(
                              "Remove",
                              style: TextStyle(color: Color(0xFF5865F2)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: pickMessageImage,
                        icon: Icon(Icons.photo, color: Colors.grey[500]),
                      ),
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
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.send, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
