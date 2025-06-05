import 'package:flutter/material.dart';
import 'services/firebase_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final userCredential = await FirebaseService.signUpWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        
        if (userCredential.user != null) {
          await FirebaseService.addUserData(userCredential.user!.uid, {
            'email': _emailController.text.trim(),
            'createdAt': DateTime.now().toIso8601String(),
            'setsCompleted': 0,
            'currentXP': 0,
            'currentRank': 'E',
            'lastSetDate': null,
          });

          if (mounted) {
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Container(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Account created successfully!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                backgroundColor: Colors.black,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                duration: Duration(seconds: 1),
              ),
            );

            setState(() {
              _isLoading = false;
            });

            // Immediately navigate back to login page
            Navigator.pop(context);
          }
          return;
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          String errorMessage;
          switch (e.code) {
            case 'email-already-in-use':
              errorMessage = 'An account already exists with this email!';
              break;
            case 'invalid-email':
              errorMessage = 'Invalid email format!';
              break;
            case 'operation-not-allowed':
              errorMessage = 'Email/password accounts are not enabled!';
              break;
            default:
              errorMessage = 'An error occurred: ${e.message}';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage, textAlign: TextAlign.center),
              backgroundColor: Colors.black,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('An unexpected error occurred. Please try again.', textAlign: TextAlign.center),
              backgroundColor: Colors.black,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              margin: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 0, 1, 71),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(30.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: Text(
                        'Register',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 40),
                  _buildInputCard(
                    controller: _emailController,
                    label: 'Email',
                    icon: Icons.email,
                    obscure: false,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter your email';
                      if (!value.contains('@')) return 'Please enter a valid email';
                      return null;
                    },
                  ),
                  SizedBox(height: 20),
                  _buildInputCard(
                    controller: _passwordController,
                    label: 'Password',
                    icon: Icons.lock,
                    obscure: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please enter your password';
                      return null;
                    },
                  ),
                  SizedBox(height: 20),
                  _buildInputCard(
                    controller: _confirmController,
                    label: 'Confirm Password',
                    icon: Icons.lock_outline,
                    obscure: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) return 'Please confirm your password';
                      if (value != _passwordController.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  SizedBox(height: 30),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      textStyle: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _isLoading ? null : _handleRegister,
                    child: _isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text('Register'),
                  ),
                  SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Already have an account? Login',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputCard({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool obscure,
    required String? Function(String?) validator,
  }) {
    return Card(
      color: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: TextFormField(
          controller: controller,
          obscureText: obscure,
          style: TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
            prefixIcon: Icon(icon, color: Colors.white70),
          ),
          validator: validator,
        ),
      ),
    );
  }
}
