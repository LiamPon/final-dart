import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'profile.dart';

class PostDetailPage extends StatefulWidget {
  final String postId;

  const PostDetailPage({super.key, required this.postId});

  @override
  State<PostDetailPage> createState() => _PostDetailPageState();
}

class _PostDetailPageState extends State<PostDetailPage> {
  var commentController = TextEditingController();
  var currentUser = FirebaseAuth.instance.currentUser;
  bool isPosting = false;

  XFile? selectedCommentImage;
  Uint8List? selectedCommentImageBytes;

  void openProfile(String userId) {
    if (userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(userId: userId),
      ),
    );
  }

  Widget buildUserAvatar(String userId, {double radius = 22}) {
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

  String formatTime(DateTime? date) {
    if (date == null) return "";
    var hour = date.hour;
    var minute = date.minute.toString().padLeft(2, '0');
    var period = hour >= 12 ? "PM" : "AM";
    var hour12 = hour % 12;
    if (hour12 == 0) hour12 = 12;
    return "$hour12:$minute $period";
  }

  Future<void> pickCommentImage() async {
    var file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (file == null) return;

    var bytes = await file.readAsBytes();
    setState(() {
      selectedCommentImage = file;
      selectedCommentImageBytes = bytes;
    });
  }

  void clearCommentImage() {
    setState(() {
      selectedCommentImage = null;
      selectedCommentImageBytes = null;
    });
  }

  Future<String?> uploadCommentImage() async {
    if (selectedCommentImage == null || selectedCommentImageBytes == null) return null;

    var fileName = selectedCommentImage!.name;
    var storageRef = FirebaseStorage.instance
        .ref()
        .child("comment_images")
        .child("${currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}_$fileName");

    await storageRef.putData(selectedCommentImageBytes!);
    return storageRef.getDownloadURL();
  }

  Future<void> addComment() async {
    var text = commentController.text.trim();
    if (text.isEmpty && selectedCommentImageBytes == null) return;

    setState(() {
      isPosting = true;
    });

    try {
      var imageUrl = await uploadCommentImage();

      await FirebaseFirestore.instance
          .collection("tbl_posts")
          .doc(widget.postId)
          .collection("tbl_comments")
          .add({
        "comment": text,
        "username": currentUser!.displayName ?? "User",
        "uid": currentUser!.uid,
        "likesCount": 0,
        "likedBy": [],
        if (imageUrl != null && imageUrl.isNotEmpty) "imageUrl": imageUrl,
        "createdAt": FieldValue.serverTimestamp(),
      });

      // update comment count on post
      await FirebaseFirestore.instance
          .collection("tbl_posts")
          .doc(widget.postId)
          .update({
        "commentCount": FieldValue.increment(1),
      });

      commentController.clear();
      clearCommentImage();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }

    setState(() {
      isPosting = false;
    });
  }

  Future<void> likeComment(String commentId, List likedBy) async {
    var uid = currentUser!.uid;
    var commentRef = FirebaseFirestore.instance
        .collection("tbl_posts")
        .doc(widget.postId)
        .collection("tbl_comments")
        .doc(commentId);

    if (likedBy.contains(uid)) {
      await commentRef.update({
        "likesCount": FieldValue.increment(-1),
        "likedBy": FieldValue.arrayRemove([uid]),
      });
    } else {
      await commentRef.update({
        "likesCount": FieldValue.increment(1),
        "likedBy": FieldValue.arrayUnion([uid]),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1F22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2B2D31),
        title: const Text(
          "Post",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Main post
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("tbl_posts")
                      .doc(widget.postId)
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
                          "Failed to load post",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data == null) {
                      return Center(
                        child: Text(
                          "Post not found",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      );
                    }
                    var post = snapshot.data!;
                    var postData = post.data() as Map<String, dynamic>;
                    var date = formatTime(post['createdAt']?.toDate());
                    var imageUrl = postData['imageUrl'] ?? "";
                    var postOwnerId = post['uid'] ?? "";

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2B2D31),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => openProfile(postOwnerId),
                                child: buildUserAvatar(postOwnerId, radius: 22),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      post['username'] ?? "User",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      date,
                                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5865F2).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  post['game'] ?? "",
                                  style: const TextStyle(color: Color(0xFF5865F2), fontSize: 10),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            post['content'] ?? "",
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          if (imageUrl.toString().isNotEmpty) ...[
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                imageUrl,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Icon(Icons.thumb_up_alt_outlined, color: Colors.grey, size: 18),
                              const SizedBox(width: 5),
                              Text(
                                "${post['likesCount'] ?? 0} likes",
                                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                              ),
                              const SizedBox(width: 20),
                              const Icon(Icons.comment_outlined, color: Colors.grey, size: 18),
                              const SizedBox(width: 5),
                              Text(
                                "${post['commentCount'] ?? 0} comments",
                                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),

                const SizedBox(height: 16),
                Text(
                  "Comments",
                  style: TextStyle(
                    color: Colors.grey[300],
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 10),

                // Comments
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("tbl_posts")
                      .doc(widget.postId)
                      .collection("tbl_comments")
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
                          "Failed to load comments",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data == null) {
                      return const SizedBox.shrink();
                    }

                    var comments = snapshot.data!.docs;

                    if (comments.isEmpty) {
                      return Center(
                        child: Text(
                          "No comments yet. Be the first!",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      );
                    }

                    return Column(
                      children: comments.map((comment) {
                        var commentData = comment.data() as Map<String, dynamic>;
                        var commentId = comment.id;
                        List likedBy = comment['likedBy'] ?? [];
                        bool isLiked = likedBy.contains(currentUser!.uid);
                        var date = formatTime(comment['createdAt']?.toDate());
                        var imageUrl = commentData['imageUrl'] ?? "";
                        var commentOwnerId = comment['uid'] ?? "";

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2B2D31),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => openProfile(commentOwnerId),
                                    child: buildUserAvatar(commentOwnerId, radius: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          comment['username'] ?? "User",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        Text(
                                          date,
                                          style: TextStyle(color: Colors.grey[500], fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => likeComment(commentId, likedBy),
                                    child: Row(
                                      children: [
                                        Icon(
                                          isLiked ? Icons.favorite : Icons.favorite_border,
                                          color: isLiked ? Colors.red : Colors.grey,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          (comment['likesCount'] ?? 0).toString(),
                                          style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                comment['comment'] ?? "",
                                style: const TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              if (imageUrl.toString().isNotEmpty) ...[
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    imageUrl,
                                    height: 160,
                                    width: 160,
                                    fit: BoxFit.cover,
                                    alignment: Alignment.center,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),

          // Comment input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: const Color(0xFF2B2D31),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selectedCommentImageBytes != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.memory(
                            selectedCommentImageBytes!,
                            height: 90,
                            width: 90,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: clearCommentImage,
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
                    const CircleAvatar(
                      radius: 18,
                      backgroundColor: Color(0xFF5865F2),
                      child: Icon(Icons.person, color: Colors.white, size: 18),
                    ),
                    IconButton(
                      onPressed: pickCommentImage,
                      icon: Icon(Icons.photo, color: Colors.grey[400]),
                    ),
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: "Add a comment...",
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          filled: true,
                          fillColor: const Color(0xFF1E1F22),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: isPosting ? null : addComment,
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: const Color(0xFF5865F2),
                        child: isPosting
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
