import 'package:flutter/material.dart';
import 'dart:math';


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
                    colors: [
                      Color(0xFFFF6A00),
                      Color(0xFFFFE100)
                    ],
                  ),
                ),
              ),
            ),

            //card
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
                          transform: Matrix4.identity()
                            ..setEntry(3, 2, 0.001)   // efek perspektif
                            ..rotateY(rotationY),
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


            // Bottom indicator
            Positioned(
              left: 0,
              bottom: 10,
              child: Container(
                width: screenWidth,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 134,
                      height: 5,
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
          'Join us and start creating amazing events!\nIt only takes a minute.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.black,
            fontSize: 13,
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
        ),
        const SizedBox(height: 20),
        _buildInputField(
          label: 'Password',
          controller: passwordController,
          hintText: 'Type here',
          obscureText: true,
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
          hintText: 'Type here',
        ),
        const SizedBox(height: 15),
        _buildInputField(
          label: 'Email',
          controller: signupEmailController,
          hintText: 'Type here',
        ),
        const SizedBox(height: 15),
        _buildInputField(
          label: 'Password',
          controller: signupPasswordController,
          hintText: 'Type here',
          obscureText: true,
        ),
        const SizedBox(height: 15),
        _buildInputField(
          label: 'Confirm Password',
          controller: confirmPasswordController,
          hintText: 'Type here',
          obscureText: true,
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
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
          padding: const EdgeInsets.all(14),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: 2,
                color: const Color(0xFFFFE100),
              ),
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: obscureText,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: 'Poppins',
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: const Color(0xFF616161),
                fontSize: 13,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: () {
        print('Login tapped');
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        decoration: ShapeDecoration(
          color: const Color(0xFFFFE100),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
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
      onTap: () {
        print('Sign Up tapped');
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
        decoration: ShapeDecoration(
          color: const Color(0xFFFFE100),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
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
              gradient: LinearGradient(
                colors: [
                  Color(0x000000),
                  Color(0xFFFF6A00)
                ],
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'Log in with',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w500,
              height: 1.69,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [
                    Color(0xFFFF6A00),
                    Color(0x000000)
                ],
            ),
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
        // Google Sign In Button
        GestureDetector(
          onTap: () {
            print('Google Sign In tapped');
          },
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
        // Facebook Sign In Button
        GestureDetector(
          onTap: () {
            print('Facebook Sign In tapped');
          },
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white, // Ubah ke white untuk Facebook juga
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
                'assets/image/IconFacebook.png', // Path ke gambar Facebook icon
                width: 24,
                height: 24,
                fit: BoxFit.contain,
              ),
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
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w500,
              height: 1.69,
            ),
          ),
          Text(
            'Sign Up',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFFFF6A00),
              fontSize: 13,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w500,
              height: 1.69,
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
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w500,
              height: 1.69,
            ),
          ),
          Text(
            'Log In',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFFFF6A00),
              fontSize: 13,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w500,
              height: 1.69,
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