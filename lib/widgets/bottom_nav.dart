import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/home_screen.dart';
import '../screens/course/course_screen.dart';
import '../screens/timeline_screen.dart';
import '../screens/map_screen.dart';
import '../screens/mypage_screen.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  const BottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': '🏠', 'label': '홈'},
      {'icon': '✨', 'label': '코스'},
      {'icon': '💬', 'label': '타임라인'},
      {'icon': '🗺️', 'label': '지도'},
      {'icon': '👤', 'label': 'MY'},
    ];

    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF0E0E4), width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(items.length, (i) {
          final active = i == currentIndex;
          return GestureDetector(
            onTap: () {
              if (i == currentIndex) return;
              switch (i) {
                case 0:
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const HomeScreen()),
                    (route) => false,
                  );
                  break;
                case 1:
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CourseScreen()),
                  );
                  break;
                case 2:
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TimelineScreen()),
                  );
                  break;
                case 3:
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MapScreen()),
                  );
                  break;

                // switch문에 case 4 추가
case 4:
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const MypageScreen()),
  );
  break;
              }
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(items[i]['icon']!, style: const TextStyle(fontSize: 20)),
                const SizedBox(height: 3),
                Text(
                  items[i]['label']!,
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: active ? const Color(0xFFE8556D) : const Color(0xFF9B7E85),
                    fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}