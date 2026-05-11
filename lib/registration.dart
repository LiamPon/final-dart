import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  var formKey = GlobalKey<FormState>();
  var firstNameController = TextEditingController();
  var lastNameController = TextEditingController();
  var emailController = TextEditingController();
  var passwordController = TextEditingController();
  var confirmpassController = TextEditingController();
  var birthdateController = TextEditingController();

  bool isLoading = false;
  bool agreedToPolicy = false;
  bool obscurePass = true;
  bool obscureConfirm = true;

  var selectedDate = "";

  Future<void> pickDate() async {
    var picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: Color(0xFF5865F2)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        selectedDate =
            "${picked.month}/${picked.day}/${picked.year}";
        birthdateController.text = selectedDate;
      });
    }
  }

  Future<void> registerUser() async {
    if (!formKey.currentState!.validate()) return;
    if (!agreedToPolicy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please agree to the privacy policy")),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      var userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      var fullName = "${firstNameController.text.trim()} ${lastNameController.text.trim()}";
      await userCredential.user!.updateDisplayName(fullName);

      await FirebaseFirestore.instance
          .collection("tbl_users")
          .doc(userCredential.user!.uid)
          .set({
        "firstname": firstNameController.text.trim(),
        "lastname": lastNameController.text.trim(),
        "email": emailController.text.trim(),
        "birthdate": birthdateController.text,
        "bio": "",
        "followerscount": 0,
        "followingsCount": 0,
        "postcount": 0,
        "profilepic": "",
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Registration successful!")),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Registration failed")),
      );
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
          "Create Account",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 45,
                      backgroundColor: const Color(0xFF5865F2),
                      child: const Icon(Icons.person, size: 55, color: Colors.white),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.grey[700],
                        child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Join GamerZone 🎮",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                "Connect with gamers worldwide",
                style: TextStyle(color: Colors.grey[400], fontSize: 14),
              ),
              const SizedBox(height: 25),

              // First Name
              TextFormField(
                controller: firstNameController,
                style: const TextStyle(color: Colors.white),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "First name is required";
                  }
                  if (value.trim().length > 20) {
                    return "First name must be 20 characters or less";
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: "First Name",
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: const Icon(Icons.person, color: Color(0xFF5865F2)),
                  filled: true,
                  fillColor: const Color(0xFF2B2D31),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF5865F2)),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Last Name
              TextFormField(
                controller: lastNameController,
                style: const TextStyle(color: Colors.white),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Last name is required";
                  }
                  if (value.trim().length > 20) {
                    return "Last name must be 20 characters or less";
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: "Last Name",
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: const Icon(Icons.person, color: Color(0xFF5865F2)),
                  filled: true,
                  fillColor: const Color(0xFF2B2D31),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF5865F2)),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Email
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: const TextStyle(color: Colors.white),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Email is required";
                  }
                  if (!value.contains("@")) {
                    return "Enter a valid email";
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: "Email",
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: const Icon(Icons.email, color: Color(0xFF5865F2)),
                  filled: true,
                  fillColor: const Color(0xFF2B2D31),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF5865F2)),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Password
              TextFormField(
                controller: passwordController,
                obscureText: obscurePass,
                style: const TextStyle(color: Colors.white),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Password is required";
                  }
                  var missing = <String>[];
                  if (value.length < 8) missing.add("8+ characters");
                  if (!RegExp(r"[A-Z]").hasMatch(value)) missing.add("1 uppercase letter");
                  if (!RegExp(r"[a-z]").hasMatch(value)) missing.add("1 lowercase letter");
                  if (!RegExp(r"[0-9]").hasMatch(value)) missing.add("1 number");
                  if (missing.isNotEmpty) {
                    return "Password must include: ${missing.join(', ')}";
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: "Password",
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: const Icon(Icons.lock, color: Color(0xFF5865F2)),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscurePass = !obscurePass;
                      });
                    },
                    icon: Icon(
                      obscurePass ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF2B2D31),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF5865F2)),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Confirm Password
              TextFormField(
                controller: confirmpassController,
                obscureText: obscureConfirm,
                style: const TextStyle(color: Colors.white),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please confirm your password";
                  }
                  if (value != passwordController.text) {
                    return "Passwords do not match";
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: "Confirm Password",
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF5865F2)),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscureConfirm = !obscureConfirm;
                      });
                    },
                    icon: Icon(
                      obscureConfirm ? Icons.visibility_off : Icons.visibility,
                      color: Colors.grey,
                    ),
                  ),
                  filled: true,
                  fillColor: const Color(0xFF2B2D31),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF5865F2)),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Birthdate
              TextFormField(
                controller: birthdateController,
                readOnly: true,
                style: const TextStyle(color: Colors.white),
                onTap: pickDate,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Birthdate is required";
                  }
                  return null;
                },
                decoration: InputDecoration(
                  labelText: "Birthdate",
                  labelStyle: TextStyle(color: Colors.grey[400]),
                  prefixIcon: const Icon(Icons.cake, color: Color(0xFF5865F2)),
                  filled: true,
                  fillColor: const Color(0xFF2B2D31),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF5865F2)),
                  ),
                ),
              ),
              const SizedBox(height: 15),

              // Privacy policy
              Row(
                children: [
                  Checkbox(
                    value: agreedToPolicy,
                    onChanged: (val) {
                      setState(() {
                        agreedToPolicy = val!;
                      });
                    },
                    activeColor: const Color(0xFF5865F2),
                  ),
                  Expanded(
                    child: Text(
                      "I agree to the Privacy Policy and Terms of Service",
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : registerUser,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5865F2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "Sign Up",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
