import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'post_detail.dart';

class ProfilePage extends StatefulWidget {
  final String userId;

  const ProfilePage({super.key, required this.userId});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  var currentUser = FirebaseAuth.instance.currentUser;
  late TabController tabController;

  bool isFollowing = false;
  bool isLoadingFollow = false;

  List<String> autoTags = [];

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    checkIfFollowing();
  }

  Future<void> checkIfFollowing() async {
    if (widget.userId == currentUser!.uid) return;

    var doc = await FirebaseFirestore.instance
        .collection("tbl_follows")
        .doc("${currentUser!.uid}_${widget.userId}")
        .get();

    setState(() {
      isFollowing = doc.exists;
    });
  }

  Future<void> toggleFollow(Map<String, dynamic> userData) async {
    setState(() {
      isLoadingFollow = true;
    });

    var followDocId = "${currentUser!.uid}_${widget.userId}";
    var followRef = FirebaseFirestore.instance.collection("tbl_follows").doc(followDocId);

    var targetUserRef = FirebaseFirestore.instance.collection("tbl_users").doc(widget.userId);
    var currentUserRef = FirebaseFirestore.instance.collection("tbl_users").doc(currentUser!.uid);

    if (isFollowing) {
      await followRef.delete();
      await targetUserRef.update({"followerscount": FieldValue.increment(-1)});
      await currentUserRef.update({"followingscount": FieldValue.increment(-1)});
      setState(() {
        isFollowing = false;
      });
    } else {
      await followRef.set({
        "followerUid": currentUser!.uid,
        "followingUid": widget.userId,
        "createdAt": FieldValue.serverTimestamp(),
      });
      await targetUserRef.update({"followerscount": FieldValue.increment(1)});
      await currentUserRef.update({"followingscount": FieldValue.increment(1)});
      setState(() {
        isFollowing = true;
      });
    }

    setState(() {
      isLoadingFollow = false;
    });
  }

  List<String> generateBioTags(Map<String, dynamic> userData) {
    List<String> tags = [];
    var game = userData['favgame'] ?? '';
    if (game.isNotEmpty) tags.add("🎮 $game");

    var followers = userData['followerscount'] ?? 0;
    if (followers >= 100) tags.add("⭐ Popular");
    if (followers >= 500) tags.add("🔥 Influencer");

    var posts = userData['postcount'] ?? 0;
    if (posts >= 10) tags.add("✍️ Active Poster");

    tags.add("👾 GamerZone Member");
    return tags;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("tbl_users")
          .doc(widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Color(0xFF1E1F22),
            body: Center(child: CircularProgressIndicator(color: Color(0xFF5865F2))),
          );
        }

        var userData = snapshot.data!.data() as Map<String, dynamic>;
        var fullname = userData['fullname'] ?? "User";
        var bio = userData['bio'] ?? "";
        var followers = userData['followerscount'] ?? 0;
        var followings = userData['followingscount'] ?? 0;
        var postCount = userData['postcount'] ?? 0;
        var favGame = userData['favgame'] ?? "";
        var tags = generateBioTags(userData);

        bool isOwnProfile = widget.userId == currentUser!.uid;

        return Scaffold(
          backgroundColor: const Color(0xFF1E1F22),
          appBar: AppBar(
            backgroundColor: const Color(0xFF2B2D31),
            title: Text(
              fullname,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar + stats row
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 45,
                              backgroundColor: Color(0xFF5865F2),
                              child: Icon(Icons.person, size: 50, color: Colors.white),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  buildStatColumn(postCount.toString(), "Posts"),
                                  buildStatColumn(followers.toString(), "Followers"),
                                  buildStatColumn(followings.toString(), "Following"),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Text(
                          fullname,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (favGame.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            "🎮 $favGame",
                            style: const TextStyle(color: Color(0xFF5865F2), fontSize: 13),
                          ),
                        ],
                        const SizedBox(height: 5),
                        Text(
                          bio,
                          style: TextStyle(color: Colors.grey[300], fontSize: 14),
                        ),
                        const SizedBox(height: 10),

                        // Auto-generated tags
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: tags.map((tag) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2B2D31),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                tag,
                                style: TextStyle(color: Colors.grey[300], fontSize: 11),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),

                        // Follow / Edit button
                        if (!isOwnProfile)
                          SizedBox(
                            width: double.infinity,
                            height: 38,
                            child: ElevatedButton(
                              onPressed: isLoadingFollow
                                  ? null
                                  : () => toggleFollow(userData),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowing
                                    ? const Color(0xFF2B2D31)
                                    : const Color(0xFF5865F2),
                                side: isFollowing
                                    ? BorderSide(color: Colors.grey.shade600)
                                    : BorderSide.none,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: isLoadingFollow
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          color: Colors.white, strokeWidth: 2),
                                    )
                                  : Text(
                                      isFollowing ? "Following" : "Follow",
                                      style: TextStyle(
                                        color: isFollowing ? Colors.grey[300] : Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TabBarDelegate(
                    TabBar(
                      controller: tabController,
                      labelColor: const Color(0xFF5865F2),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: const Color(0xFF5865F2),
                      tabs: const [
                        Tab(icon: Icon(Icons.grid_3x3)),
                        Tab(icon: Icon(Icons.bookmark_border)),
                      ],
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: tabController,
              children: [
                // Posts tab
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("tbl_posts")
                      .where("uid", isEqualTo: widget.userId)
                      .orderBy("createdAt", descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF5865F2)),
                      );
                    }

                    var posts = snapshot.data!.docs;

                    if (posts.isEmpty) {
                      return Center(
                        child: Text("No posts yet", style: TextStyle(color: Colors.grey[500])),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        var post = posts[index];
                        var date = post['createdAt']?.toDate().toString() ?? '';

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PostDetailPage(postId: post.id),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2B2D31),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF5865F2).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        post['game'] ?? "",
                                        style: const TextStyle(color: Color(0xFF5865F2), fontSize: 11),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      date,
                                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  post['content'] ?? "",
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.thumb_up_alt_outlined, color: Colors.grey[500], size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      (post['likesCount'] ?? 0).toString(),
                                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                    ),
                                    const SizedBox(width: 14),
                                    Icon(Icons.comment_outlined, color: Colors.grey[500], size: 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      (post['commentCount'] ?? 0).toString(),
                                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
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

                // Saved posts tab
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("tbl_posts")
                      .where("bookmarkedBy", arrayContains: widget.userId)
                      .orderBy("createdAt", descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF5865F2)),
                      );
                    }

                    var posts = snapshot.data!.docs;

                    if (posts.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.bookmark_border, color: Colors.grey[600], size: 48),
                            const SizedBox(height: 10),
                            Text("No saved posts", style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        var post = posts[index];

                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PostDetailPage(postId: post.id),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2B2D31),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.bookmark, color: Color(0xFF5865F2), size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    post['content'] ?? "",
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildStatColumn(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(color: Colors.grey[400], fontSize: 12),
        ),
      ],
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: const Color(0xFF1E1F22),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) => false;
}
