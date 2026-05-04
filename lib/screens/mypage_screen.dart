import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/bottom_nav.dart';

class MypageScreen extends StatelessWidget {
  const MypageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF7F5),
      body: SafeArea(
        child: Column(
          children: [
            // ── 상단바 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'MY 페이지',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      color: const Color(0xFF2D1A20),
                    ),
                  ),
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDF0F2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(child: Text('⚙️', style: TextStyle(fontSize: 16))),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [

                    // ── 프로필 카드 ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE8556D), Color(0xFFC03650)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(36),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Center(
                              child: Text('👤', style: TextStyle(fontSize: 32)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '이윤서',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'yunseo@email.com',
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // 통계
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatItem(label: '저장한 코스', value: '12'),
                              _StatItem(label: '방문한 장소', value: '34'),
                              _StatItem(label: '게시물', value: '8'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 저장한 코스 ──
                    _SectionTitle(title: '저장한 코스'),
                    const SizedBox(height: 10),
                    _SavedCourseCard(
                      emoji: '🌸',
                      color1: const Color(0xFFF7C5CD),
                      color2: const Color(0xFFC5D5F7),
                      title: '봄날 홍대 산책 코스',
                      sub: '3곳 · 4시간',
                    ),
                    _SavedCourseCard(
                      emoji: '🍃',
                      color1: const Color(0xFFC5F7D5),
                      color2: const Color(0xFFF7F0C5),
                      title: '연남동 브런치 데이트',
                      sub: '3곳 · 3시간',
                    ),
                    const SizedBox(height: 20),

                    // ── 메뉴 목록 ──
                    _SectionTitle(title: '설정'),
                    const SizedBox(height: 10),
                    _MenuItem(icon: '👥', label: '친구 관리'),
                    _MenuItem(icon: '🔔', label: '알림 설정'),
                    _MenuItem(icon: '🔒', label: '개인정보 보호'),
                    _MenuItem(icon: '📞', label: '고객센터'),
                    _MenuItem(icon: '🚪', label: '로그아웃', isRed: true),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            const BottomNav(currentIndex: 4),
          ],
        ),
      ),
    );
  }
}

// ── 통계 아이템 ──
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.playfairDisplay(
            fontSize: 22,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 10,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}

// ── 섹션 타이틀 ──
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF9B7E85),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── 저장된 코스 카드 ──
class _SavedCourseCard extends StatelessWidget {
  final String emoji;
  final Color color1;
  final Color color2;
  final String title;
  final String sub;
  const _SavedCourseCard({
    required this.emoji,
    required this.color1,
    required this.color2,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF0F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color1, color2]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 13,
                    color: const Color(0xFF2D1A20),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sub,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: const Color(0xFF9B7E85),
                  ),
                ),
              ],
            ),
          ),
          const Text('→', style: TextStyle(color: Color(0xFF9B7E85))),
        ],
      ),
    );
  }
}

// ── 메뉴 아이템 ──
class _MenuItem extends StatelessWidget {
  final String icon;
  final String label;
  final bool isRed;
  const _MenuItem({required this.icon, required this.label, this.isRed = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF0F2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: isRed ? const Color(0xFFE8556D) : const Color(0xFF2D1A20),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Text(
            '→',
            style: TextStyle(
              color: isRed ? const Color(0xFFE8556D) : const Color(0xFF9B7E85),
            ),
          ),
        ],
      ),
    );
  }
}