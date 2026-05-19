import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/bottom_nav.dart';
import 'course/course_screen.dart';
import 'mypage_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
                    '안녕하세요 💕',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      color: const Color(0xFF2D1A20),
                    ),
                  ),
                  Stack(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDF0F2),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Center(child: Text('🔔', style: TextStyle(fontSize: 16))),
                      ),
                      Positioned(
                        top: 0, right: 0,
                        child: Container(
                          width: 9, height: 9,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8556D),
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── 스크롤 영역 ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 배너 ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE8556D), Color(0xFFC03650)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '오늘의 추천 코스',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 17,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '홍대 → 연남동 → 망원 한강 3시간 코스',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // ── 코스 보기 버튼 연결 ──
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CourseScreen()),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '코스 보기 →',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 친구 목록 ──
                    _SectionTitle(title: '함께하는 친구'),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 70,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          _FriendAvatar(name: '지민', initial: '지'),
                          _FriendAvatar(name: '수아', initial: '수'),
                          _FriendAvatar(name: '현우', initial: '현'),
                          _FriendAvatar(name: '태연', initial: '태'),
                          // ── 친구 추가 버튼 연결 ──
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const MypageScreen()),
                              );
                            },
                            child: _FriendAvatarAdd(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 최근 코스 ──
                    _SectionTitle(title: '최근 저장한 코스'),
                    const SizedBox(height: 10),
                    _CourseCard(
                      emoji: '🌸',
                      color1: const Color(0xFFF7C5CD),
                      color2: const Color(0xFFC5D5F7),
                      title: '봄날 홍대 산책 코스',
                      sub: '카페 → 전시 → 한강  ·  3곳  ·  4시간',
                    ),
                    const SizedBox(height: 10),
                    _CourseCard(
                      emoji: '🍃',
                      color1: const Color(0xFFC5F7D5),
                      color2: const Color(0xFFF7F0C5),
                      title: '연남동 브런치 데이트',
                      sub: '식사 → 카페 → 쇼핑  ·  3곳  ·  3시간',
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── 바텀 네비게이션 ──
            const BottomNav(currentIndex: 0),
          ],
        ),
      ),
    );
  }
}

// ── 섹션 타이틀 ──
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: const Color(0xFF9B7E85),
        letterSpacing: 0.8,
      ),
    );
  }
}

// ── 친구 아바타 ──
class _FriendAvatar extends StatelessWidget {
  final String name;
  final String initial;
  const _FriendAvatar({required this.name, required this.initial});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Column(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF7C5CD),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: const Color(0xFFE8556D), width: 2),
            ),
            child: Center(
              child: Text(
                initial,
                style: GoogleFonts.dmSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFC03650),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(name, style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF9B7E85))),
        ],
      ),
    );
  }
}

// ── 친구 추가 아바타 ──
class _FriendAvatarAdd extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Column(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF2E8E4),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(
                color: const Color(0xFF9B7E85),
                width: 1.5,
              ),
            ),
            child: const Center(
              child: Text('+', style: TextStyle(fontSize: 20, color: Color(0xFF9B7E85))),
            ),
          ),
          const SizedBox(height: 4),
          Text('추가', style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF9B7E85))),
        ],
      ),
    );
  }
}

// ── 코스 카드 ──
class _CourseCard extends StatelessWidget {
  final String emoji;
  final Color color1;
  final Color color2;
  final String title;
  final String sub;
  const _CourseCard({
    required this.emoji,
    required this.color1,
    required this.color2,
    required this.title,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFDF0F2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 90,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color1, color2],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 30))),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 14,
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
        ],
      ),
    );
  }
}