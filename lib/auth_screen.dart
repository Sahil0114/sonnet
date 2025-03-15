import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback showPromptScreen;
  const AuthScreen({super.key, required this.showPromptScreen});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    if (_isSignUp) {
      final error = await _signUp(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });

      if (error == null) {
        setState(() {
          _isSignUp = false;
          _errorMessage = 'Account created! Please sign in.';
        });
        _passwordController.clear();
      }
    } else {
      final isValid = await _signIn(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (isValid) {
        setState(() {
          _isLoading = false;
          _errorMessage = null;
        });
        widget.showPromptScreen();
      } else {
        final error = await _getErrorMessage(
          _usernameController.text.trim(),
          _passwordController.text,
        );
        setState(() {
          _isLoading = false;
          _errorMessage = error;
        });
      }
    }
  }

  Future<bool> _signIn(String username, String password) async {
    // Check default credentials
    if (username == 'test' && password == 'test1') {
      return true;
    }

    // Check stored credentials
    final prefs = await SharedPreferences.getInstance();
    final storedCredentials = prefs.getStringList('user_credentials') ?? [];

    for (var credential in storedCredentials) {
      final parts = credential.split(':');
      if (parts.length == 2 && parts[0] == username) {
        return parts[1] == password;
      }
    }

    return false;
  }

  Future<String?> _signUp(String username, String password) async {
    if (username.isEmpty || password.isEmpty) {
      return 'Username and password cannot be empty';
    }

    if (username == 'test') {
      return 'Username already exists';
    }

    final prefs = await SharedPreferences.getInstance();
    final storedCredentials = prefs.getStringList('user_credentials') ?? [];

    for (var credential in storedCredentials) {
      final parts = credential.split(':');
      if (parts.length == 2 && parts[0] == username) {
        return 'Username already exists';
      }
    }

    storedCredentials.add('$username:$password');
    await prefs.setStringList('user_credentials', storedCredentials);
    return null;
  }

  Future<String> _getErrorMessage(String username, String password) async {
    if (username.isEmpty) {
      return 'Please enter username';
    }
    if (password.isEmpty) {
      return 'Please enter password';
    }
    if (username != 'test') {
      return 'Incorrect username';
    }
    if (password != 'test1') {
      return 'Incorrect password';
    }
    return 'Invalid credentials';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF330000),
              Color(0xFF000000),
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.only(top: 40.0),
                child: Stack(
                  children: [
                    Container(
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height * 0.3,
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage(
                            "assets/images/sonnet.png",
                          ),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        padding: const EdgeInsets.all(5.0),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFFFFFFFF),
                            width: 0.4,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          height: 90.0,
                          width: 90.0,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFFFFFF),
                            shape: BoxShape.circle,
                            image: DecorationImage(
                              image: AssetImage(
                                "assets/images/sonnetlogo.png",
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Text(
                        _isSignUp ? 'Create Account' : 'Welcome Back!',
                        style: GoogleFonts.inter(
                          fontSize: 24.0,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _errorMessage!.contains('created')
                                ? Colors.green.withOpacity(0.1)
                                : Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Text(
                            _errorMessage!,
                            style: GoogleFonts.inter(
                              color: _errorMessage!.contains('created')
                                  ? Colors.green
                                  : Colors.red,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      const SizedBox(height: 30),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: TextField(
                          controller: _usernameController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Username',
                            hintStyle:
                                TextStyle(color: Colors.white.withOpacity(0.5)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: TextField(
                          controller: _passwordController,
                          obscureText: true,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Password',
                            hintStyle:
                                TextStyle(color: Colors.white.withOpacity(0.5)),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),
                      GestureDetector(
                        onTap: _isLoading ? null : _handleSignIn,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFCCCC),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.black,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    _isSignUp ? 'Sign Up' : 'Sign In',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _isSignUp
                                ? "Already have an account? "
                                : "Don't have an account? ",
                            style: GoogleFonts.inter(
                              color: Colors.white.withOpacity(0.7),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _isSignUp = !_isSignUp;
                                _errorMessage = null;
                                _passwordController.clear();
                              });
                            },
                            child: Text(
                              _isSignUp ? 'Sign In' : 'Sign Up',
                              style: GoogleFonts.inter(
                                color: const Color(0xFFFFCCCC),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
