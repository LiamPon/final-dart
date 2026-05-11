import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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

  Future<void> addComment() async {
    var text = commentController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      isPosting = true;
    });

    try {
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
                    if (!snapshot.hasData) {
                      return const SizedBox();
                    }
                    var post = snapshot.data!;
                    var date = post['createdAt']?.toDate().toString() ?? '';

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
                              const CircleAvatar(
                                radius: 22,
                                backgroundColor: Color(0xFF5865F2),
                                child: Icon(Icons.person, color: Colors.white),
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
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF5865F2)),
                      );
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
                        var commentId = comment.id;
                        List likedBy = comment['likedBy'] ?? [];
                        bool isLiked = likedBy.contains(currentUser!.uid);
                        var date = comment['createdAt']?.toDate().toString() ?? '';

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
                                  const CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Color(0xFF5865F2),
                                    child: Icon(Icons.person, color: Colors.white, size: 16),
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
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 18,
                  backgroundColor: Color(0xFF5865F2),
                  child: Icon(Icons.person, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
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
