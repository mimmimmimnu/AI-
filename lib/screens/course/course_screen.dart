import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
// 상단 import 추가
import 'course_result_screen.dart';
import '../../widgets/bottom_nav.dart';

class CourseScreen extends StatefulWidget {
  const CourseScreen({super.key});

  @override
  State<CourseScreen> createState() => _CourseScreenState();
}

class _CourseScreenState extends State<CourseScreen> {
  int _people = 2;

  final List<String> _activities = ['☕ 카페', '🍽️ 맛집', '🎨 전시', '🎬 영화', '🌳 공원', '🛍️ 쇼핑', '🎡 놀이공원', '🌅 야경'];
  final Set<int> _selectedActivities = {0, 1};

  final List<String> _areas = ['홍대', '강남', '이태원', '한강', '성수', '북촌'];
  int _selectedArea = 0;

  final List<String> _durations = ['2시간', '3~4시간', '하루 종일'];
  int _selectedDuration = 1;

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
                    '코스 만들기',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      color: const Color(0xFF2D1A20),
                    ),
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

                    // ── 인원 ──
                    _SectionTitle(title: '인원은 몇 명인가요?'),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2E8E4),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () { if (_people > 1) setState(() => _people--); },
                            child: Container(
                              width: 30, height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8556D),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Center(
                                child: Text('−', style: TextStyle(color: Colors.white, fontSize: 18)),
                              ),
                            ),
                          ),
                          Column(
                            children: [
                              Text(
                                '$_people명',
                                style: GoogleFonts.dmSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF2D1A20),
                                ),
                              ),
                              Text(
                                _people == 1 ? '혼자' : _people == 2 ? '커플' : '그룹',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  color: const Color(0xFF9B7E85),
                                ),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () { if (_people < 10) setState(() => _people++); },
                            child: Container(
                              width: 30, height: 30,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8556D),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: const Center(
                                child: Text('+', style: TextStyle(color: Colors.white, fontSize: 18)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 활동 ──
                    _SectionTitle(title: '어떤 활동을 원하세요?'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_activities.length, (i) {
                        final selected = _selectedActivities.contains(i);
                        return GestureDetector(
                          onTap: () => setState(() {
                            selected ? _selectedActivities.remove(i) : _selectedActivities.add(i);
                          }),
                          child: _Chip(label: _activities[i], selected: selected),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),

                    // ── 지역 ──
                    _SectionTitle(title: '어느 지역으로 갈까요?'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_areas.length, (i) {
                        return GestureDetector(
                          onTap: () => setState(() => _selectedArea = i),
                          child: _Chip(label: _areas[i], selected: _selectedArea == i),
                        );
                      }),
                    ),
                    const SizedBox(height: 20),

                    // ── 시간 ──
                    _SectionTitle(title: '예상 소요 시간'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(_durations.length, (i) {
                        return GestureDetector(
                          onTap: () => setState(() => _selectedDuration = i),
                          child: _Chip(label: _durations[i], selected: _selectedDuration == i),
                        );
                      }),
                    ),
                    const SizedBox(height: 28),

                    // ── 생성 버튼 ──
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const CourseResultScreen()),
                      );
                    },
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
                          '✨ 코스 생성하기',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.dmSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
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

// ── 칩 ──
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  const _Chip({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFE8556D) : const Color(0xFFF2E8E4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(
          fontSize: 12,
          color: selected ? Colors.white : const Color(0xFF9B7E85),
          fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
        ),
      ),
    );
  }
}

