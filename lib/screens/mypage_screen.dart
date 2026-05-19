import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/user_provider.dart';
import '../widgets/bottom_nav.dart';
import 'package:flutter/services.dart';

class MypageScreen extends StatelessWidget {
  const MypageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();

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
                  Text('MY 페이지', style: GoogleFonts.playfairDisplay(fontSize: 20, color: const Color(0xFF2D1A20))),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingScreen())),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: const Color(0xFFFDF0F2), borderRadius: BorderRadius.circular(18)),
                      child: const Center(child: Text('⚙️', style: TextStyle(fontSize: 16))),
                    ),
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
                        gradient: const LinearGradient(colors: [Color(0xFFE8556D), Color(0xFFC03650)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () => _showEditProfile(context, user),
                            child: Stack(
                              children: [
                                Container(
                                  width: 72, height: 72,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(36),
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: Center(child: Text(user.avatarEmoji, style: const TextStyle(fontSize: 32))),
                                ),
                                Positioned(
                                  bottom: 0, right: 0,
                                  child: Container(
                                    width: 22, height: 22,
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
                                    child: const Center(child: Text('✏️', style: TextStyle(fontSize: 11))),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(user.name, style: GoogleFonts.playfairDisplay(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(user.email, style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white.withOpacity(0.8))),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatItem(label: '저장한 코스', value: '${user.savedCourses.length}'),
                              _StatItem(label: '친구', value: '${user.friends.length}'),
                              _StatItem(label: '게시물', value: '8'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 저장한 코스 ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SectionTitle(title: '저장한 코스'),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedCoursesScreen())),
                          child: Text('전체보기', style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFFE8556D))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...user.savedCourses.take(2).toList().asMap().entries.map((e) =>
                      _SavedCourseCard(
                        course: e.value,
                        onDelete: () => user.deleteCourse(e.key),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 친구 관리 ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _SectionTitle(title: '친구'),
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendManageScreen())),
                          child: Text('관리', style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFFE8556D))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 70,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ...user.friends.map((f) => _FriendAvatar(name: f['name'], initial: f['initial'])),
                          _FriendAvatarAdd(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendManageScreen()))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── 설정 메뉴 ──
                    _SectionTitle(title: '설정'),
                    const SizedBox(height: 10),
                    _MenuItem(icon: '🔔', label: '알림 설정', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingScreen()))),
                    _MenuItem(icon: '👥', label: '친구 관리', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FriendManageScreen()))),
                    _MenuItem(icon: '🔒', label: '개인정보 보호', onTap: () {}),
                    _MenuItem(icon: '📞', label: '고객센터', onTap: () {}),
                    _MenuItem(icon: '🚪', label: '로그아웃', onTap: () {}, isRed: true),
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

  // ── 프로필 편집 ──
  void _showEditProfile(BuildContext context, UserProvider user) {
    final nameController = TextEditingController(text: user.name);
    final emailController = TextEditingController(text: user.email);
    final avatars = ['👤', '🐱', '🐶', '🦊', '🐼', '🐨', '🦋', '🌸'];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFF2E8E4), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 20),
              Text('프로필 편집', style: GoogleFonts.playfairDisplay(fontSize: 20, color: const Color(0xFF2D1A20))),
              const SizedBox(height: 16),
              // 아바타 선택
              Wrap(
                spacing: 12,
                children: avatars.map((a) => GestureDetector(
                  onTap: () => user.updateAvatar(a),
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: user.avatarEmoji == a ? const Color(0xFFFDF0F2) : const Color(0xFFF2E8E4),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: user.avatarEmoji == a ? const Color(0xFFE8556D) : Colors.transparent, width: 2),
                    ),
                    child: Center(child: Text(a, style: const TextStyle(fontSize: 22))),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF2D1A20)),
                decoration: InputDecoration(
                  hintText: '이름',
                  filled: true,
                  fillColor: const Color(0xFFF2E8E4),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: emailController,
                style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF2D1A20)),
                decoration: InputDecoration(
                  hintText: '이메일',
                  filled: true,
                  fillColor: const Color(0xFFF2E8E4),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  user.updateName(nameController.text);
                  user.updateEmail(emailController.text);
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFE8556D), Color(0xFFC03650)]),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Text('저장하기', textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
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
        Text(value, style: GoogleFonts.playfairDisplay(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: Colors.white.withOpacity(0.8))),
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
      child: Text(title.toUpperCase(), style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF9B7E85), letterSpacing: 0.8)),
    );
  }
}

