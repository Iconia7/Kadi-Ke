import 'package:flutter/material.dart';
import '../services/custom_auth_service.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();

  // Login controllers
  final _loginUsernameController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // Register controllers
  final _registerUsernameController = TextEditingController();
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmPasswordController = TextEditingController();


  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _errorMessage = null;
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _registerUsernameController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();

    _registerConfirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await CustomAuthService().login(
        _loginUsernameController.text.trim(),
        _loginPasswordController.text,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen()),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleRegister() async {
    if (!_registerFormKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await CustomAuthService().register(
        _registerUsernameController.text.trim(),
        _registerPasswordController.text,
        email: _registerEmailController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen()),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await CustomAuthService().signInWithGoogle();

      if (!mounted) return;
      if (CustomAuthService().isAuthenticated) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeScreen()),
        );
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

    @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1E293B),
              Color(0xFF0F172A),
              Color(0xFF1E1B4B),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Game Logo
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF00E5FF).withOpacity(0.2),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/Kadi.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Welcome',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 4,
                      shadows: [
                        Shadow(color: Color(0xFF00E5FF).withOpacity(0.5), blurRadius: 15)
                      ]
                    ),
                  ),
                  SizedBox(height: 40),

                  // Glassmorphism Card
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                      boxShadow: [
                        BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10))
                      ]
                    ),
                    child: Column(
                      children: [
                        // Tabs
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black26,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              indicator: BoxDecoration(
                                color: Color(0xFF00E5FF).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Color(0xFF00E5FF).withOpacity(0.5))
                              ),
                              labelColor: Color(0xFF00E5FF),
                              unselectedLabelColor: Colors.white54,
                              dividerColor: Colors.transparent,
                              labelStyle: TextStyle(fontWeight: FontWeight.bold),
                              tabs: const [
                                Tab(text: 'SIGN IN'),
                                Tab(text: 'REGISTER'),
                              ],
                            ),
                          ),
                        ),

                        // Error message
                        if (_errorMessage != null)
                          Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.error_outline, color: Colors.redAccent),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Fixed height for TabBarView to prevent overflow
                        SizedBox(
                           height: 400,
                           child: TabBarView(
                             controller: _tabController,
                             children: [
                               _buildLoginForm(),
                               _buildRegisterForm(),
                             ],
                           ),
                        ),
                        
                        // Google Login Button
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Divider(color: Colors.white12)),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text('OR', style: TextStyle(color: Colors.white24, fontSize: 12)),
                                  ),
                                  Expanded(child: Divider(color: Colors.white12)),
                                ],
                              ),
                              SizedBox(height: 20),
                              OutlinedButton(
                                onPressed: _isLoading ? null : _handleGoogleLogin,
                                style: OutlinedButton.styleFrom(
                                  fixedSize: Size(double.maxFinite, 56),
                                  side: BorderSide(color: Colors.white24),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  backgroundColor: Colors.white.withOpacity(0.05),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.network(
                                      'https://cdn1.iconfinder.com/data/icons/google-s-logo/150/Google_Icons-09-512.png',
                                      height: 24,
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      'SIGN IN WITH GOOGLE',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

Widget _buildLoginForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _loginFormKey,
        child: Column(
          children: [
            SizedBox(height: 20),
            _buildTextField(
               controller: _loginUsernameController,
               label: 'Username',
               icon: Icons.person_outline,
               autofillHints: [AutofillHints.username],
            ),
            SizedBox(height: 20),
            _buildTextField(
               controller: _loginPasswordController,
               label: 'Password',
               icon: Icons.lock_outline,
               isPassword: true,
               autofillHints: [AutofillHints.password],
            ),
            SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPasswordDialog,
                child: Text('Forgot Password?', style: TextStyle(color: Color(0xFF00E5FF))),
              ),
            ),
            SizedBox(height: 20),
            _buildActionButton('ENTER GAME', _isLoading ? null : _handleLogin),
          ],

        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _registerFormKey,
        child: Column(
          children: [
            _buildTextField(
               controller: _registerUsernameController,
               label: 'Username',
               icon: Icons.person_outline,
               autofillHints: [AutofillHints.newUsername],
            ),
            SizedBox(height: 16),
            _buildTextField(
               controller: _registerEmailController,
               label: 'Email Address',
               icon: Icons.email_outlined,
               autofillHints: [AutofillHints.email],
               validator: (val) => val == null || !val.contains('@') ? 'Invalid Email' : null,
            ),
            SizedBox(height: 16),
            _buildTextField(
               controller: _registerPasswordController,
               label: 'Password',
               icon: Icons.lock_outline,
               isPassword: true,
               autofillHints: [AutofillHints.newPassword],
            ),
            SizedBox(height: 16),
            _buildTextField(
               controller: _registerConfirmPasswordController,
               label: 'Confirm Password',
               icon: Icons.lock_outline,
               isPassword: true,
               validator: (val) => val != _registerPasswordController.text ? 'Passwords do not match' : null,
               autofillHints: [AutofillHints.newPassword],
            ),
            SizedBox(height: 30),
            _buildActionButton('CREATE ACCOUNT', _isLoading ? null : _handleRegister),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
     required TextEditingController controller, 
     required String label, 
     required IconData icon, 
     bool isPassword = false,
     String? Function(String?)? validator,
     Iterable<String>? autofillHints,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      autofillHints: autofillHints,
      style: TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Color(0xFF00E5FF)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white24),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Color(0xFF00E5FF)),
        ),
        filled: true,
        fillColor: Colors.black12,
      ),
      validator: validator ?? (value) {
        if (value == null || value.trim().isEmpty) return 'Required';
        return null;
      },
    );
  }

  Widget _buildActionButton(String text, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF00E5FF),
          foregroundColor: Colors.black,
          shadowColor: Color(0xFF00E5FF).withOpacity(0.5),
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading 
          ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
          : Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
      ),
    );
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF0F172A),
        title: Text('Reset Password', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter your email to receive a reset code.', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 20),
            TextField(
              controller: emailController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E5FF))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            child: Text('Send Code', style: TextStyle(color: Color(0xFF00E5FF))),
            onPressed: () async {
              Navigator.pop(context);
              if (emailController.text.trim().isEmpty) return;
              
              setState(() => _isLoading = true);
              try {
                final msg = await CustomAuthService().forgotPassword(emailController.text.trim());
                if (!mounted) return;
                
                // Show success and ask for token
                _showResetTokenDialog(emailController.text.trim(), msg);
              } catch (e) {
                setState(() {
                  _errorMessage = e.toString().replaceAll('Exception: ', '');
                  _isLoading = false;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showResetTokenDialog(String email, String message) async {
    final tokenController = TextEditingController();
    final passwordController = TextEditingController();
    
    // Auto-fill token if present in debug message (for dev convenience)
    if (message.contains('Debug Code: ')) {
       tokenController.text = message.split('Debug Code: ').last.trim();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF0F172A),
        title: Text('Enter Reset Code', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: TextStyle(color: Colors.greenAccent, fontSize: 12)),
            SizedBox(height: 20),
            TextField(
              controller: tokenController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: 'Reset Code', labelStyle: TextStyle(color: Colors.white54)),
            ),
            SizedBox(height: 10),
            TextField(
              controller: passwordController,
              obscureText: true,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(labelText: 'New Password', labelStyle: TextStyle(color: Colors.white54)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => setState(() => _isLoading = false), child: Text('Cancel', style: TextStyle(color: Colors.white54))),
          TextButton(
            child: Text('Reset Password', style: TextStyle(color: Color(0xFF00E5FF))),
            onPressed: () async {
              Navigator.pop(context);
              try {
                await CustomAuthService().resetPassword(email, tokenController.text.trim(), passwordController.text);
                if (!mounted) return;
                setState(() {
                   _isLoading = false;
                   _errorMessage = "Password Reset Successful! Please Login.";
                   _tabController.animateTo(0); // Switch to Login tab
                });
              } catch (e) {
                setState(() {
                   _errorMessage = e.toString().replaceAll('Exception: ', '');
                   _isLoading = false;
                });
              }
            },
          ),
        ],
      ),
    );
  }
}