import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_post.dart';
import 'post_detail.dart';
import 'profile.dart';
import 'messages.dart';
import 'settings.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int currentIndex = 0;

  var currentUser = FirebaseAuth.instance.currentUser;

  List<String> gameFilters = [
    "All",
    "League of Legends",
    "CS:GO",
    "Valorant",
    "DOTA2",
    "Mobile Legends",
    "COC",
  ];

  String selectedFilter = "All";

  String searchQuery = "";
  var searchController = TextEditingController();

  String formatTime(DateTime? date) {
    if (date == null) return "";
    var hour = date.hour;
    var minute = date.minute.toString().padLeft(2, '0');
    var period = hour >= 12 ? "PM" : "AM";
    var hour12 = hour % 12;
    if (hour12 == 0) hour12 = 12;
    return "$hour12:$minute $period";
  }

  void openProfile(String userId) {
    if (userId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfilePage(userId: userId),
      ),
    );
  }

  Widget buildUserAvatar(String userId, {double radius = 20}) {
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

  Stream<QuerySnapshot> getPostsStream() {
    if (selectedFilter == "All") {
      return FirebaseFirestore.instance
          .collection("tbl_posts")
          .orderBy("createdAt", descending: true)
          .snapshots();
    } else {
      return FirebaseFirestore.instance
          .collection("tbl_posts")
          .where("game", isEqualTo: selectedFilter)
          .snapshots();
    }
  }

  Future<void> toggleLike(String postId, List likedBy) async {
    var uid = currentUser!.uid;
    var postRef = FirebaseFirestore.instance.collection("tbl_posts").doc(postId);

    if (likedBy.contains(uid)) {
      await postRef.update({
        "likesCount": FieldValue.increment(-1),
        "likedBy": FieldValue.arrayRemove([uid]),
      });
    } else {
      await postRef.update({
        "likesCount": FieldValue.increment(1),
        "likedBy": FieldValue.arrayUnion([uid]),
      });
    }
  }

  Future<void> toggleBookmark(String postId, List bookmarkedBy) async {
    var uid = currentUser!.uid;
    var postRef = FirebaseFirestore.instance.collection("tbl_posts").doc(postId);

    if (bookmarkedBy.contains(uid)) {
      await postRef.update({
        "bookmarkedBy": FieldValue.arrayRemove([uid]),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Removed from bookmarks")),
      );
    } else {
      await postRef.update({
        "bookmarkedBy": FieldValue.arrayUnion([uid]),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post bookmarked!")),
      );
    }
  }

  Future<void> deletePost(String postId) async {
    try {
      await FirebaseFirestore.instance.collection("tbl_posts").doc(postId).delete();
      await FirebaseFirestore.instance
          .collection("tbl_users")
          .doc(currentUser!.uid)
          .update({"postcount": FieldValue.increment(-1)});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Post deleted")),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void confirmDeletePost(String postId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2B2D31),
          title: const Text("Delete Post", style: TextStyle(color: Colors.white)),
          content: Text(
            "Are you sure you want to delete this post?",
            style: TextStyle(color: Colors.grey[400]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: Colors.grey[400])),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                deletePost(postId);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void showPostMenu(String postId, String postOwnerId) {
    var isOwnPost = postOwnerId == currentUser!.uid;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2B2D31),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            if (!isOwnPost)
              ListTile(
                leading: const Icon(Icons.flag, color: Colors.orange),
                title: const Text("Report Post", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  FirebaseFirestore.instance.collection("tbl_reports").add({
                    "postId": postId,
                    "reportedBy": currentUser!.uid,
                    "createdAt": FieldValue.serverTimestamp(),
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Post reported")),
                  );
                },
              ),
            if (!isOwnPost)
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text("Block User", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  var blockDocId = "${currentUser!.uid}_${postOwnerId}";
                  FirebaseFirestore.instance
                      .collection("tbl_blocks")
                      .doc(blockDocId)
                      .set({
                    "blockerUid": currentUser!.uid,
                    "blockedUid": postOwnerId,
                    "createdAt": FieldValue.serverTimestamp(),
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("User blocked")),
                  );
                },
              ),
            if (isOwnPost)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text("Delete Post", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  confirmDeletePost(postId);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close, color: Colors.grey),
              title: Text("Cancel", style: TextStyle(color: Colors.grey[400])),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }

  Widget buildFeedTab() {
    return Column(
      children: [
        Container(
          color: const Color(0xFF2B2D31),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          child: TextField(
            controller: searchController,
            style: const TextStyle(color: Colors.white),
            onChanged: (val) {
              setState(() {
                searchQuery = val.toLowerCase();
              });
            },
            decoration: InputDecoration(
              hintText: "Search posts...",
              hintStyle: TextStyle(color: Colors.grey[500]),
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

        Container(
          color: const Color(0xFF2B2D31),
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            itemCount: gameFilters.length,
            itemBuilder: (context, index) {
              var filter = gameFilters[index];
              var isSelected = filter == selectedFilter;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedFilter = filter;
                  });
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF5865F2) : const Color(0xFF1E1F22),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[400],
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: getPostsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF5865F2)),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    "Failed to load posts",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data == null) {
                return Center(
                  child: Text(
                    "No posts yet",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                );
              }

              var posts = snapshot.data!.docs;

              posts.sort((a, b) {
                var aDate = a['createdAt']?.toDate();
                var bDate = b['createdAt']?.toDate();
                if (aDate == null && bDate == null) return 0;
                if (aDate == null) return 1;
                if (bDate == null) return -1;
                return bDate.compareTo(aDate);
              });

              if (posts.isEmpty) {
                return Center(
                  child: Text(
                    "No posts yet",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                );
              }

              var filteredPosts = posts.where((post) {
                var content = (post['content'] ?? '').toString().toLowerCase();
                var username = (post['username'] ?? '').toString().toLowerCase();
                var game = (post['game'] ?? '').toString().toLowerCase();
                return content.contains(searchQuery) ||
                    username.contains(searchQuery) ||
                    game.contains(searchQuery);
              }).toList();

              if (filteredPosts.isEmpty) {
                return Center(
                  child: Text(
                    "No posts found",
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: filteredPosts.length,
                itemBuilder: (context, index) {
                  var post = filteredPosts[index];
                  var postId = post.id;
                  var postData = post.data() as Map<String, dynamic>;

                  List likedBy = post['likedBy'] ?? [];
                  List bookmarkedBy = post['bookmarkedBy'] ?? [];
                  bool isLiked = likedBy.contains(currentUser!.uid);
                  bool isBookmarked = bookmarkedBy.contains(currentUser!.uid);

                  var date = formatTime(post['createdAt']?.toDate());
                  var imageUrl = postData['imageUrl'] ?? "";

                  return GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PostDetailPage(postId: postId),
                        ),
                      );
                      if (!mounted) return;
                      setState(() {});
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                                onTap: () => openProfile(postData['uid'] ?? ""),
                                child: buildUserAvatar(postData['uid'] ?? "", radius: 20),
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
                                        fontSize: 14,
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
                                  style: const TextStyle(
                                    color: Color(0xFF5865F2),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => showPostMenu(postId, postData['uid'] ?? ""),
                                icon: Icon(Icons.more_vert, color: Colors.grey[500], size: 20),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Text(
                            post['content'] ?? "",
                            style: const TextStyle(color: Colors.white, fontSize: 15),
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
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => toggleLike(postId, likedBy),
                                child: Row(
                                  children: [
                                    Icon(
                                      isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined,
                                      color: isLiked ? const Color(0xFF5865F2) : Colors.grey,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      (post['likesCount'] ?? 0).toString(),
                                      style: TextStyle(color: Colors.grey[400]),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 20),
                              Row(
                                children: [
                                  const Icon(Icons.comment_outlined, color: Colors.grey, size: 20),
                                  const SizedBox(width: 5),
                                  Text(
                                    (post['commentCount'] ?? 0).toString(),
                                    style: TextStyle(color: Colors.grey[400]),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => toggleBookmark(postId, bookmarkedBy),
                                child: Icon(
                                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                                  color: isBookmarked ? const Color(0xFF5865F2) : Colors.grey,
                                  size: 22,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> pages = [
      buildFeedTab(),
      MessagesPage(),
      ProfilePage(userId: currentUser!.uid),
      const SettingsPage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF1E1F22),
      appBar: currentIndex == 0
          ? AppBar(
              backgroundColor: const Color(0xFF2B2D31),
              title: const Text(
                "GamerZone",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              automaticallyImplyLeading: false,
              centerTitle: false,
            )
          : null,
      body: pages[currentIndex],
      floatingActionButton: currentIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CreatePostPage()),
                );
              },
              backgroundColor: const Color(0xFF5865F2),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },
        backgroundColor: const Color(0xFF2B2D31),
        selectedItemColor: const Color(0xFF5865F2),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.message), label: "Messages"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings"),
        ],
      ),
    );
  }
}