// ── 저장된 코스 카드 ──
class _SavedCourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final VoidCallback onDelete;
  const _SavedCourseCard({required this.course, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFDF0F2), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [course['color1'], course['color2']]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(course['emoji'], style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(course['title'], style: GoogleFonts.playfairDisplay(fontSize: 13, color: const Color(0xFF2D1A20))),
                const SizedBox(height: 3),
                Text(course['sub'], style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF9B7E85))),
              ],
            ),
          ),
          GestureDetector(
            onTap: onDelete,
            child: const Text('🗑️', style: TextStyle(fontSize: 16)),
          ),
        ],
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
            decoration: BoxDecoration(color: const Color(0xFFF7C5CD), borderRadius: BorderRadius.circular(21), border: Border.all(color: const Color(0xFFE8556D), width: 2)),
            child: Center(child: Text(initial, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFFC03650)))),
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
  final VoidCallback onTap;
  const _FriendAvatarAdd({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: const Color(0xFFF2E8E4), borderRadius: BorderRadius.circular(21), border: Border.all(color: const Color(0xFF9B7E85), width: 1.5)),
              child: const Center(child: Text('+', style: TextStyle(fontSize: 20, color: Color(0xFF9B7E85)))),
            ),
            const SizedBox(height: 4),
            Text('추가', style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF9B7E85))),
          ],
        ),
      ),
    );
  }
}

// ── 메뉴 아이템 ──
class _MenuItem extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool isRed;
  const _MenuItem({required this.icon, required this.label, required this.onTap, this.isRed = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: const Color(0xFFFDF0F2), borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: GoogleFonts.dmSans(fontSize: 13, color: isRed ? const Color(0xFFE8556D) : const Color(0xFF2D1A20)))),
            Text('→', style: TextStyle(color: isRed ? const Color(0xFFE8556D) : const Color(0xFF9B7E85))),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════
