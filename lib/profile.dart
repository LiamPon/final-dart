import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'post_detail.dart';
import 'chat.dart';

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
  bool isBlocked = false;
  bool isLoadingBlock = false;

  XFile? selectedProfileImage;
  Uint8List? selectedProfileImageBytes;
  bool isUploadingPhoto = false;

  List<String> autoTags = [];

  String formatTime(DateTime? date) {
    if (date == null) return "";
    var hour = date.hour;
    var minute = date.minute.toString().padLeft(2, '0');
    var period = hour >= 12 ? "PM" : "AM";
    var hour12 = hour % 12;
    if (hour12 == 0) hour12 = 12;
    return "$hour12:$minute $period";
  }

  int readCount(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  int readFollowingsCount(Map<String, dynamic> userData) {
    var value = userData['followingsCount'];
    value ??= userData['followingscount'];
    return readCount(value);
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

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    checkIfFollowing();
    checkIfBlocked();
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

  Future<void> checkIfBlocked() async {
    if (widget.userId == currentUser!.uid) return;

    var doc = await FirebaseFirestore.instance
        .collection("tbl_blocks")
        .doc("${currentUser!.uid}_${widget.userId}")
        .get();

    setState(() {
      isBlocked = doc.exists;
    });
  }

  Future<void> toggleFollow() async {
    setState(() {
      isLoadingFollow = true;
    });

    var followDocId = "${currentUser!.uid}_${widget.userId}";
    var followRef = FirebaseFirestore.instance.collection("tbl_follows").doc(followDocId);

    var targetUserRef = FirebaseFirestore.instance.collection("tbl_users").doc(widget.userId);
    var currentUserRef = FirebaseFirestore.instance.collection("tbl_users").doc(currentUser!.uid);

    var currentSnapshot = await currentUserRef.get();
    var currentData = currentSnapshot.data() as Map<String, dynamic>? ?? {};
    var currentFollowings = readFollowingsCount(currentData);
    var delta = isFollowing ? -1 : 1;
    var nextFollowings = currentFollowings + delta;
    if (nextFollowings < 0) nextFollowings = 0;

    if (isFollowing) {
      await followRef.delete();
      await targetUserRef.update({"followerscount": FieldValue.increment(-1)});
      await currentUserRef.update({"followingsCount": nextFollowings});
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
      await currentUserRef.update({"followingsCount": nextFollowings});
      setState(() {
        isFollowing = true;
      });
    }

    setState(() {
      isLoadingFollow = false;
    });
  }

  Future<void> unfollowForBlock() async {
    if (!isFollowing) return;

    var followDocId = "${currentUser!.uid}_${widget.userId}";
    var followRef = FirebaseFirestore.instance.collection("tbl_follows").doc(followDocId);

    var targetUserRef = FirebaseFirestore.instance.collection("tbl_users").doc(widget.userId);
    var currentUserRef = FirebaseFirestore.instance.collection("tbl_users").doc(currentUser!.uid);

    var currentSnapshot = await currentUserRef.get();
    var currentData = currentSnapshot.data() as Map<String, dynamic>? ?? {};
    var currentFollowings = readFollowingsCount(currentData);
    var nextFollowings = currentFollowings - 1;
    if (nextFollowings < 0) nextFollowings = 0;

    await followRef.delete();
    await targetUserRef.update({"followerscount": FieldValue.increment(-1)});
    await currentUserRef.update({"followingsCount": nextFollowings});

    setState(() {
      isFollowing = false;
    });
  }

  Future<void> toggleBlock() async {
    setState(() {
      isLoadingBlock = true;
    });

    var blockDocId = "${currentUser!.uid}_${widget.userId}";
    var blockRef = FirebaseFirestore.instance.collection("tbl_blocks").doc(blockDocId);

    try {
      if (isBlocked) {
        await blockRef.delete();
        setState(() {
          isBlocked = false;
        });
      } else {
        await blockRef.set({
          "blockerUid": currentUser!.uid,
          "blockedUid": widget.userId,
          "createdAt": FieldValue.serverTimestamp(),
        });
        await unfollowForBlock();
        setState(() {
          isBlocked = true;
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }

    if (!mounted) return;
    setState(() {
      isLoadingBlock = false;
    });
  }

  void confirmBlockChange() {
    if (widget.userId == currentUser!.uid) return;

    var isUnblock = isBlocked;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2B2D31),
          title: Text(
            isUnblock ? "Unblock User" : "Block User",
            style: TextStyle(color: isUnblock ? Colors.white : Colors.red),
          ),
          content: Text(
            isUnblock
                ? "This user will be able to view your profile again."
                : "You won't see this user's content and they can't interact with you.",
            style: TextStyle(color: Colors.grey[400]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: Colors.grey[400])),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await toggleBlock();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isUnblock ? const Color(0xFF5865F2) : Colors.red,
              ),
              child: Text(
                isUnblock ? "Unblock" : "Block",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  List<String> generateBioTags(Map<String, dynamic> userData) {
    List<String> tags = [];
    var game = userData['favgame'] ?? '';
    if (game.isNotEmpty) tags.add("🎮 $game");

    var followers = readCount(userData['followerscount']);
    if (followers >= 100) tags.add("⭐ Popular");
    if (followers >= 500) tags.add("🔥 Influencer");

    var posts = readCount(userData['postcount']);
    if (posts >= 10) tags.add("✍️ Active Poster");

    tags.add("👾 GamerZone Member");
    return tags;
  }

  Future<void> addGameTag() async {
    var tagController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2B2D31),
          title: const Text("Add Game Tag", style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: tagController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Enter game name",
              hintStyle: TextStyle(color: Colors.grey[500]),
              filled: true,
              fillColor: const Color(0xFF1E1F22),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: Colors.grey[400])),
            ),
            ElevatedButton(
              onPressed: () async {
                var tag = tagController.text.trim();
                if (tag.isEmpty) return;
                await FirebaseFirestore.instance
                    .collection("tbl_users")
                    .doc(currentUser!.uid)
                    .update({
                  "gameTags": FieldValue.arrayUnion([tag]),
                });
                if (!mounted) return;
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5865F2)),
              child: const Text("Add", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> removeGameTag(String tag) async {
    await FirebaseFirestore.instance
        .collection("tbl_users")
        .doc(currentUser!.uid)
        .update({
      "gameTags": FieldValue.arrayRemove([tag]),
    });
  }

  Future<void> pickProfileImage() async {
    var file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (file == null) return;

    var bytes = await file.readAsBytes();
    setState(() {
      selectedProfileImage = file;
      selectedProfileImageBytes = bytes;
      isUploadingPhoto = true;
    });

    try {
      var fileName = selectedProfileImage!.name;
      var storageRef = FirebaseStorage.instance
          .ref()
          .child("profile_images")
          .child("${currentUser!.uid}_${DateTime.now().millisecondsSinceEpoch}_$fileName");

      await storageRef.putData(selectedProfileImageBytes!);
      var url = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance
          .collection("tbl_users")
          .doc(currentUser!.uid)
          .update({"profilepic": url});
      await currentUser!.updatePhotoURL(url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }

    if (!mounted) return;
    setState(() {
      isUploadingPhoto = false;
    });
  }

  Future<void> startChatWithUser(String otherUid, String otherName) async {
    if (otherUid == currentUser!.uid) return;

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
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection("tbl_users")
          .doc(widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF1E1F22),
            body: Center(child: CircularProgressIndicator(color: Color(0xFF5865F2))),
          );
        }
        if (snapshot.hasError) {
          return const Scaffold(
            backgroundColor: Color(0xFF1E1F22),
            body: Center(
              child: Text(
                "Failed to load profile",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data == null) {
          return const Scaffold(
            backgroundColor: Color(0xFF1E1F22),
            body: Center(
              child: Text(
                "Profile not found",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        var userData = snapshot.data!.data() as Map<String, dynamic>;
        var fullname = buildDisplayName(userData);
        var bio = userData['bio'] ?? "";
        var followers = readCount(userData['followerscount']);
        var followings = readFollowingsCount(userData);
        var postCount = readCount(userData['postcount']);
        var favGame = userData['favgame'] ?? "";
        var tags = generateBioTags(userData);
        var profilePic = userData['profilepic'] ?? "";
        var gameTags = <String>[];
        if (userData['gameTags'] is List) {
          gameTags = List<String>.from(userData['gameTags']);
        }

        bool isOwnProfile = widget.userId == currentUser!.uid;
        var showBio = bio.trim().isNotEmpty && bio.trim() != "New to GamerZone 🎮";

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
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 45,
                                  backgroundColor: const Color(0xFF5865F2),
                                  backgroundImage: profilePic.toString().isNotEmpty
                                      ? NetworkImage(profilePic)
                                      : null,
                                  child: profilePic.toString().isNotEmpty
                                      ? null
                                      : const Icon(Icons.person, size: 50, color: Colors.white),
                                ),
                                if (isOwnProfile)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: GestureDetector(
                                      onTap: isUploadingPhoto ? null : pickProfileImage,
                                      child: CircleAvatar(
                                        radius: 14,
                                        backgroundColor: Colors.grey[700],
                                        child: isUploadingPhoto
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.camera_alt,
                                                size: 14,
                                                color: Colors.white,
                                              ),
                                      ),
                                    ),
                                  ),
                              ],
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
                        if (showBio) ...[
                          const SizedBox(height: 5),
                          Text(
                            bio,
                            style: TextStyle(color: Colors.grey[300], fontSize: 14),
                          ),
                          const SizedBox(height: 10),
                        ] else
                          const SizedBox(height: 8),

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
                        const SizedBox(height: 12),

                        Row(
                          children: [
                            Text(
                              "Game Tags",
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            if (isOwnProfile)
                              IconButton(
                                onPressed: addGameTag,
                                icon: const Icon(Icons.add, color: Color(0xFF5865F2)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (gameTags.isEmpty)
                          Text(
                            "No game tags yet",
                            style: TextStyle(color: Colors.grey[500], fontSize: 12),
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: gameTags.map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2B2D31),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      tag,
                                      style: TextStyle(color: Colors.grey[300], fontSize: 11),
                                    ),
                                    if (isOwnProfile) ...[
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () => removeGameTag(tag),
                                        child: Icon(Icons.close, color: Colors.grey[400], size: 12),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 14),

                        // Follow / Message buttons
                        if (!isOwnProfile)
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 38,
                                  child: ElevatedButton(
                                    onPressed: isLoadingFollow ? null : () => toggleFollow(),
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
                              ),
                              const SizedBox(width: 10),
                              SizedBox(
                                height: 38,
                                child: ElevatedButton(
                                  onPressed: () => startChatWithUser(widget.userId, fullname),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2B2D31),
                                    side: BorderSide(color: Colors.grey.shade600),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.message, color: Colors.white, size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        "Message",
                                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
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
                        Tab(icon: Icon(Icons.list)),
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
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF5865F2)),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text("Failed to load posts", style: TextStyle(color: Colors.grey[500])),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data == null) {
                      return const SizedBox.shrink();
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
                        child: Text("No posts yet", style: TextStyle(color: Colors.grey[500])),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: posts.length,
                      itemBuilder: (context, index) {
                        var post = posts[index];
                        var date = formatTime(post['createdAt']?.toDate());
                        var postData = post.data() as Map<String, dynamic>;
                        var imageUrl = postData['imageUrl'] ?? "";

                        return GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PostDetailPage(postId: post.id),
                              ),
                            );
                            if (!mounted) return;
                            setState(() {});
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
                                if (imageUrl.toString().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      imageUrl,
                                      height: 160,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ],
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
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF5865F2)),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text("Failed to load saved posts", style: TextStyle(color: Colors.grey[500])),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data == null) {
                      return const SizedBox.shrink();
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
                        var date = formatTime(post['createdAt']?.toDate());
                        var postData = post.data() as Map<String, dynamic>;
                        var imageUrl = postData['imageUrl'] ?? "";

                        return GestureDetector(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PostDetailPage(postId: post.id),
                              ),
                            );
                            if (!mounted) return;
                            setState(() {});
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
                                if (imageUrl.toString().isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      imageUrl,
                                      height: 140,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Text(
                                  date,
                                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
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
