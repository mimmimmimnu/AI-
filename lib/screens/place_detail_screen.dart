import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/bottom_nav.dart';

class PlaceDetailScreen extends StatelessWidget {
  const PlaceDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF7F5),
      body: SafeArea(
        child: Column(
          children: [
            // ── 헤더 이미지 ──
            Container(
              height: 160,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFF7C5CD), Color(0xFFE8AAB5), Color(0xFFD4B5E8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  // 뒤로가기
                  Positioned(
                    top: 12, left: 14,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 34, height: 34,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: const Center(
                          child: Text('←', style: TextStyle(fontSize: 18, color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                  // 찜하기
                  Positioned(
                    top: 12, right: 14,
                    child: Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: const Center(
                        child: Text('♡', style: TextStyle(fontSize: 16, color: Colors.white)),
                      ),
                    ),
                  ),
                  // 장소명
                  Positioned(
                    bottom: 14, left: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '🍽️ 홍대 뇨끼 식당',
                          style: GoogleFonts.playfairDisplay(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '마포구 홍대입구 · 파스타 · 뇨끼',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── 본문 ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── 평점 요약 ──
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDF0F2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          // 평점 숫자
                          Column(
                            children: [
                              Text(
                                '4.5',
                                style: GoogleFonts.playfairDisplay(
                                  fontSize: 28,
                                  color: const Color(0xFFE8556D),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Row(
                                children: List.generate(5, (i) => Text(
                                  '★',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: i < 4
                                        ? const Color(0xFFE8556D)
                                        : const Color(0xFFE0D0D4),
                                  ),
                                )),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '리뷰 23개',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  color: const Color(0xFF9B7E85),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),
                          // 평점 바
                          Expanded(
                            child: Column(
                              children: [
                                _RatingBar(star: 5, ratio: 0.75),
                                const SizedBox(height: 5),
                                _RatingBar(star: 4, ratio: 0.55),
                                const SizedBox(height: 5),
                                _RatingBar(star: 3, ratio: 0.20),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 친구 게시물 ──
                    Text(
                      '친구들의 게시물'.toUpperCase(),
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF9B7E85),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 12),

                    _ReviewItem(
                      initial: '수',
                      name: '수아',
                      rating: 5,
                      text: '뇨끼가 진짜 너무 맛있어!! 소스가 크리미하고 양도 많아 👍',
                      hasImage: true,
                      imageEmoji: '🍝',
                    ),
                    _ReviewItem(
                      initial: '지',
                      name: '지민',
                      rating: 4,
                      text: '분위기 완전 좋고 사진도 잘 나와요 📸 데이트하기 딱!',
                      hasImage: false,
                      imageEmoji: '',
                    ),
                    _ReviewItem(
                      initial: '현',
                      name: '현우',
                      rating: 5,
                      text: '가격 대비 퀄리티 최고. 예약 필수!!',
                      hasImage: false,
                      imageEmoji: '',
                    ),
                    const SizedBox(height: 20),

                    // ── 지도 버튼 ──
                    GestureDetector(
                      onTap: () {},
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
                          '🗺️ 지도에서 위치 보기',
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

                    // ── 리뷰 작성 버튼 ──
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
                          '+ 내 리뷰 작성',
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
            const BottomNav(currentIndex: 3),
          ],
        ),
      ),
    );
  }
}

// ── 평점 바 ──
class _RatingBar extends StatelessWidget {
  final int star;
  final double ratio;
  const _RatingBar({required this.star, required this.ratio});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$star★',
          style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF9B7E85)),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 5,
              backgroundColor: const Color(0xFFF2E8E4),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE8556D)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 리뷰 아이템 ──
class _ReviewItem extends StatelessWidget {
  final String initial;
  final String name;
  final int rating;
  final String text;
  final bool hasImage;
  final String imageEmoji;

  const _ReviewItem({
    required this.initial,
    required this.name,
    required this.rating,
    required this.text,
    required this.hasImage,
    required this.imageEmoji,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 아바타
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFF7C5CD),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                initial,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFC03650),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF2D1A20),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      children: List.generate(5, (i) => Text(
                        '★',
                        style: TextStyle(
                          fontSize: 10,
                          color: i < rating
                              ? const Color(0xFFE8556D)
                              : const Color(0xFFE0D0D4),
                        ),
                      )),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: const Color(0xFF9B7E85),
                    height: 1.4,
                  ),
                ),
                if (hasImage) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF7E0C5), Color(0xFFF7C5D5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(imageEmoji, style: const TextStyle(fontSize: 24)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

