import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat.dart';
import 'profile.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  var currentUser = FirebaseAuth.instance.currentUser;
  var searchController = TextEditingController();

  void openProfile(String userId) {
    if (userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(userId: userId),
      ),
    );
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

  String buildDisplayName(Map<String, dynamic> userData) {
    var first = (userData['firstname'] ?? '').toString().trim();
    var last = (userData['lastname'] ?? '').toString().trim();
    var combined = [first, last].where((part) => part.isNotEmpty).join(' ');
    if (combined.isNotEmpty) return combined;
    var legacy = (userData['fullname'] ?? '').toString().trim();
    if (legacy.isNotEmpty) return legacy;
    return "User";
  }

  Stream<QuerySnapshot> getConversations() {
    return FirebaseFirestore.instance
        .collection("tbl_messages")
        .where("participants", arrayContains: currentUser!.uid)
        .snapshots();
  }

  void searchAndOpenChat() async {
    var query = searchController.text.trim();
    if (query.isEmpty) return;

    var result = await FirebaseFirestore.instance
        .collection("tbl_users")
        .where("email", isEqualTo: query)
        .limit(1)
        .get();

    if (result.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not found")),
      );
      return;
    }

    var otherUser = result.docs.first;
    var otherUid = otherUser.id;
    var otherName = buildDisplayName(otherUser.data() as Map<String, dynamic>);

    if (otherUid == currentUser!.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("That's you!")),
      );
      return;
    }

    List<String> ids = [currentUser!.uid, otherUid];
    ids.sort();
    var conversationId = ids.join("_");

    var convoRef = FirebaseFirestore.instance
        .collection("tbl_messages")
        .doc(conversationId);

    var convoDoc = await convoRef.get();
    if (!convoDoc.exists) {
      await convoRef.set({
        "participants": [currentUser!.uid, otherUid],
        "lastMessage": "",
        "lastMessageAt": FieldValue.serverTimestamp(),
        "lastSenderId": "",
        "unreadCount": 0,
        "unreadCounts": {
          currentUser!.uid: 0,
          otherUid: 0,
        },
      });
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatPage(
          conversationId: conversationId,
          otherUserName: otherName,
          otherUserId: otherUid,
        ),
      ),
    );

    searchController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1F22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2B2D31),
        title: const Text(
          "Messages",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          Container(
            color: const Color(0xFF2B2D31),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Search by email to start chat...",
                      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1E1F22),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: searchAndOpenChat,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF5865F2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: getConversations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF5865F2)),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Failed to load conversations",
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  );
                }
                if (!snapshot.hasData || snapshot.data == null) {
                  return const SizedBox.shrink();
                }

                var convos = snapshot.data!.docs;
                convos.sort((a, b) {
                  var aData = a.data() as Map<String, dynamic>;
                  var bData = b.data() as Map<String, dynamic>;
                  var aDate = aData['lastMessageAt']?.toDate();
                  var bDate = bData['lastMessageAt']?.toDate();
                  if (aDate == null && bDate == null) return 0;
                  if (aDate == null) return 1;
                  if (bDate == null) return -1;
                  return bDate.compareTo(aDate);
                });

                if (convos.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.message_outlined, color: Colors.grey[600], size: 52),
                        const SizedBox(height: 12),
                        Text(
                          "No conversations yet",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          "Search for a user by email to start chatting",
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: convos.length,
                  itemBuilder: (context, index) {
                    var convo = convos[index];
                    List participants = convo['participants'];
                    var otherUid = participants.firstWhere(
                      (uid) => uid != currentUser!.uid,
                      orElse: () => "",
                    );

                    if (otherUid.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    var data = convo.data() as Map<String, dynamic>;
                    var lastMessage = data['lastMessage'] ?? "";
                    var lastSenderId = data['lastSenderId'] ?? "";
                    var unreadCounts = data['unreadCounts'] as Map<String, dynamic>?;
                    var unreadCount = unreadCounts != null
                        ? (unreadCounts[currentUser!.uid] ?? 0)
                        : (data['unreadCount'] ?? 0);
                    if (unreadCounts == null && lastSenderId == currentUser!.uid) {
                      unreadCount = 0;
                    }
                    var lastDate = data['lastMessageAt']?.toDate();
                    var timeStr = formatTime(lastDate);

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection("tbl_users")
                          .doc(otherUid)
                          .get(),
                      builder: (context, userSnapshot) {
                        if (!userSnapshot.hasData) {
                          return const SizedBox(
                            height: 70,
                            child: Center(
                              child: CircularProgressIndicator(color: Color(0xFF5865F2), strokeWidth: 2),
                            ),
                          );
                        }

                        var userData = userSnapshot.data!.data() as Map<String, dynamic>;
                        var otherName = buildDisplayName(userData);
                        var profilePic = userData['profilepic'] ?? "";

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          leading: GestureDetector(
                            onTap: () => openProfile(otherUid),
                            child: CircleAvatar(
                              radius: 26,
                              backgroundColor: const Color(0xFF5865F2),
                              backgroundImage: profilePic.toString().isNotEmpty
                                  ? NetworkImage(profilePic)
                                  : null,
                              child: profilePic.toString().isNotEmpty
                                  ? null
                                  : const Icon(Icons.person, color: Colors.white),
                            ),
                          ),
                          title: Text(
                            otherName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            lastMessage.isEmpty ? "No messages yet" : lastMessage,
                            style: TextStyle(color: Colors.grey[500], fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                timeStr,
                                style: TextStyle(color: Colors.grey[500], fontSize: 11),
                              ),
                              const SizedBox(height: 4),
                              if (unreadCount > 0)
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF5865F2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatPage(
                                  conversationId: convo.id,
                                  otherUserName: otherName,
                                  otherUserId: otherUid,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
