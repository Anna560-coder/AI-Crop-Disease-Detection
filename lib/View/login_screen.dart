// ignore_for_file: use_build_context_synchronously

import 'package:ai_crop_disease_detection/Theme/app_theme.dart';
import 'package:ai_crop_disease_detection/View/admin_screen.dart';
import 'package:ai_crop_disease_detection/View/agriculture_expert_screen.dart';
import 'package:ai_crop_disease_detection/View/farmer_screen.dart';
import 'package:ai_crop_disease_detection/View/onboarding_screen.dart';
import 'package:ai_crop_disease_detection/View/signup_screen.dart';
import 'package:ai_crop_disease_detection/View/widgets/auth_header.dart';
import 'package:flutter/material.dart';

import '../Services/auth_services.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  bool isPasswordHidden = true;
  //instance for AuthService for authentication logic
  final AuthServices _authServices = AuthServices();

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void login() async {
    //check the fields are filled in before contacting firebase
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() {
      isLoading = true;
    });

    //call login method from authservice with user inputs
    String? result = await _authServices.login(
      email: emailController.text,
      password: passwordController.text,
    );
    if (!mounted) return;
    setState(() {
      isLoading = false;
    });
    //Navigate based on the role or show the error message.
    //Roles are compared case-insensitively ("Expert" and "expert" both work).
    final role = result?.toLowerCase();
    if (role == "admin") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AdminScreen()),
      );
    } else if (role == "farmer") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => FarmerScreen()),
      );
    } else if (role == "expert") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AgricultureExpertScreen()),
      );
    } else {
      //login failed: show the (plain-language) error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result ?? "Login failed. Please try again.")),
      );
    }
  }

  Future<void> forgotPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Type your email address above first, then tap \"Forgot password?\"",
          ),
        ),
      );
      return;
    }

    final error = await _authServices.resetPassword(email);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error ??
              "We sent a password reset link to $email. Check your email inbox.",
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            AuthHeader(height: screenHeight * 0.36),
            AuthPanel(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      "Welcome back",
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Log in to check the health of your crops.",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    //Input Email
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                        labelText: "Email address",
                        hintText: "e.g. name@gmail.com",
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? "Please enter your email address"
                          : null,
                    ),
                    const SizedBox(height: 16),
                    //Input Password
                    TextFormField(
                      controller: passwordController,
                      obscureText: isPasswordHidden,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => login(),
                      autofillHints: const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: "Password",
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
                      validator: (value) => value == null || value.isEmpty
                          ? "Please enter your password"
                          : null,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: isLoading ? null : forgotPassword,
                        child: const Text("Forgot password?"),
                      ),
                    ),
                    const SizedBox(height: 4),
                    //Login Button
                    isLoading
                        ? const SizedBox(
                            height: 56,
                            child: Center(child: CircularProgressIndicator()),
                          )
                        : ElevatedButton.icon(
                            onPressed: login,
                            icon: const Icon(Icons.login),
                            label: const Text("Log in"),
                          ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            "New to ${AppStrings.appName}?",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => SignupScreen()),
                        );
                      },
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text("Create a free account"),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const OnboardingScreen(openedFromApp: true),
                          ),
                        );
                      },
                      icon: const Icon(Icons.help_outline),
                      label: const Text("How does this app work?"),
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
