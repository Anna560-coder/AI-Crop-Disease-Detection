// ignore_for_file: use_build_context_synchronously

import 'package:ai_crop_disease_detection/Services/auth_services.dart';
import 'package:ai_crop_disease_detection/Theme/app_theme.dart';
import 'package:ai_crop_disease_detection/View/login_screen.dart';
import 'package:ai_crop_disease_detection/View/widgets/auth_header.dart';
import 'package:flutter/material.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();
  TextEditingController nameController = TextEditingController();

  // Self sign-up always creates a Farmer account. Admin and Expert roles are
  // set by an administrator in the Firebase console (enforced by
  // firestore.rules), so there is no role choice on this screen.
  final String selectedRole = "Farmer";
  bool isLoading = false;
  bool isPasswordHidden = true;

  //instance for AuthService for authentication logic
  final AuthServices _authServices = AuthServices();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    nameController.dispose();
    super.dispose();
  }

  // signup function to handle user registration
  void _signup() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

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
    if (!mounted) return;
    setState(() {
      isLoading = false;
    });

    if (result == null) {
      //signup successful: Navigate to loginscreen with success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Your account was created! Please log in."),
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    } else {
      //signup failed: show the (plain-language) error message
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            AuthHeader(height: screenHeight * 0.28),
            AuthPanel(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Create your account",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "It's free. You only need your name, email and a password.",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    //Input for name
                    TextFormField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: "Full name",
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? "Please enter your name"
                          : null,
                    ),
                    const SizedBox(height: 16),
                    //Input for Email
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: "Email address",
                        hintText: "e.g. name@gmail.com",
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) {
                        final email = value?.trim() ?? "";
                        if (email.isEmpty) {
                          return "Please enter your email address";
                        }
                        if (!email.contains('@') || !email.contains('.')) {
                          return "Please enter a valid email, e.g. name@gmail.com";
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    //Input for Password
                    TextFormField(
                      controller: passwordController,
                      obscureText: isPasswordHidden,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: "Password",
                        helperText: "At least 6 characters",
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: isPasswordHidden
                              ? "Show password"
                              : "Hide password",
                          onPressed: () {
                            setState(() {
                              isPasswordHidden = !isPasswordHidden;
                            });
                          },
                          icon: Icon(
                            isPasswordHidden
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.length < 6
                          ? "Password must be at least 6 characters"
                          : null,
                    ),
                    const SizedBox(height: 16),
                    //Confirm password to catch typing mistakes
                    TextFormField(
                      controller: confirmPasswordController,
                      obscureText: isPasswordHidden,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _signup(),
                      decoration: const InputDecoration(
                        labelText: "Confirm password",
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                      validator: (value) => value != passwordController.text
                          ? "The passwords do not match"
                          : null,
                    ),
                    const SizedBox(height: 16),
                    // Tells the user which account type they are creating.
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.agriculture,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              "You are registering as a farmer.",
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    //Signup button
                    isLoading
                        ? const SizedBox(
                            height: 56,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : ElevatedButton.icon(
                            onPressed: _signup,
                            icon: const Icon(Icons.how_to_reg),
                            label: const Text("Create account"),
                          ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account?",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (_) => LoginScreen()),
                            );
                          },
                          child: const Text("Log in"),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
