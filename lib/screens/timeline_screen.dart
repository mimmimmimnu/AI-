import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/bottom_nav.dart';
import 'post_write_screen.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  int _selectedRoom = 0;

  final List<String> _rooms = ['지민♥수아', '현우그룹'];

  final List<Map<String, dynamic>> _posts = [
    {
      'initial': '지',
      'name': '지민',
      'text': '오늘 홍대 갔다왔어! 진짜 너무 좋았어 😍',
      'hasImage': true,
      'imageEmoji': '🌸',
      'time': '10:32 AM',
      'likes': 3,
    },
    {
      'initial': '수',
      'name': '수아',
      'text': '어니언 카페 분위기 완전 감성이었어 ☕ 다음에 또 가고싶다!',
      'hasImage': false,
      'time': '10:45 AM',
      'likes': 5,
    },
    {
      'initial': '지',
      'name': '지민',
      'text': '망원한강 피크닉 사진 🌅',
      'hasImage': true,
      'imageEmoji': '🌅',
      'time': '4:12 PM',
      'likes': 8,
    },
    {
      'initial': '현',
      'name': '현우',
      'text': '우와 여기 진짜 예쁘다! 다음번에 나도 같이 가고싶어 👀',
      'hasImage': false,
      'time': '4:30 PM',
      'likes': 2,
    },
  ];

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
                    '우리의 피드 💌',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 20,
                      color: const Color(0xFF2D1A20),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PostWriteScreen()),
    );
  },
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDF0F2),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(child: Text('✏️', style: TextStyle(fontSize: 16))),
                  ),
                  ),
                ],
              ),
            ),

            // ── 방 선택 탭 ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  ..._rooms.asMap().entries.map((e) {
                    final selected = _selectedRoom == e.key;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedRoom = e.key),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFFE8556D) : const Color(0xFFF2E8E4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          e.value,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: selected ? Colors.white : const Color(0xFF9B7E85),
                          ),
                        ),
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2E8E4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '+ 새방',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: const Color(0xFF9B7E85),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── 피드 ──
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _posts.length,
                itemBuilder: (context, i) {
                  final post = _posts[i];
                  return _PostItem(post: post);
                },
              ),
            ),

            // ── 입력창 ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF0E0E4), width: 1)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2E8E4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '게시물 작성...',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: const Color(0xFF9B7E85),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8556D),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(
                      child: Text('↑', style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),

            // ── 바텀 네비게이션 ──
            const BottomNav(currentIndex: 2),
          ],
        ),
      ),
    );
  }
}

// ── 게시물 아이템 ──
class _PostItem extends StatelessWidget {
  final Map<String, dynamic> post;
  const _PostItem({required this.post});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 아바타 ──
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF7C5CD),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                post['initial'],
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFC03650),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // ── 말풍선 ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDF0F2),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post['name'],
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFC03650),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        post['text'],
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: const Color(0xFF2D1A20),
                          height: 1.4,
                        ),
                      ),
                      if (post['hasImage'] == true) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF7C5CD), Color(0xFFE8AAB5)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              post['imageEmoji'],
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${post['time']} · ♡ ${post['likes']}',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
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

// ── 바텀 네비게이션 ──