// ── 저장한 코스 전체보기 화면 ──
// ══════════════════════════════════════
class SavedCoursesScreen extends StatelessWidget {
  const SavedCoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFFBF7F5),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Text('←', style: TextStyle(fontSize: 22, color: Color(0xFF2D1A20)))),
                  const SizedBox(width: 16),
                  Text('저장한 코스', style: GoogleFonts.playfairDisplay(fontSize: 20, color: const Color(0xFF2D1A20))),
                ],
              ),
            ),
            Expanded(
              child: user.savedCourses.isEmpty
                  ? Center(child: Text('저장한 코스가 없어요 🌸', style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF9B7E85))))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: user.savedCourses.length,
                      itemBuilder: (context, i) => _SavedCourseCard(
                        course: user.savedCourses[i],
                        onDelete: () => user.deleteCourse(i),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════
// ── 친구 관리 화면 ──
// ══════════════════════════════════════
class FriendManageScreen extends StatelessWidget {
  const FriendManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFFBF7F5),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(onTap: () => Navigator.pop(context), child: const Text('←', style: TextStyle(fontSize: 22, color: Color(0xFF2D1A20)))),
                      const SizedBox(width: 16),
                      Text('친구 관리', style: GoogleFonts.playfairDisplay(fontSize: 20, color: const Color(0xFF2D1A20))),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => _showAddFriend(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFFE8556D), Color(0xFFC03650)]),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('+ 추가', style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: user.friends.isEmpty
                  ? Center(child: Text('친구를 추가해봐요 💕', style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF9B7E85))))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: user.friends.length,
                      itemBuilder: (context, i) {
                        final friend = user.friends[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: const Color(0xFFFDF0F2), borderRadius: BorderRadius.circular(14)),
                          child: Row(
                            children: [
                              Container(
                                width: 40, height: 40,
                                decoration: BoxDecoration(color: const Color(0xFFF7C5CD), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE8556D), width: 2)),
                                child: Center(child: Text(friend['initial'], style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: const Color(0xFFC03650)))),
                              ),
                              const SizedBox(width: 14),
                              Expanded(child: Text(friend['name'], style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF2D1A20)))),
                              GestureDetector(
                                onTap: () => user.removeFriend(i),
                                child: Text('삭제', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFFE8556D))),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFriend(BuildContext context) {
  final controller = TextEditingController();
  final user = context.read<UserProvider>();

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFF2E8E4), borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text('친구 추가', style: GoogleFonts.playfairDisplay(fontSize: 20, color: const Color(0xFF2D1A20))),
            const SizedBox(height: 8),
            Text('친구의 코드를 입력해줘', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF9B7E85))),
            // 내 코드 표시
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF0F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFF7C5CD), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('내 코드', style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF9B7E85))),
                      const SizedBox(height: 2),
                      Text(
                        user.myFriendCode,
                        style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFFE8556D), letterSpacing: 4),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: user.myFriendCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('코드가 복사됐어! 💕', style: GoogleFonts.dmSans()),
                          backgroundColor: const Color(0xFFE8556D),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8556D),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text('복사', style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: const Color(0xFFE8556D), letterSpacing: 4),
              textAlign: TextAlign.center,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: 'XXXXXX',
                hintStyle: GoogleFonts.dmSans(fontSize: 20, color: const Color(0xFF9B7E85), letterSpacing: 4),
                filled: true,
                fillColor: const Color(0xFFFDF0F2),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                final result = user.addFriendByCode(controller.text);
                Navigator.pop(context);
                if (result == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('코드를 찾을 수 없어 😢', style: GoogleFonts.dmSans()),
                      backgroundColor: const Color(0xFF9B7E85),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                } else if (result == 'already') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('이미 친구야! 💕', style: GoogleFonts.dmSans()),
                      backgroundColor: const Color(0xFF9B7E85),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$result 님과 친구가 됐어! 💕', style: GoogleFonts.dmSans()),
                      backgroundColor: const Color(0xFFE8556D),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFE8556D), Color(0xFFC03650)]),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Text('추가하기', textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    ),
  );
}
}

// ══════════════════════════════════════
// ── 알림 설정 화면 ──
// ══════════════════════════════════════
class NotificationSettingScreen extends StatelessWidget {
  const NotificationSettingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFFBF7F5),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Text('←', style: TextStyle(fontSize: 22, color: Color(0xFF2D1A20)))),
                  const SizedBox(width: 16),
                  Text('알림 설정', style: GoogleFonts.playfairDisplay(fontSize: 20, color: const Color(0xFF2D1A20))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _NotifItem(
                    title: '푸시 알림',
                    sub: '앱 알림을 받아요',
                    value: user.pushNotification,
                    onChanged: user.togglePushNotification,
                  ),
                  _NotifItem(
                    title: '친구 활동 알림',
                    sub: '친구가 게시물을 올리면 알려줘요',
                    value: user.friendActivity,
                    onChanged: user.toggleFriendActivity,
                  ),
                  _NotifItem(
                    title: '코스 추천 알림',
                    sub: '새로운 코스 추천을 받아요',
                    value: user.courseRecommend,
                    onChanged: user.toggleCourseRecommend,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifItem extends StatelessWidget {
  final String title;
  final String sub;
  final bool value;
  final Function(bool) onChanged;
  const _NotifItem({required this.title, required this.sub, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: const Color(0xFFFDF0F2), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF2D1A20), fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text(sub, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF9B7E85))),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFE8556D),
          ),
        ],
      ),
    );
  }
}