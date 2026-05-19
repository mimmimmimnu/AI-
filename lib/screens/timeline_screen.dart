import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../widgets/bottom_nav.dart';
import 'post_write_screen.dart';
import '../models/post_model.dart';
import '../providers/post_provider.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final roomProvider = context.watch<RoomProvider>();
    final postProvider = context.watch<PostProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
  if (_scrollController.hasClients) {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }
});
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
                  Row(
                    children: [
                      // 초대코드 버튼
                      GestureDetector(
                        onTap: () => _showInviteCode(context, roomProvider.currentRoom.inviteCode),
                        child: Container(
                          width: 36, height: 36,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDF0F2),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Center(child: Text('🔗', style: TextStyle(fontSize: 16))),
                        ),
                      ),
                      // 글쓰기 버튼
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
                ],
              ),
            ),

            // ── 방 선택 탭 ──
            SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  ...roomProvider.rooms.asMap().entries.map((e) {
                    final selected = roomProvider.selectedIndex == e.key;
                    return GestureDetector(
                      onTap: () => roomProvider.selectRoom(e.key),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFFE8556D) : const Color(0xFFF2E8E4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          e.value.name,
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: selected ? Colors.white : const Color(0xFF9B7E85),
                          ),
                        ),
                      ),
                    );
                  }),
                  // 방 추가 버튼
                  GestureDetector(
                    onTap: () => _showRoomOptions(context, roomProvider),
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
  child: postProvider.posts.isEmpty
      ? Center(
          child: Text(
            '아직 게시물이 없어요 💕\n첫 게시물을 올려봐요!',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF9B7E85)),
          ),
        )
      : ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: postProvider.posts.length,
          itemBuilder: (context, i) => _PostItem(post: postProvider.posts[i]),
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
                        style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF9B7E85)),
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

            const BottomNav(currentIndex: 2),
          ],
        ),
      ),
    );
  }

  // ── 초대코드 보여주기 ──
  void _showInviteCode(BuildContext context, String code) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
            Text('초대 코드', style: GoogleFonts.playfairDisplay(fontSize: 20, color: const Color(0xFF2D1A20))),
            const SizedBox(height: 8),
            Text('친구에게 아래 코드를 공유해줘!', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF9B7E85))),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFDF0F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFF7C5CD), width: 1.5),
              ),
              child: Text(
                code,
                style: GoogleFonts.dmSans(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFE8556D),
                  letterSpacing: 6,
                ),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                Navigator.pop(context);
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
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFE8556D), Color(0xFFC03650)]),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Text('코드 복사하기', textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── 방 옵션 (새로 만들기 / 참가하기) ──
  void _showRoomOptions(BuildContext context, RoomProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
            Text('새 방 만들기', style: GoogleFonts.playfairDisplay(fontSize: 20, color: const Color(0xFF2D1A20))),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _showCreateRoom(context, provider);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFE8556D), Color(0xFFC03650)]),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Text('✨ 새 방 만들기', textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _showJoinRoom(context, provider);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFF7C5CD), width: 1.5),
                ),
                child: Text('🔗 초대코드로 참가하기', textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: const Color(0xFFE8556D))),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── 방 만들기 ──
  void _showCreateRoom(BuildContext context, RoomProvider provider) {
    final controller = TextEditingController();
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
              Text('방 이름을 입력해줘', style: GoogleFonts.playfairDisplay(fontSize: 20, color: const Color(0xFF2D1A20))),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                style: GoogleFonts.dmSans(fontSize: 14, color: const Color(0xFF2D1A20)),
                decoration: InputDecoration(
                  hintText: '예) 지민♥수아',
                  hintStyle: GoogleFonts.dmSans(color: const Color(0xFF9B7E85)),
                  filled: true,
                  fillColor: const Color(0xFFF2E8E4),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  if (controller.text.isNotEmpty) {
                    provider.createRoom(controller.text);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('방이 만들어졌어! 💕', style: GoogleFonts.dmSans()),
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
                  child: Text('만들기', textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ── 초대코드로 방 참가 ──
  void _showJoinRoom(BuildContext context, RoomProvider provider) {
    final controller = TextEditingController();
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
              Text('초대 코드 입력', style: GoogleFonts.playfairDisplay(fontSize: 20, color: const Color(0xFF2D1A20))),
              const SizedBox(height: 8),
              Text('친구에게 받은 6자리 코드를 입력해줘', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF9B7E85))),
              const SizedBox(height: 20),
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
                  final room = provider.findRoomByCode(controller.text);
                  if (room != null) {
                    provider.joinRoom(controller.text);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${room.name} 방에 참가했어! 💕', style: GoogleFonts.dmSans()),
                        backgroundColor: const Color(0xFFE8556D),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('코드를 찾을 수 없어 😢', style: GoogleFonts.dmSans()),
                        backgroundColor: const Color(0xFF9B7E85),
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
                  child: Text('참가하기', textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
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

// ── 게시물 아이템 ──
class _PostItem extends StatelessWidget {
  final PostModel post;
  const _PostItem({required this.post});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF7C5CD),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                post.initial,
                style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFFC03650)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFDF0F2),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.name,
                        style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFFC03650)),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        post.text,
                        style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF2D1A20), height: 1.4),
                      ),
                      if (post.hasImage) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF7C5CD), Color(0xFFE8AAB5)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(post.imageEmoji, style: const TextStyle(fontSize: 28)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () => context.read<PostProvider>().toggleLike(post.id),
                  child: Text(
                    '${post.time} · ♡ ${post.likes}',
                    style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF9B7E85)),
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