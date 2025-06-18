// login_screen.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '/screens/home_screen.dart'; // Create a basic home screen file


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
      static const routeName = '/login';


  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  // Login controllers
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // Sign up controllers
  final _signupNameController = TextEditingController();
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupConfirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupNameController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupConfirmPasswordController.dispose();
    super.dispose();
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _login() async {
  final email = _loginEmailController.text.trim();
  final password = _loginPasswordController.text;

  if (email.isEmpty || password.isEmpty) {
    _showSnackBar("Please enter email and password");
    return;
  }

  setState(() => _isLoading = true);

  try {
    final response = await Supabase.instance.client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    final user = response.user;

    if (user != null) {
      // Attempt to extract name from user metadata
      final metadata = user.userMetadata;
      String name = 'User';

      if (metadata != null && metadata['name'] != null) {
        name = metadata['name'].toString();
      }

      // Save name in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);

      // Navigate to home screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        ),
      );
    } else {
      _showSnackBar("Login failed. Please try again.");
    }
  } on AuthException catch (e) {
    _showSnackBar(e.message);
  } catch (e) {
    debugPrint("Login Error: $e");
    _showSnackBar("An error occurred. Please try again.");
  } finally {
    setState(() => _isLoading = false);
  }
}

  Future<void> _signup() async {
    final name = _signupNameController.text.trim();
    final email = _signupEmailController.text.trim();
    final password = _signupPasswordController.text;
    final confirmPassword = _signupConfirmPasswordController.text;

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      _showSnackBar("Please fill in all fields");
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar("Passwords do not match");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      if (res.user != null) {
        _showSnackBar("Account created! Check your email to confirm.");
        _tabController.animateTo(0);
      }
    } on AuthException catch (e) {
      _showSnackBar(e.message);
    } catch (_) {
      _showSnackBar("Sign up failed. Try again.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildLoginTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildTextField(
            label: 'Email',
            controller: _loginEmailController,
            hint: 'your@email.com'),
        const SizedBox(height: 16),
        _buildTextField(
            label: 'Password',
            controller: _loginPasswordController,
            obscure: true),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _login,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("Login"),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Flexible(child: Text("Don't have an account? ")),
            GestureDetector(
              onTap: () => _tabController.animateTo(1),
              child:
                  const Text('Sign up', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignupTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        _buildTextField(
            label: 'Name',
            controller: _signupNameController,
            hint: 'Your name'),
        const SizedBox(height: 12),
        _buildTextField(label: 'Email', controller: _signupEmailController),
        const SizedBox(height: 12),
        _buildTextField(
            label: 'Password',
            controller: _signupPasswordController,
            obscure: true),
        const SizedBox(height: 12),
        _buildTextField(
            label: 'Confirm Password',
            controller: _signupConfirmPasswordController,
            obscure: true),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _signup,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("Sign Up"),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            "Check your email to confirm your account.",
            style: TextStyle(color: Colors.grey),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Flexible(child: Text("Already have an account? ")),
            GestureDetector(
              onTap: () => _tabController.animateTo(0),
              child: const Text('Login', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Center(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            elevation: 4,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('NovaCare',
                        style:
                            TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text('Sign in to track your health metrics',
                        style: TextStyle(color: Colors.grey)),
                    const SizedBox(height: 20),
                    TabBar(
                      controller: _tabController,
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Colors.black,
                      tabs: const [Tab(text: 'Login'), Tab(text: 'Sign Up')],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 400,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildLoginTab(),
                          _buildSignupTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
