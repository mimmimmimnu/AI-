import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// 상단 import 추가
import 'home_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF7F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

              // ── 로고 ──
              Text(
                '✿ Datefit',
                style: GoogleFonts.playfairDisplay(
                  fontSize: 36,
                  color: const Color(0xFFC03650),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '둘이서 만드는 완벽한 하루',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: const Color(0xFF9B7E85),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 48),

              // ── 이메일 입력 ──
              _InputField(hint: '이메일', obscure: false),
              const SizedBox(height: 12),

              // ── 비밀번호 입력 ──
              _InputField(hint: '비밀번호', obscure: true),
              const SizedBox(height: 20),

              // ── 로그인 버튼 ──
              _PrimaryButton(
                label: '로그인',
                onTap: () {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  },
              ),
              const SizedBox(height: 20),

              // ── 구분선 ──
              Row(
                children: [
                  const Expanded(child: Divider(color: Color(0xFFF2E8E4), thickness: 1.5)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      '또는',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: const Color(0xFF9B7E85),
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: Color(0xFFF2E8E4), thickness: 1.5)),
                ],
              ),
              const SizedBox(height: 20),

              // ── 소셜 로그인 ──
              _SocialButton(label: '🟡  카카오로 계속하기', onTap: () {}),
              const SizedBox(height: 10),
              _SocialButton(label: '🍎  Apple로 계속하기', onTap: () {}),
              const SizedBox(height: 28),

              // ── 회원가입 링크 ──
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '아직 계정이 없으신가요? ',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: const Color(0xFF9B7E85),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Text(
                      '회원가입',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: const Color(0xFFE8556D),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 공통 입력 필드 ──
class _InputField extends StatelessWidget {
  final String hint;
  final bool obscure;
  const _InputField({required this.hint, required this.obscure});

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscure,
      style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF2D1A20)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF9B7E85)),
        filled: true,
        fillColor: const Color(0xFFF2E8E4),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    );
  }
}

// ── 메인 버튼 ──
class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE8556D), Color(0xFFC03650)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ── 소셜 버튼 ──
class _SocialButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SocialButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: const Color(0xFFF2E8E4),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            color: const Color(0xFF2D1A20),
          ),
        ),
      ),
    );
  }
}