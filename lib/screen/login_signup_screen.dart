import 'package:flutter/material.dart';
import 'dart:math';
import '../service/auth_service.dart';
import 'landing_page/welcome_screen.dart';
import '../widget/forgot_password_dialog.dart';
import 'home/home_screen.dart';

void main() {
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginScreen(),
    ),
  );
}

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLogin = true;
  bool _isLoading = false;

  bool _obscureLoginPassword = true;
  bool _obscureSignupPassword = true;
  bool _obscureConfirmPassword = true;

  final AuthService _authService = AuthService();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController signupEmailController = TextEditingController();
  final TextEditingController signupPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  void toggleView() {
    setState(() {
      isLogin = !isLogin;
    });
  }

  Future<void> _handleLogin() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      _showErrorDialog('Please fill in all fields');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await _authService.signInWithEmailOrUsername(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      if (result['success']) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen()),
        );
      } else {
        _showErrorDialog(result['error']);
      }
    } catch (e) {
      _showErrorDialog('Login failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignUp() async {
    if (usernameController.text.isEmpty ||
        signupEmailController.text.isEmpty ||
        signupPasswordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      _showErrorDialog('Please fill in all fields');
      return;
    }

    if (signupPasswordController.text != confirmPasswordController.text) {
      _showErrorDialog('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _authService.registerWithEmailAndPassword(
        signupEmailController.text.trim(),
        signupPasswordController.text.trim(),
        usernameController.text.trim(),
      );

      if (result['success']) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => WelcomeScreen()),
        );
      } else {
        _showErrorDialog(result['error'] ?? 'Registration failed');
      }
    } catch (e) {
      _showErrorDialog('Sign up failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }


  void _showProfileSetupDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Profile Setup'),
        content: Text('Account created successfully! Profile setup will complete in the background.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => WelcomeScreen()),
              );
            },
            child: Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            SizedBox(height: 10),
            Text(
              'If this persists, please check your internet connection and try again.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }


  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      final result = await _authService.signInWithGoogle();

      if (result['success']) {

        if (result['isNewUser'] == true) {

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => WelcomeScreen()),
          );
        } else {

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen()),
          );
        }
      } else {
        _showErrorDialog(result['error']);
      }
    } catch (e) {
      _showErrorDialog('Google sign in failed: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Container(
        width: screenWidth,
        height: screenHeight,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: Colors.white),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                width: screenWidth,
                height: screenHeight,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.00, 1.00),
                    radius: 2.22,
                    colors: [Color(0xFFFF6A00), Color(0xFFFFE100)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              bottom: 0,
              child: Container(
                width: screenWidth,
                height: screenHeight * 0.75,
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: 600),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    final rotate = Tween(begin: pi, end: 0.0).animate(animation);
                    return AnimatedBuilder(
                      animation: rotate,
                      child: child,
                      builder: (context, child) {
                        final isUnder = (child?.key != ValueKey(isLogin));
                        final rotationY = isUnder ? min(rotate.value, pi / 2) : rotate.value;
                        return Transform(
                          transform: Matrix4.identity()..setEntry(3, 2, 0.001)..rotateY(rotationY),
                          alignment: Alignment.center,
                          child: child,
                        );
                      },
                    );
                  },
                  child: isLogin
                      ? _buildLoginCard(screenWidth, screenHeight, key: ValueKey(true))
                      : _buildSignupCard(screenWidth, screenHeight, key: ValueKey(false)),
                ),
              ),
            ),
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black54,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFE100)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginCard(double screenWidth, double screenHeight, {Key? key}) {
    return Container(
      key: key,
      width: screenWidth,
      height: screenHeight * 0.75,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(55),
            topRight: Radius.circular(55),
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 51),
          child: Column(
            children: [
              SizedBox(height: 50),
              _buildWelcomeBackHeader(),
              SizedBox(height: 40),
              _buildLoginForm(),
              SizedBox(height: 40),
              _buildLoginButton(),
              SizedBox(height: 30),
              _buildSignInWithDivider(),
              SizedBox(height: 20),
              _buildSocialLoginButtons(),
              SizedBox(height: 20),
              _buildSwitchToSignUp(),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignupCard(double screenWidth, double screenHeight, {Key? key}) {
    return Container(
      key: key,
      width: screenWidth,
      height: screenHeight * 0.75,
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(55),
            topRight: Radius.circular(55),
          ),
        ),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 51),
          child: Column(
            children: [
              SizedBox(height: 50),
              _buildCreateAccountHeader(),
              SizedBox(height: 30),
              _buildSignupForm(),
              SizedBox(height: 30),
              _buildSignupButton(),
              SizedBox(height: 20),
              _buildSignInWithDivider(),
              SizedBox(height: 15),
              _buildSocialLoginButtons(),
              SizedBox(height: 15),
              _buildSwitchToLogin(),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeBackHeader() {
    return Column(
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Welcome',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextSpan(
                text: ' Back',
                style: TextStyle(
                  color: const Color(0xFFFF6A00),
                  fontSize: 20,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 15),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'What event are you making this time?\nTell us ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextSpan(
                text: 'everything!',
                style: TextStyle(
                  color: const Color(0xFFFF6A00),
                  fontSize: 13,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildCreateAccountHeader() {
    return Column(
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Create',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 20,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextSpan(
                text: ' Account',
                style: TextStyle(
                  color: const Color(0xFFFF6A00),
                  fontSize: 20,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 15),
        Text(
          'Join us and start creating amazing events!\nPassword: min 8 chars with letters, numbers & symbols.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        _buildInputField(
          label: 'Username or Email',
          controller: emailController,
          hintText: 'Type here',
          isForLogin: true,
        ),
        const SizedBox(height: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Password',
                  style: TextStyle(
                    color: const Color(0xFF616161),
                    fontSize: 13,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => ForgotPasswordDialog(
                        authService: _authService,
                      ),
                    );
                  },
                  child: Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color: const Color(0xFFFF6A00),
                      fontSize: 12,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: ShapeDecoration(
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    width: 2,
                    color: const Color(0xFFFFE100),
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: passwordController,
                      obscureText: _obscureLoginPassword,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Type here',
                        hintStyle: TextStyle(
                          color: const Color(0xFF616161),
                          fontSize: 11,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() =>
                      _obscureLoginPassword = !_obscureLoginPassword);
                    },
                    child: Icon(
                      _obscureLoginPassword
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSignupForm() {
    return Column(
      children: [
        _buildInputField(
          label: 'Username',
          controller: usernameController,
          hintText: 'Choose your unique username',
          isForLogin: false,
        ),
        const SizedBox(height: 15),
        _buildInputField(
          label: 'Email',
          controller: signupEmailController,
          hintText: 'Type here',
          isForLogin: false,
        ),
        const SizedBox(height: 15),
        _buildInputField(
          label: 'Password',
          controller: signupPasswordController,
          hintText: 'Min 8 chars with letters, numbers & symbols',
          obscureText: _obscureSignupPassword,
          isPassword: true,
          isForLogin: false,
          onToggleVisibility: () {
            setState(() => _obscureSignupPassword = !_obscureSignupPassword);
          },
        ),
        const SizedBox(height: 15),
        _buildInputField(
          label: 'Confirm Password',
          controller: confirmPasswordController,
          hintText: 'Type here',
          obscureText: _obscureConfirmPassword,
          isPassword: true,
          isForLogin: false,
          onToggleVisibility: () {
            setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
          },
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required bool isForLogin,
    bool obscureText = false,
    bool isPassword = false,
    VoidCallback? onToggleVisibility,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF616161),
            fontSize: 13,
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: 2,
                color: const Color(0xFFFFE100),
              ),
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  obscureText: obscureText,
                  style: TextStyle(
                    color: isForLogin ? Colors.white : Colors.black,
                    fontSize: 13,
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: hintText,
                    hintStyle: TextStyle(
                      color: const Color(0xFF616161),
                      fontSize: 11,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              if (isPassword)
                GestureDetector(
                  onTap: onToggleVisibility,
                  child: Icon(
                    obscureText ? Icons.visibility_off : Icons.visibility,
                    color: isForLogin ? Colors.white70 : Colors.black54,
                    size: 20,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _handleLogin,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        decoration: ShapeDecoration(
          color: _isLoading ? Colors.grey : const Color(0xFFFFE100),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        ),
        child: Text(
          'Log In',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
            height: 1.29,
          ),
        ),
      ),
    );
  }

  Widget _buildSignupButton() {
    return GestureDetector(
      onTap: _isLoading ? null : _handleSignUp,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        decoration: ShapeDecoration(
          color: _isLoading ? Colors.grey : const Color(0xFFFFE100),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
        ),
        child: Text(
          'Sign Up',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 17,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
            height: 1.29,
          ),
        ),
      ),
    );
  }

  Widget _buildSignInWithDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(0x000000), Color(0xFFFF6A00)]),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Sign Up with',
            style: TextStyle(
              color: isLogin ? Colors.white : Colors.black,
              fontSize: 13,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFFFF6A00), Color(0x000000)]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSocialLoginButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _isLoading ? null : _handleGoogleSignIn,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                'assets/image/IconGoogle.png',
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
        SizedBox(width: 20),
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.facebook,
              color: Colors.grey.shade600,
              size: 24,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchToSignUp() {
    return GestureDetector(
      onTap: toggleView,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Don\'t have an account? ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            'Sign Up',
            style: TextStyle(
              color: const Color(0xFFFF6A00),
              fontSize: 13,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchToLogin() {
    return GestureDetector(
      onTap: toggleView,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Already have an account? ',
            style: TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            'Log In',
            style: TextStyle(
              color: const Color(0xFFFF6A00),
              fontSize: 13,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    usernameController.dispose();
    signupEmailController.dispose();
    signupPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}