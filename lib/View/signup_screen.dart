// ignore_for_file: use_build_context_synchronously

import 'package:ai_crop_disease_detection/Services/auth_services.dart';
import 'package:ai_crop_disease_detection/View/login_screen.dart';
import 'package:flutter/material.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  TextEditingController surnameController = TextEditingController();
  TextEditingController farmnameController = TextEditingController();
  TextEditingController farmregisternumberController = TextEditingController();
  String selectedRole = "Farmer";
  bool isLoading = false;
  bool isPasswordHidden = true;

  //instance for AuthService for authentication logic
  final AuthServices _authServices = AuthServices();

  // signup function to handle user registration
  void _signup() async {
    setState(() {
      isLoading = true;
    });
    //call signup method from authservices with user inputs
    String? result = await _authServices.signup(
      name: nameController.text,
      email: emailController.text,
      password: passwordController.text,
      role: selectedRole,
    );
    setState(() {
      isLoading = false;
    });

    if (result == null) {
      //signup successful: Navigate to loginscreen with success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Signup Successfully! Now Turn to login")),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    } else {
      //signup failed: show the error message
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Signup Failed $result")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Image.asset("assets/register_user.png"),
            SizedBox(height: 20),
            //Input for name
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: "Name",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 20),
            //Input for Email
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 15),
            //Input for Password
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      isPasswordHidden = !isPasswordHidden;
                    });
                  },
                  icon: Icon(
                    isPasswordHidden ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              obscureText: isPasswordHidden,
            ),
            SizedBox(height: 15),

            //Dropdown for selecting the role
            DropdownButtonFormField(
              initialValue: selectedRole,
              decoration: InputDecoration(
                labelText: "Role",
                border: OutlineInputBorder(),
              ),
              items: ["Admin", "Farmer"].map((role) {
                return DropdownMenuItem(value: role, child: Text(role));
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedRole = newValue!;
                });
              },
            ),
            SizedBox(height: 20),
            //Signup button
            isLoading
                ? Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _signup,
                      child: Text("Signup"),
                    ),
                  ),
            SizedBox(height: 15),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  "Already have an account? ",
                  style: TextStyle(fontSize: 18),
                ),
                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => LoginScreen()),
                    );
                  },
                  child: Text(
                    "Login here",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ],
            ),
            //Login Button
          ],
        ),
      ),
    );
  }
}
