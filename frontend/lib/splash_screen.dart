import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.white,
    body: Center(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/fridge_icon.png', width: 140, height: 140),
              const SizedBox(height: 4),
              Text(
                '나만의 냉장고',
                style: GoogleFonts.jua(
                  fontSize: 65,
                  color: const Color(0xFF4A90D9),
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AI가 관리하는 스마트 냉장고',
                style: GoogleFonts.jua(
                  fontSize: 16,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}