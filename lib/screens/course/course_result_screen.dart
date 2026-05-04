import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../map_screen.dart';
import '../../widgets/bottom_nav.dart';

class CourseResultScreen extends StatelessWidget {
  const CourseResultScreen({super.key});

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
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text('←', style: TextStyle(fontSize: 22, color: Color(0xFF2D1A20))),
                  ),
                  Text(
                    '추천 코스',
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
                    child: const Center(child: Text('♡', style: TextStyle(fontSize: 16))),
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

                    // ── 코스 헤더 배너 ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE8556D), Color(0xFFC03650)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '홍대 · 2인 · 3~4시간',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '봄날 홍대 감성 데이트',
                            style: GoogleFonts.playfairDisplay(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '☕ 카페 · 🍽️ 맛집 · 🌸 산책',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 코스 일정 ──
                    Text(
                      '코스 일정'.toUpperCase(),
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF9B7E85),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _StepItem(
                      number: 1,
                      name: '☕ 연남동 어니언',
                      info: '카페 · 09:00 ~ 10:30 · 1.5h',
                      tags: ['브런치', '감성'],
                      isLast: false,
                    ),
                    _StepItem(
                      number: 2,
                      name: '🍽️ 홍대 뇨끼 식당',
                      info: '레스토랑 · 11:00 ~ 12:30 · 1.5h',
                      tags: ['파스타', '데이트'],
                      isLast: false,
                    ),
                    _StepItem(
                      number: 3,
                      name: '🎨 KT&G 상상마당',
                      info: '전시 · 13:00 ~ 14:30 · 1.5h',
                      tags: ['전시', '문화'],
                      isLast: false,
                    ),
                    _StepItem(
                      number: 4,
                      name: '🌅 망원 한강공원',
                      info: '공원 · 15:00 ~ 17:00 · 2h',
                      tags: ['한강', '피크닉'],
                      isLast: true,
                    ),
                    const SizedBox(height: 20),

                    // ── 지도 버튼 ──
                    GestureDetector(
                      onTap: () {Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const MapScreen()),
  );},
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
                          '🗺️ 지도에서 보기',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── 공유 버튼 ──
                    GestureDetector(
                      onTap: () {},
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: const Color(0xFFF7C5CD),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          '친구와 공유하기',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFE8556D),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── 바텀 네비게이션 ──
            const BottomNav(currentIndex: 1),
          ],
        ),
      ),
    );
  }
}

// ── 코스 스텝 아이템 ──
class _StepItem extends StatelessWidget {
  final int number;
  final String name;
  final String info;
  final List<String> tags;
  final bool isLast;

  const _StepItem({
    required this.number,
    required this.name,
    required this.info,
    required this.tags,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 번호 + 연결선 ──
        Column(
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                color: const Color(0xFFE8556D),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  '$number',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 36,
                margin: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF7C5CD), Color(0xFFFDF0F2)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),

        // ── 카드 ──
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFDF0F2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF2D1A20),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  info,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: const Color(0xFF9B7E85),
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 4,
                  children: tags.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7C5CD),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tag,
                      style: GoogleFonts.dmSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFC03650),
                      ),
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

