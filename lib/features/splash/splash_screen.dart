import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFF), Color(0xFFEFF4FF)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 4),
              Container(
                width: 132,
                height: 132,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(34),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x180B4FB8),
                      blurRadius: 32,
                      offset: Offset(0, 16),
                    ),
                  ],
                ),
                child: SvgPicture.asset('assets/branding/neizami_mark.svg'),
              ),
              const SizedBox(height: 24),
              const Text(
                'NEIZAMI',
                style: TextStyle(
                  color: Color(0xFF0B4FB8),
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ONE PLATFORM. COMPLETE CONTROL.',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
              ),
              const Spacer(flex: 5),
              const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const SizedBox(height: 18),
              const Text(
                'جاري تجهيز مساحة العمل',
                style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 34),
            ],
          ),
        ),
      ),
    );
  }
}
