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
      body: Stack(
        children: [
          // 배경 식재료들
          Positioned(top: 60, left: 30, child: _FoodEmoji('🥕', 40)),
          Positioned(top: 120, right: 20, child: _FoodEmoji('🥦', 44)),
          Positioned(top: 240, right: 30, child: _FoodEmoji('🍅', 38)),
          Positioned(top: 200, left: 20, child: _FoodEmoji('🥚', 36)),
          Positioned(top: 360, right: 20, child: _FoodEmoji('🧅', 40)),
          Positioned(top: 400, left: 30, child: _FoodEmoji('🍋', 38)),
          Positioned(top: 500, right: 30, child: _FoodEmoji('🌶️', 36)),
          Positioned(top: 520, left: 20, child: _FoodEmoji('🍄', 40)),
          Positioned(top: 640, right: 20, child: _FoodEmoji('🥑', 42)),
          Positioned(top: 660, left: 30, child: _FoodEmoji('🧄', 38)),
          Positioned(top: 760, right: 30, child: _FoodEmoji('🫐', 40)),
          Positioned(top: 780, left: 20, child: _FoodEmoji('🍓', 38)),

          // 중앙 로고
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '나만의',
                      style: GoogleFonts.blackHanSans(
                        fontSize: 48,
                        color: const Color(0xFF2D3436),
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      '냉장고',
                      style: GoogleFonts.blackHanSans(
                        fontSize: 48,
                        color: const Color(0xFF4A90D9),
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'AI가 관리하는 스마트 냉장고',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodEmoji extends StatelessWidget {
  final String emoji;
  final double size;

  const _FoodEmoji(this.emoji, this.size);

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.15,
      child: Text(emoji, style: TextStyle(fontSize: size)),
    );
  }
}