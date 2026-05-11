import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage> {
  var postController = TextEditingController();
  var currentUser = FirebaseAuth.instance.currentUser;
  bool isLoading = false;
  int charCount = 0;
  int maxChars = 500;

  String selectedGame = "Valorant";

  List<String> games = [
    "League of Legends",
    "CS:GO",
    "Valorant",
    "DOTA2",
    "Mobile Legends",
    "COC",
  ];

  Future<void> submitPost() async {
    var content = postController.text.trim();

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post cannot be empty")),
      );
      return;
    }

    if (content.length > maxChars) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post exceeds character limit")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await FirebaseFirestore.instance.collection("tbl_posts").add({
        "content": content,
        "username": currentUser!.displayName ?? "User",
        "uid": currentUser!.uid,
        "game": selectedGame,
        "likesCount": 0,
        "commentCount": 0,
        "likedBy": [],
        "bookmarkedBy": [],
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post submitted!")),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1F22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2B2D31),
        title: const Text(
          "Create Post",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: isLoading ? null : submitPost,
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    "Post",
                    style: TextStyle(
                      color: Color(0xFF5865F2),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // User row
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 22,
                      backgroundColor: Color(0xFF5865F2),
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentUser!.displayName ?? "User",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          "Posting to Community",
                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Text field
                TextField(
                  controller: postController,
                  maxLines: null,
                  minLines: 5,
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  onChanged: (val) {
                    setState(() {
                      charCount = val.length;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "What's on your mind, gamer? 🎮",
                    hintStyle: TextStyle(color: Colors.grey[600]),
                    filled: true,
                    fillColor: const Color(0xFF2B2D31),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 8),

                // Character counter
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "$charCount / $maxChars",
                    style: TextStyle(
                      color: charCount > maxChars ? Colors.red : Colors.grey[500],
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Game tag selector
                Text(
                  "Select Game Tag",
                  style: TextStyle(color: Colors.grey[400], fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: games.map((game) {
                    bool isSelected = game == selectedGame;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedGame = game;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF5865F2) : const Color(0xFF2B2D31),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF5865F2) : Colors.grey.shade700,
                          ),
                        ),
                        child: Text(
                          game,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey[400],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),

                // Media options (not functional, just UI)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B2D31),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.photo, color: Colors.green[400]),
                          const SizedBox(width: 6),
                          Text("Photo", style: TextStyle(color: Colors.grey[400])),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.videocam, color: Colors.red[400]),
                          const SizedBox(width: 6),
                          Text("Video", style: TextStyle(color: Colors.grey[400])),
                        ],
                      ),
                      Row(
                        children: [
                          Icon(Icons.gif, color: Colors.blue[400]),
                          const SizedBox(width: 6),
                          Text("GIF", style: TextStyle(color: Colors.grey[400])),
                        ],
                      ),
                    ],
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
