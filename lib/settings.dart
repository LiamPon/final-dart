import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  var currentUser = FirebaseAuth.instance.currentUser;
  bool isPrivateAccount = false;
  bool allowMessages = true;


  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  void confirmLogout() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2B2D31),
          title: const Text("Logout", style: TextStyle(color: Colors.white)),
          content: Text(
            "Are you sure you want to logout?",
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
                logout();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5865F2)),
              child: const Text("Logout", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2B2D31),
          title: const Text("Delete Account", style: TextStyle(color: Colors.red)),
          content: Text(
            "This action is permanent and cannot be undone. All your posts and data will be deleted.",
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
                try {
                  // Delete Firestore user data
                  await FirebaseFirestore.instance
                      .collection("tbl_users")
                      .doc(currentUser!.uid)
                      .delete();

                  // Delete the auth account
                  await currentUser!.delete();

                  if (!mounted) return;
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                } on FirebaseAuthException catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message ?? "Failed to delete account")),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Delete", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2D31),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: const Color(0xFF5865F2)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        value: value,
        activeColor: const Color(0xFF5865F2),
        onChanged: onChanged,
      ),
    );
  }

  Widget buildActionTile({
    required IconData icon,
    required String title,
    required Color iconColor,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2B2D31),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor),
        title: Text(title, style: TextStyle(color: textColor, fontSize: 14)),
        trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 14),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1F22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2B2D31),
        title: const Text(
          "Settings",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          // Account info
          Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2B2D31),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFF5865F2),
                  child: Icon(Icons.person, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUser?.displayName ?? "User",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      currentUser?.email ?? "",
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),

          buildSectionTitle("Privacy"),
          buildToggleTile(
            icon: Icons.lock,
            title: "Private Account",
            subtitle: "Only followers can see your posts",
            value: isPrivateAccount,
            onChanged: (val) => setState(() => isPrivateAccount = val),
          ),
          buildToggleTile(
            icon: Icons.message,
            title: "Allow Direct Messages",
            subtitle: "Anyone can send you a message",
            value: allowMessages,
            onChanged: (val) => setState(() => allowMessages = val),
          ),

          buildSectionTitle("Manage"),
          buildActionTile(
            icon: Icons.block,
            title: "Blocked Users",
            iconColor: Colors.orange,
            textColor: Colors.white,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BlockedUsersPage()),
              );
            },
          ),

          buildSectionTitle("Account"),
          buildActionTile(
            icon: Icons.logout,
            title: "Logout",
            iconColor: Colors.grey,
            textColor: Colors.white,
            onTap: confirmLogout,
          ),
          buildActionTile(
            icon: Icons.delete_forever,
            title: "Delete Account",
            iconColor: Colors.red,
            textColor: Colors.red,
            onTap: confirmDeleteAccount,
          ),

          const SizedBox(height: 30),
          Center(
            child: Text(
              "GamerZone v1.0.0",
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// Blocked users page
class BlockedUsersPage extends StatelessWidget {
  const BlockedUsersPage({super.key});

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
  Widget build(BuildContext context) {
    var currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF1E1F22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2B2D31),
        title: const Text(
          "Blocked Users",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("tbl_blocks")
            .where("blockerUid", isEqualTo: currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF5865F2)),
            );
          }

          var blocks = snapshot.data!.docs;

          if (blocks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.block, color: Colors.grey[600], size: 48),
                  const SizedBox(height: 12),
                  Text("No blocked users", style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: blocks.length,
            itemBuilder: (context, index) {
              var block = blocks[index];
              var blockedUid = block['blockedUid'];

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection("tbl_users")
                    .doc(blockedUid)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) return const SizedBox();

                  var userData = userSnapshot.data!.data() as Map<String, dynamic>? ?? {};
                  var name = buildDisplayName(userData);

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B2D31),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF5865F2),
                        child: Icon(Icons.person, color: Colors.white),
                      ),
                      title: Text(name, style: const TextStyle(color: Colors.white)),
                      trailing: TextButton(
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection("tbl_blocks")
                              .doc(block.id)
                              .delete();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("User unblocked")),
                          );
                        },
                        child: const Text(
                          "Unblock",
                          style: TextStyle(color: Color(0xFF5865F2)),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

