import 'package:flutter/material.dart';

import '../../../core/app_info.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const background = Color(0xFF17365D);

    return const Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          child: Column(
            children: [
              Spacer(),
              _SplashLogo(),
              SizedBox(height: 22),
              Text(
                AppInfo.appName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'مساعدك اليومي للجدول والحصص',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFE7EDF5),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 30),
              SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFFD9AC5F),
                ),
              ),
              Spacer(),
              Text(
                'إعداد وتطوير: ${AppInfo.developerName}',
                style: TextStyle(
                  color: Color(0xFFD9E1EC),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplashLogo extends StatelessWidget {
  const _SplashLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 142,
      height: 142,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(34),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Image.asset(
          'assets/images/app_icon.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
