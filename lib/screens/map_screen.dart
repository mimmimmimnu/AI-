import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'place_detail_screen.dart';
import '../widgets/bottom_nav.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

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
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Text('←', style: TextStyle(fontSize: 22, color: Color(0xFF2D1A20))),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '코스 지도',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      color: const Color(0xFF2D1A20),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDF0F2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(child: Text('⊕', style: TextStyle(fontSize: 18))),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── 지도 Mock ──
                    Container(
                      width: double.infinity,
                      height: 240,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFF0E8F0), Color(0xFFE4DFF0), Color(0xFFDDE8F0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Stack(
                          children: [
                            // 그리드
                            CustomPaint(
                              size: const Size(double.infinity, 240),
                              painter: _GridPainter(),
                            ),
                            // 도로
                            Positioned(left: 0, right: 0, top: 90,
                              child: Container(height: 7, color: Colors.white.withOpacity(0.6))),
                            Positioned(left: 0, right: 0, top: 160,
                              child: Container(height: 7, color: Colors.white.withOpacity(0.6))),
                            Positioned(top: 0, bottom: 0, left: 90,
                              child: Container(width: 7, color: Colors.white.withOpacity(0.6))),
                            Positioned(top: 0, bottom: 0, left: 175,
                              child: Container(width: 7, color: Colors.white.withOpacity(0.6))),
                            Positioned(top: 0, bottom: 0, left: 230,
                              child: Container(width: 7, color: Colors.white.withOpacity(0.6))),

                            // 경로선
                            CustomPaint(
                              size: const Size(double.infinity, 240),
                              painter: _RoutePainter(),
                            ),

                            // 마커 1 (활성)
                            Positioned(left: 60, top: 36,
                              child: _MapMarker(number: 1, active: true)),
                            // 마커 2
                            Positioned(left: 148, top: 70,
                              child: _MapMarker(number: 2, active: false)),
                            // 마커 3
                            Positioned(left: 202, top: 138,
                              child: _MapMarker(number: 3, active: false)),
                            // 마커 4
                            Positioned(left: 202, top: 165,
                              child: _MapMarker(number: 4, active: false)),

                            // 현재 위치 점
                            Positioned(left: 56, top: 52,
                              child: Container(
                                width: 12, height: 12,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8556D),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFE8556D).withOpacity(0.4),
                                      blurRadius: 8, spreadRadius: 3,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 장소 목록 ──
                    // ── 장소 목록 ──
Text(
  '코스 장소 목록'.toUpperCase(),
  style: GoogleFonts.dmSans(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: const Color(0xFF9B7E85),
    letterSpacing: 0.8,
  ),
),
const SizedBox(height: 10),

GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlaceDetailScreen()),
    );
  },
  child: _MapPlaceCard(
    number: 1,
    name: '☕ 연남동 어니언',
    sub: '현재 위치 · 출발',
    rating: 5,
    active: true,
  ),
),
GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlaceDetailScreen()),
    );
  },
  child: _MapPlaceCard(
    number: 2,
    name: '🍽️ 홍대 뇨끼 식당',
    sub: '도보 8분',
    rating: 4,
    active: false,
  ),
),
GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlaceDetailScreen()),
    );
  },
  child: _MapPlaceCard(
    number: 3,
    name: '🎨 KT&G 상상마당',
    sub: '도보 5분',
    rating: 5,
    active: false,
  ),
),
GestureDetector(
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlaceDetailScreen()),
    );
  },
  child: _MapPlaceCard(
    number: 4,
    name: '🌅 망원 한강공원',
    sub: '도보 12분',
    rating: 5,
    active: false,
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

// ── 지도 그리드 Painter ──
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC8B4BE).withOpacity(0.3)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 28) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 28) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }
  @override
  bool shouldRepaint(_) => false;
}

// ── 경로선 Painter ──
class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFE8556D).withOpacity(0.8)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(66, 52)
      ..lineTo(66, 90)
      ..lineTo(155, 90)
      ..lineTo(155, 160)
      ..lineTo(209, 160)
      ..lineTo(209, 185);

    _drawDashedPath(canvas, path, linePaint);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashLength = 6.0;
    const gapLength = 3.0;
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final start = distance;
        final end = (distance + dashLength).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(start, end), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── 지도 마커 ──
class _MapMarker extends StatelessWidget {
  final int number;
  final bool active;
  const _MapMarker({required this.number, required this.active});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: active ? const Color(0xFFE8556D) : const Color(0xFF9B7E85),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4, offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$number',
              style: GoogleFonts.dmSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── 장소 카드 ──
class _MapPlaceCard extends StatelessWidget {
  final int number;
  final String name;
  final String sub;
  final int rating;
  final bool active;
  const _MapPlaceCard({
    required this.number,
    required this.name,
    required this.sub,
    required this.rating,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFFFDF0F2)
            : const Color(0xFFFBF7F5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: active
              ? const Color(0xFFF7C5CD)
              : const Color(0xFFF0E0E4),
          width: active ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: active ? const Color(0xFFE8556D) : const Color(0xFF9B7E85),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Center(
              child: Text(
                '$number',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF2D1A20),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: const Color(0xFF9B7E85),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: List.generate(5, (i) => Text(
              '★',
              style: TextStyle(
                fontSize: 11,
                color: i < rating
                    ? const Color(0xFFE8556D)
                    : const Color(0xFFE0D0D4),
              ),
            )),
          ),
        ],
      ),
    );
  }
}

