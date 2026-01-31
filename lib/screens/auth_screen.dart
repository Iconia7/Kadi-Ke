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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1F38), Color(0xFF0F111A)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / Branding
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                         BoxShadow(color: Color(0xFF00E5FF).withOpacity(0.4), blurRadius: 20, spreadRadius: 5)
                      ]
                    ),
                    child: Icon(Icons.style, size: 60, color: Color(0xFF00E5FF)),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'KADI KE',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 3,
                      shadows: [Shadow(color: Color(0xFF00E5FF), blurRadius: 10)]
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

                        // Tab Views container using AnimatedSwitcher or fixed height? 
                        // Using AnimatedSize implicitly via column invalidation or fixed height?
                        // Let's rely on standard constraints.
                        SizedBox(
                           height: 400, // Fixed height for form area
                           child: TabBarView(
                             controller: _tabController,
                             children: [
                               _buildLoginForm(),
                               _buildRegisterForm(),
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
               icon: Icons.person_outline
            ),
            SizedBox(height: 20),
            _buildTextField(
               controller: _loginPasswordController,
               label: 'Password',
               icon: Icons.lock_outline,
               isPassword: true
            ),
            SizedBox(height: 40),
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
               icon: Icons.person_outline
            ),
            SizedBox(height: 16),
            _buildTextField(
               controller: _registerPasswordController,
               label: 'Password',
               icon: Icons.lock_outline,
               isPassword: true
            ),
            SizedBox(height: 16),
            _buildTextField(
               controller: _registerConfirmPasswordController,
               label: 'Confirm Password',
               icon: Icons.lock_outline,
               isPassword: true,
               validator: (val) => val != _registerPasswordController.text ? 'Passwords do not match' : null
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
     String? Function(String?)? validator
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
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
}
