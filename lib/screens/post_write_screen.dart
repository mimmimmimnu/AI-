import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PostWriteScreen extends StatefulWidget {
  const PostWriteScreen({super.key});

  @override
  State<PostWriteScreen> createState() => _PostWriteScreenState();
}

class _PostWriteScreenState extends State<PostWriteScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _selectedPlace;
  bool _hasImage = false;

  final List<String> _places = [
    '☕ 연남동 어니언',
    '🍽️ 홍대 뇨끼 식당',
    '🎨 KT&G 상상마당',
    '🌅 망원 한강공원',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
                    child: Text(
                      '취소',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: const Color(0xFF9B7E85),
                      ),
                    ),
                  ),
                  Text(
                    '게시물 작성',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 18,
                      color: const Color(0xFF2D1A20),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (_controller.text.isNotEmpty) {
                        Navigator.pop(context, {
                          'text': _controller.text,
                          'place': _selectedPlace,
                          'hasImage': _hasImage,
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE8556D), Color(0xFFC03650)],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '게시',
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
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

                    // ── 작성자 정보 ──
                    Row(
                      children: [
                        Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7C5CD),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE8556D), width: 2),
                          ),
                          child: Center(
                            child: Text(
                              '나',
                              style: GoogleFonts.dmSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFC03650),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '이윤서',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF2D1A20),
                              ),
                            ),
                            Text(
                              '지민♥수아 방',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: const Color(0xFFE8556D),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── 텍스트 입력 ──
                    TextField(
                      controller: _controller,
                      maxLines: 6,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        color: const Color(0xFF2D1A20),
                        height: 1.6,
                      ),
                      decoration: InputDecoration(
                        hintText: '오늘 어땠나요? 친구들과 공유해보세요 💕',
                        hintStyle: GoogleFonts.dmSans(
                          fontSize: 14,
                          color: const Color(0xFF9B7E85),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── 이미지 추가 영역 ──
                    if (_hasImage)
                      Stack(
                        children: [
                          Container(
                            width: double.infinity,
                            height: 180,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF7C5CD), Color(0xFFE8AAB5)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Text('🌸', style: TextStyle(fontSize: 48)),
                            ),
                          ),
                          Positioned(
                            top: 8, right: 8,
                            child: GestureDetector(
                              onTap: () => setState(() => _hasImage = false),
                              child: Container(
                                width: 28, height: 28,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.4),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Center(
                                  child: Text('✕', style: TextStyle(color: Colors.white, fontSize: 12)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),

                    // ── 장소 태그 ──
                    Text(
                      '장소 태그'.toUpperCase(),
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF9B7E85),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _places.map((place) {
                        final selected = _selectedPlace == place;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _selectedPlace = selected ? null : place;
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFFE8556D)
                                  : const Color(0xFFF2E8E4),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              place,
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: selected ? Colors.white : const Color(0xFF9B7E85),
                                fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // ── 구분선 ──
                    const Divider(color: Color(0xFFF0E0E4), thickness: 1),
                    const SizedBox(height: 12),

                    // ── 하단 액션 버튼 ──
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() => _hasImage = !_hasImage),
                          child: _ActionButton(
                            icon: '🖼️',
                            label: '사진',
                            active: _hasImage,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _ActionButton(icon: '📍', label: '위치', active: false),
                        const SizedBox(width: 12),
                        _ActionButton(icon: '😊', label: '이모지', active: false),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 액션 버튼 ──
class _ActionButton extends StatelessWidget {
  final String icon;
  final String label;
  final bool active;
  const _ActionButton({required this.icon, required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFFDF0F2) : const Color(0xFFF2E8E4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? const Color(0xFFE8556D) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: active ? const Color(0xFFE8556D) : const Color(0xFF9B7E85),
              fontWeight: active ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}