// ============================================================
// Datefit — 이지민_찐최종 + 이윤서 + 유다예 합본
// Flutter Web 전용
// ============================================================
import 'dart:convert';
import 'dart:math' as math;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, Clipboard, ClipboardData;
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';

// ────────────────────────────────────────────────────────────
// 모델
// ────────────────────────────────────────────────────────────
class ChatMessage {
  final String text;
  final bool isUser;
  final bool isSystem;
  ChatMessage({required this.text, required this.isUser, this.isSystem = false});
}

class PlaceResult {
  final String name;
  final String address;
  final String roadAddress;
  final String category;
  final String phone;
  final double? lat;
  final double? lng;
  final String source;
  final String placeUrl;
  final String openHours;

  PlaceResult({
    required this.name, required this.address, required this.roadAddress,
    required this.category, required this.phone,
    this.lat, this.lng, required this.source,
    this.placeUrl = '', this.openHours = '',
  });
}

class CourseStep {
  String time;
  final String emoji;
  final String type;
  final String band;
  final String duration;
  final String description;
  final String searchQuery;
  final String categoryCode;
  final String engine;
  PlaceResult? place;
  bool isSearching;
  int? travelMinutesFromPrev;

  CourseStep({
    required this.time, required this.emoji, required this.type,
    this.band = '', required this.duration, required this.description,
    required this.searchQuery, required this.categoryCode, required this.engine,
    this.place, this.isSearching = false, this.travelMinutesFromPrev,
  });
}

class PostModel {
  final String id;
  final String initial;
  final String name;
  final String text;
  final bool hasImage;
  final String imageEmoji;
  final String time;
  int likes;
  PostModel({required this.id, required this.initial, required this.name,
    required this.text, this.hasImage = false, this.imageEmoji = '',
    required this.time, this.likes = 0});
}

class RoomModel {
  final String id;
  final String name;
  final String inviteCode;
  final List<String> members;
  RoomModel({required this.id, required this.name, required this.inviteCode, required this.members});
}

// ────────────────────────────────────────────────────────────
// Providers
// ────────────────────────────────────────────────────────────
class PostProvider extends ChangeNotifier {
  final List<PostModel> _posts = [];
  List<PostModel> get posts => _posts;

  void addPost({required String text, String? place, bool hasImage = false, String imageEmoji = ''}) {
    final now = TimeOfDay.now();
    final h = now.hour > 12 ? now.hour - 12 : now.hour;
    final m = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    _posts.add(PostModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      initial: '나', name: '이윤서',
      text: place != null ? '$text\n📍 $place' : text,
      hasImage: hasImage, imageEmoji: hasImage ? imageEmoji : '',
      time: '$h:$m $period', likes: 0,
    ));
    notifyListeners();
  }

  void toggleLike(String id) {
    final post = _posts.firstWhere((p) => p.id == id);
    post.likes++;
    notifyListeners();
  }
}

class RoomProvider extends ChangeNotifier {
  final List<RoomModel> _rooms = [
    RoomModel(id: '1', name: '지민♥수아', inviteCode: 'LOVE01', members: ['이윤서', '지민', '수아']),
    RoomModel(id: '2', name: '현우그룹',  inviteCode: 'CREW02', members: ['이윤서', '현우', '태연']),
  ];
  int _selectedIndex = 0;
  List<RoomModel> get rooms => _rooms;
  RoomModel get currentRoom => _rooms[_selectedIndex];
  int get selectedIndex => _selectedIndex;

  void selectRoom(int i) { _selectedIndex = i; notifyListeners(); }

  RoomModel? findRoomByCode(String code) {
    try { return _rooms.firstWhere((r) => r.inviteCode == code.toUpperCase()); }
    catch (_) { return null; }
  }

  void joinRoom(String code) {
    final room = findRoomByCode(code);
    if (room != null && !room.members.contains('이윤서')) {
      final i = _rooms.indexOf(room);
      _rooms[i] = RoomModel(id: room.id, name: room.name, inviteCode: room.inviteCode, members: [...room.members, '이윤서']);
      notifyListeners();
    }
  }

  void createRoom(String name) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = math.Random();
    final code = List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
    _rooms.add(RoomModel(id: DateTime.now().millisecondsSinceEpoch.toString(), name: name, inviteCode: code, members: ['이윤서']));
    _selectedIndex = _rooms.length - 1;
    notifyListeners();
  }
}

class UserProvider extends ChangeNotifier {
  String _name = '이윤서';
  String _email = 'yunseo@datefit.com';
  String _avatarEmoji = '👤';
  bool _push = true, _friendAct = true, _courseRec = false;
  final String myCode = 'USER07';
  String? _loggedInUsername;

  final Map<String, Map<String, String>> _friendCodeDB = {
    'USER01': {'initial': '지', 'name': '지민'}, 'USER02': {'initial': '수', 'name': '수아'},
    'USER03': {'initial': '현', 'name': '현우'}, 'USER04': {'initial': '태', 'name': '태연'},
    'USER05': {'initial': '하', 'name': '하늘'}, 'USER06': {'initial': '민', 'name': '민준'},
  };
  final List<Map<String, dynamic>> _savedCourses = [
    {'emoji':'🌸','color1':const Color(0xFFF7C5CD),'color2':const Color(0xFFC5D5F7),'title':'봄날 홍대 산책 코스','sub':'3곳 · 4시간'},
    {'emoji':'🍃','color1':const Color(0xFFC5F7D5),'color2':const Color(0xFFF7F0C5),'title':'연남동 브런치 데이트','sub':'3곳 · 3시간'},
  ];
  final List<Map<String, dynamic>> _friends = [
    {'initial':'지','name':'지민'},{'initial':'수','name':'수아'},
    {'initial':'현','name':'현우'},{'initial':'태','name':'태연'},
  ];

  String get name => _name;
  String get email => _email;
  String get avatarEmoji => _avatarEmoji;
  String? get loggedInUsername => _loggedInUsername;
  bool get pushNotification => _push;
  bool get friendActivity => _friendAct;
  bool get courseRecommend => _courseRec;
  String get myFriendCode => myCode;
  List<Map<String, dynamic>> get savedCourses => _savedCourses;
  List<Map<String, dynamic>> get friends => _friends;

  void setLoggedInUser(String username) {
    _loggedInUsername = username;
    _name = username;
    notifyListeners();
  }
  void logout() { _loggedInUsername = null; notifyListeners(); }

  void updateName(String v) { _name = v; notifyListeners(); }
  void updateEmail(String v) { _email = v; notifyListeners(); }
  void updateAvatar(String v) { _avatarEmoji = v; notifyListeners(); }
  void togglePushNotification(bool v) { _push = v; notifyListeners(); }
  void toggleFriendActivity(bool v) { _friendAct = v; notifyListeners(); }
  void toggleCourseRecommend(bool v) { _courseRec = v; notifyListeners(); }
  void deleteCourse(int i) { _savedCourses.removeAt(i); notifyListeners(); }
  void removeFriend(int i) { _friends.removeAt(i); notifyListeners(); }
  void addCourse(Map<String, dynamic> course) {
    _savedCourses.insert(0, course); // 가장 위에(최신순으로) 추가합니다.
    notifyListeners();
  }

  String? addFriendByCode(String code) {
    final upper = code.toUpperCase();
    if (!_friendCodeDB.containsKey(upper)) return null;
    final friend = _friendCodeDB[upper]!;
    if (_friends.any((f) => f['name'] == friend['name'])) return 'already';
    _friends.add(friend);
    notifyListeners();
    return friend['name'];
  }
}

// ────────────────────────────────────────────────────────────
// 앱 진입
// ────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAuth.instance.signInAnonymously();

  ui.platformViewRegistry.registerViewFactory('kakao-map-view', (int viewId) {
    final div = web.HTMLDivElement()
      ..id = 'kakao-map'
      ..style.width = '100%'
      ..style.height = '100%';
    Future.delayed(const Duration(seconds: 1), () {
      globalContext.callMethod('initKakaoMap'.toJS, div);
    });
    return div;
  });

  ui.platformViewRegistry.registerViewFactory('kakao-review-map-view', (int viewId) {
    final div = web.HTMLDivElement()
      ..id = 'kakao-review-map'
      ..style.width = '100%'
      ..style.height = '100%';
    Future.delayed(const Duration(seconds: 1), () {
      globalContext.callMethod('initKakaoReviewMap'.toJS, div);
    });
    return div;
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PostProvider()),
        ChangeNotifierProvider(create: (_) => RoomProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
      ],
      child: const DatefitApp(),
    ),
  );
}

class DatefitApp extends StatelessWidget {
  const DatefitApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Datefit',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xFFE8556D), scaffoldBackgroundColor: const Color(0xFFFBF7F5)),
    home: const LoginScreen(),
  );
}

// ────────────────────────────────────────────────────────────
// 색상 상수
// ────────────────────────────────────────────────────────────
const kRose   = Color(0xFFE8556D);
const kRoseDk = Color(0xFFC03650);
const kRoseLt = Color(0xFFF7C5CD);
const kBlush  = Color(0xFFFDF0F2);
const kCream  = Color(0xFFFBF7F5);
const kNude   = Color(0xFFF2E8E4);
const kText   = Color(0xFF2D1A20);
const kMuted  = Color(0xFF9B7E85);

// ────────────────────────────────────────────────────────────
// 로그인 화면
// ────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final id = _idCtrl.text.trim();
    final pw = _pwCtrl.text.trim();
    if (id.isEmpty || pw.isEmpty) {
      setState(() => _error = '아이디와 비밀번호를 입력해주세요.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(id).get();
      if (!doc.exists) {
        setState(() { _error = '존재하지 않는 아이디입니다.'; _loading = false; });
        return;
      }
      if (doc['password'] != pw) {
        setState(() { _error = '비밀번호가 틀렸습니다.'; _loading = false; });
        return;
      }
      if (!mounted) return;
      context.read<UserProvider>().setLoggedInUser(id);
      Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false);
    } catch (e) {
      setState(() { _error = '오류가 발생했습니다. 다시 시도해주세요.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCream,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              const SizedBox(height: 60),
              Text('✿ Datefit', style: GoogleFonts.playfairDisplay(fontSize: 36, color: kRoseDk, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('둘이서 만드는 완벽한 하루', style: GoogleFonts.dmSans(fontSize: 13, color: kMuted, letterSpacing: 0.5)),
              const SizedBox(height: 48),
              _ControlledInputField(hint: '아이디', obscure: false, controller: _idCtrl),
              const SizedBox(height: 12),
              _ControlledInputField(hint: '비밀번호', obscure: true, controller: _pwCtrl),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: GoogleFonts.dmSans(fontSize: 12, color: Colors.red)),
              ],
              const SizedBox(height: 20),
              _loading
                ? const CircularProgressIndicator(color: kRose)
                : _PrimaryButton(label: '로그인', onTap: _login),
              const SizedBox(height: 28),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('아직 계정이 없으신가요? ', style: GoogleFonts.dmSans(fontSize: 12, color: kMuted)),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignupScreen())),
                  child: Text('회원가입', style: GoogleFonts.dmSans(fontSize: 12, color: kRose, fontWeight: FontWeight.w500))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ControlledInputField extends StatelessWidget {
  final String hint;
  final bool obscure;
  final TextEditingController controller;
  const _ControlledInputField({required this.hint, required this.obscure, required this.controller});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    obscureText: obscure,
    style: GoogleFonts.dmSans(fontSize: 13, color: kText),
    decoration: InputDecoration(
      hintText: hint, hintStyle: GoogleFonts.dmSans(fontSize: 13, color: kMuted),
      filled: true, fillColor: kNude,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    ),
  );
}

// ────────────────────────────────────────────────────────────
// 회원가입 화면
// ────────────────────────────────────────────────────────────
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _idCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _idCtrl.dispose();
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final id = _idCtrl.text.trim();
    final pw = _pwCtrl.text.trim();
    final pwConfirm = _pwConfirmCtrl.text.trim();
    if (id.isEmpty || pw.isEmpty || pwConfirm.isEmpty) {
      setState(() => _error = '모든 항목을 입력해주세요.');
      return;
    }
    if (pw != pwConfirm) {
      setState(() => _error = '비밀번호가 일치하지 않습니다.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(id).get();
      if (doc.exists) {
        setState(() { _error = '이미 사용 중인 아이디입니다.'; _loading = false; });
        return;
      }
      await FirebaseFirestore.instance.collection('users').doc(id).set({
        'password': pw,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      context.read<UserProvider>().setLoggedInUser(id);
      Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false);
    } catch (e) {
      setState(() { _error = '오류가 발생했습니다. 다시 시도해주세요.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCream,
      appBar: AppBar(
        backgroundColor: kCream,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: kRoseDk, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Text('회원가입', style: GoogleFonts.playfairDisplay(fontSize: 28, color: kRoseDk, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('Datefit과 함께하세요', style: GoogleFonts.dmSans(fontSize: 13, color: kMuted)),
              const SizedBox(height: 40),
              _ControlledInputField(hint: '아이디', obscure: false, controller: _idCtrl),
              const SizedBox(height: 12),
              _ControlledInputField(hint: '비밀번호', obscure: true, controller: _pwCtrl),
              const SizedBox(height: 12),
              _ControlledInputField(hint: '비밀번호 확인', obscure: true, controller: _pwConfirmCtrl),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: GoogleFonts.dmSans(fontSize: 12, color: Colors.red)),
              ],
              const SizedBox(height: 20),
              _loading
                ? const CircularProgressIndicator(color: kRose)
                : _PrimaryButton(label: '회원가입', onTap: _signup),
            ]),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kRose, kRoseDk]),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Text(label, textAlign: TextAlign.center,
        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white, letterSpacing: 0.3)),
    ),
  );
}

class _SocialButton extends StatelessWidget {
  final String label; final VoidCallback onTap;
  const _SocialButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(color: kNude, borderRadius: BorderRadius.circular(28)),
      child: Text(label, textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 13, color: kText)),
    ),
  );
}

// ────────────────────────────────────────────────────────────
// 메인 쉘 (탭 구조)
// ────────────────────────────────────────────────────────────
class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeTab(),
    CoursePage(),
    TimelineTab(),
    ReviewTab(),
    MypageTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      {'icon': '🏠', 'label': '홈'},
      {'icon': '✨', 'label': 'AI 코스'},
      {'icon': '💬', 'label': '타임라인'},
      {'icon': '⭐', 'label': '후기'},
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
            onTap: () => onTap(i),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(items[i]['icon']!, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 3),
              Text(items[i]['label']!,
                style: GoogleFonts.dmSans(fontSize: 10,
                  color: active ? kRose : kMuted,
                  fontWeight: active ? FontWeight.w500 : FontWeight.w400)),
            ]),
          );
        }),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────
// 홈 탭
// ────────────────────────────────────────────────────────────
class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    final savedCourses = user.savedCourses;
    return Scaffold(
      backgroundColor: kCream,
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('안녕하세요 💕', style: GoogleFonts.playfairDisplay(fontSize: 20, color: kText)),
            Stack(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(18)),
                child: const Center(child: Text('🔔', style: TextStyle(fontSize: 16)))),
              Positioned(top: 0, right: 0, child: Container(width: 9, height: 9,
                decoration: BoxDecoration(color: kRose, borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.white, width: 1.5)))),
            ]),
          ]),
        ),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // 배너
            Container(
              width: double.infinity, padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kRose, kRoseDk], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('오늘의 추천 코스', style: GoogleFonts.playfairDisplay(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('홍대 → 연남동 → 망원 한강 3시간 코스',
                  style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white.withOpacity(0.85))),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    final shell = context.findAncestorStateOfType<_MainShellState>();
                    shell?.setState(() => shell._currentIndex = 1);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(20)),
                    child: Text('코스 보기 →', style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            _SectionLabel('함께하는 친구'),
            const SizedBox(height: 10),
            SizedBox(height: 70, child: ListView(scrollDirection: Axis.horizontal, children: [
              ...user.friends.map((f) => _FriendAvatar(name: f['name'], initial: f['initial'])),
              _FriendAvatarAdd(onTap: () {
                final shell = context.findAncestorStateOfType<_MainShellState>();
                shell?.setState(() => shell._currentIndex = 3);
              }),
            ])),
            const SizedBox(height: 20),
            _SectionLabel('최근 저장한 코스'),
            const SizedBox(height: 10),
            if (savedCourses.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 28),
                decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  const Text('🗺️', style: TextStyle(fontSize: 32)),
                  const SizedBox(height: 8),
                  Text('저장한 코스가 없어요\nAI 코스 탭에서 코스를 만들어보세요!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(fontSize: 12, color: kMuted, height: 1.6)),
                ]),
              )
            else
              ...savedCourses.map((course) { // 💡 take(2) 삭제 및 동적 매핑으로 변경
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector( // 💡 클릭 이벤트 추가
                    onTap: () => _showCourseDetail(context, course),
                    child: _CourseCard(
                      emoji: course['emoji'] as String,
                      color1: course['color1'] as Color,
                      color2: course['color2'] as Color,
                      title: course['title'] as String,
                      sub: course['sub'] as String,
                    ),
                  ),
                );
              }),
            const SizedBox(height: 20),
          ]),
        )),
      ])),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel(this.title);
  @override
  Widget build(BuildContext context) => Text(title.toUpperCase(),
    style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500, color: kMuted, letterSpacing: 0.8));
}

class _FriendAvatar extends StatelessWidget {
  final String name, initial;
  const _FriendAvatar({required this.name, required this.initial});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 14),
    child: Column(children: [
      Container(width: 42, height: 42,
        decoration: BoxDecoration(color: kRoseLt, borderRadius: BorderRadius.circular(21), border: Border.all(color: kRose, width: 2)),
        child: Center(child: Text(initial, style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: kRoseDk)))),
      const SizedBox(height: 4),
      Text(name, style: GoogleFonts.dmSans(fontSize: 10, color: kMuted)),
    ]),
  );
}

class _FriendAvatarAdd extends StatelessWidget {
  final VoidCallback onTap;
  const _FriendAvatarAdd({required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 14),
    child: GestureDetector(onTap: onTap, child: Column(children: [
      Container(width: 42, height: 42,
        decoration: BoxDecoration(color: kNude, borderRadius: BorderRadius.circular(21), border: Border.all(color: kMuted, width: 1.5)),
        child: const Center(child: Text('+', style: TextStyle(fontSize: 20, color: kMuted)))),
      const SizedBox(height: 4),
      Text('추가', style: GoogleFonts.dmSans(fontSize: 10, color: kMuted)),
    ])),
  );
}

class _CourseCard extends StatelessWidget {
  final String emoji, title, sub;
  final Color color1, color2;
  const _CourseCard({required this.emoji, required this.color1, required this.color2, required this.title, required this.sub});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(16)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(height: 90,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color1, color2], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Center(child: Text(emoji, style: const TextStyle(fontSize: 30)))),
      Padding(padding: const EdgeInsets.fromLTRB(14, 10, 14, 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.playfairDisplay(fontSize: 14, color: kText)),
        const SizedBox(height: 3),
        Text(sub, style: GoogleFonts.dmSans(fontSize: 11, color: kMuted)),
      ])),
    ]),
  );
}

// ────────────────────────────────────────────────────────────
// AI 코스 추천 페이지 (이지민 원본 그대로)
// ────────────────────────────────────────────────────────────
class CoursePage extends StatefulWidget {
  const CoursePage({super.key});
  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> with SingleTickerProviderStateMixin {
  // ── API 키 ──
  static const String kakaoRestApiKey    = String.fromEnvironment('KAKAO_REST_API_KEY', defaultValue: '8ddff68bae409484fe211e99220c0bd1');
  static const String naverClientId      = String.fromEnvironment('NAVER_CLIENT_ID');
  static const String naverClientSecret  = String.fromEnvironment('NAVER_CLIENT_SECRET');
  static const String groqApiKey         = String.fromEnvironment('GROQ_API_KEY');
  static const String _groqModel         = 'llama-3.3-70b-versatile';

  static const Map<String, String> _districtHotspot = {
    '강남구': '신사동, 압구정동, 청담동, 삼성동', '용산구': '이태원동, 한남동, 해방촌',
    '마포구': '홍대입구, 연남동, 망원동', '성동구': '성수동, 서울숲',
    '종로구': '북촌, 인사동, 광화문', '중구': '명동, 을지로, 충무로',
    '서초구': '반포동, 방배동', '송파구': '잠실동, 방이동',
    '강서구': '마곡동, 발산동', '영등포구': '여의도, 당산동',
    '광진구': '건대입구, 뚝섬', '성북구': '성신여대입구, 삼청동',
    '은평구': '연신내, 불광동', '동작구': '흑석동, 노량진',
  };

  static Map<String, String> _seasonTheme() {
    final m = DateTime.now().month;
    if (m >= 3 && m <= 5) return {'key':'season','emoji':'🌸','label':'계절 특화형','desc':'봄 — 벚꽃 명소와 야외 피크닉 중심','places':'벚꽃 공원, 야외 카페, 피크닉 스팟, 강변 산책로','hint':'봄 특화: search 필드에 실제 장소명(예: "남산공원") 사용.',};
    if (m >= 6 && m <= 8) return {'key':'season','emoji':'☀️','label':'계절 특화형','desc':'여름 — 한강·루프탑·시원한 실내 중심','places':'한강 수변공원, 루프탑 카페, 실내 미술관, 시원한 카페','hint':'여름 특화: 오후 뜨거운 시간엔 실내 배치, 저녁은 한강변.',};
    if (m >= 9 && m <= 11) return {'key':'season','emoji':'🍂','label':'계절 특화형','desc':'가을 — 단풍 명소와 야외 활동 중심','places':'단풍 공원, 궁궐 후원, 야외 카페, 트레킹 코스','hint':'가을 특화: 야외 활동 비중 높여 구성.',};
    return {'key':'season','emoji':'❄️','label':'계절 특화형','desc':'겨울 — 야경·실내 전시·따뜻한 카페 중심','places':'야경 명소, 실내 전시, 따뜻한 카페','hint':'겨울 특화: 이동 거리 최소화, 낮은 실내 위주.',};
  }

  static List<Map<String, String>> get _themes => [
    {'key':'healing','label':'정적인 힐링형','emoji':'🌿','desc':'여유롭고 조용한 분위기','places':'조용한 카페, 공원 산책, 한강, 북카페, 소품샵'},
    _seasonTheme(),
    {'key':'food',   'label':'미식 탐방형', 'emoji':'🍽️','desc':'맛집과 디저트 중심','places':'이색 레스토랑, 유명 베이커리, 디저트 카페, 와인바'},
    {'key':'culture','label':'문화 감성형', 'emoji':'🎨','desc':'감성적인 문화 체험','places':'미술관, 전시회, 독립서점, 힙한 골목, 팝업스토어'},
  ];

  static const Map<String, String> categoryLabels = {
    'FD6':'음식점','CE7':'카페','AT4':'관광명소','AD5':'숙박','CT1':'문화시설','MT1':'쇼핑',
  };

  final TextEditingController searchController       = TextEditingController();
  final TextEditingController chatInputController    = TextEditingController();
  final TextEditingController _courseInputController = TextEditingController();
  final ScrollController      chatScrollController   = ScrollController();

  List<PlaceResult>  places       = [];
  List<ChatMessage>  chatMessages  = [];
  List<CourseStep>   _courseSteps  = [];

  bool   isLoading        = false;
  bool   isChatLoading    = false;
  bool   _isCourseLoading = false;
  String errorMessage     = '';
  String _courseError     = '';
  String _selectedThemeKey  = '';
  String currentCategoryCode = '';
  int?   selectedPlaceIndex;

  List<Map<String, dynamic>> _localSpots  = [];
  List<Map<String, dynamic>> _restaurants = [];

  late final TabController _tabController;

  static const String _systemPrompt = '''
당신은 카카오맵 기반 데이트 코스 및 장소 추천 AI 어시스턴트입니다.

[장소 추천 규칙]
1. [검색결과] 목록에 있는 장소만 추천하세요. 절대 지어내지 마세요.
2. "다른 거 알려줘" → 아직 추천 안 한 [검색결과] 항목 추천.
3. [검색결과] 소진 시 다른 키워드로 재검색하세요.
4. 검색 결과 없으면 즉시 [SEARCH:...]로 검색하세요.

[검색 명령 형식 — 반드시 대괄호 사용]
[SEARCH:검색어:카테고리코드:엔진]

엔진: naver(감성/분위기) or kakao(구체적 업종)
카테고리: FD6=음식점, CE7=카페, AT4=관광명소, CT1=문화시설, MT1=쇼핑

잡담에는 [SEARCH:] 없이 한국어로 친절하게 답변하세요.
''';

  String _buildCoursePrompt({
    required String region, required String themeLine,
    required String mandatoryNote, required String spotsContext,
    required String restaurantCtx, required String userPreferences,
  }) {
    final hotspot = _districtHotspot[region] ?? '';
    final hotspotHint = hotspot.isNotEmpty ? '\n[핵심 동네]: $hotspot' : '';
    return '''
You are a Korean date course planner for Seoul couples.
Reply ONLY with a valid JSON array. No markdown, no explanation.

$themeLine
Region: $region$hotspotHint$mandatoryNote$spotsContext$restaurantCtx$userPreferences

코스 5개 슬롯 순서: morning→lunch→afternoon→dinner→night (총 5~7 steps)
search 필드: "<동네명> <구체적 특성>" 형식 필수. lunch/dinner는 category="FD6", engine="kakao".

출력 형식:
[{"band":"morning","emoji":"☕","type":"카페","duration":"1시간 30분","description":"한남동 감성 카페","search":"한남동 감성 브런치 카페","category":"CE7","engine":"naver"}]
''';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLocalSpots();
    _loadRestaurants();
  }

  @override
  void dispose() {
    _tabController.dispose();
    chatInputController.dispose();
    chatScrollController.dispose();
    searchController.dispose();
    _courseInputController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalSpots() async {
    try {
      final s = await rootBundle.loadString('assets/spots.json');
      _localSpots = (jsonDecode(s) as List).cast<Map<String, dynamic>>();
    } catch (_) {}
  }

  Future<void> _loadRestaurants() async {
    try {
      final s = await rootBundle.loadString('assets/restaurants.json');
      _restaurants = (jsonDecode(s) as List).cast<Map<String, dynamic>>();
    } catch (_) {}
  }

  List<Map<String, dynamic>> _getTopRestaurants({String mealType = 'meal', bool forTourist = true, int limit = 5}) {
    final cats = mealType == 'cafe' ? ['카페/찻집']
        : mealType == 'dinner' ? ['한식','전문음식','외국식','음식점기타']
        : ['한식','간이음식','전문음식','외국식','음식점기타'];
    final key = forTourist ? 'rank_tourist' : 'rank_local';
    return (_restaurants.where((r) => cats.contains(r['category'])).toList()
      ..sort((a, b) => (a[key] as int).compareTo(b[key] as int))).take(limit).toList();
  }

  List<Map<String, dynamic>> _getSpotsForRegion(String region) =>
      (_localSpots.where((s) {
        final d = s['district'] as String;
        return d.contains(region) || region.contains(d.replaceAll('구', ''));
      }).toList()..sort((a, b) => (a['rank'] as int).compareTo(b['rank'] as int)));

  List<String> _getCategoriesForTheme(String key) {
    final m = DateTime.now().month;
    return switch (key) {
      'healing' => ['자연관광','기타관광','문화관광'],
      'season'  => (m >= 6 && m <= 8) ? ['자연관광','기타관광','문화관광']
          : (m >= 12 || m <= 2) ? ['문화관광','역사관광','기타관광']
          : ['자연관광','기타관광','역사관광'],
      'culture' => ['문화관광','역사관광','체험관광','쇼핑'],
      'food'    => ['문화관광','기타관광','쇼핑','자연관광'],
      _         => ['문화관광','기타관광','역사관광','자연관광'],
    };
  }

  Future<String> _callGroq(List<Map<String, String>> messages, {bool jsonMode = false}) async {
    if (groqApiKey.isEmpty) throw Exception('GROQ_API_KEY 없음 — run.ps1 또는 --dart-define 확인');
    final body = <String, dynamic>{'model': _groqModel, 'messages': messages};
    if (jsonMode) body['response_format'] = {'type': 'json_object'};
    final res = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $groqApiKey'},
      body: jsonEncode(body),
    );
    if (res.statusCode == 401) throw Exception('Groq API 키 오류');
    if (res.statusCode != 200) throw Exception('Groq ${res.statusCode}: ${res.body}');
    return jsonDecode(utf8.decode(res.bodyBytes))['choices'][0]['message']['content'] as String;
  }

  Future<List<PlaceResult>> _searchNaver(String query) async {
    final res = await http.get(
      Uri.parse('https://openapi.naver.com/v1/search/local.json?query=${Uri.encodeQueryComponent(query)}&display=5&sort=sim'),
      headers: {'X-Naver-Client-Id': naverClientId, 'X-Naver-Client-Secret': naverClientSecret},
    );
    if (res.statusCode != 200) throw Exception('네이버 API ${res.statusCode}');
    final items = jsonDecode(res.body)['items'] as List;
    String strip(String s) => s.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    return await Future.wait(items.map((item) async {
      final road = item['roadAddress'] ?? '', addr = item['address'] ?? '';
      final coord = await _getCoordFromAddress(road.isNotEmpty ? road : addr);
      return PlaceResult(name: strip(item['title'] ?? ''), address: addr, roadAddress: road,
        category: item['category'] ?? '', phone: item['telephone'] ?? '',
        lat: coord?['lat'], lng: coord?['lng'], source: 'naver');
    }));
  }

  Future<Map<String, double>?> _getCoordFromAddress(String address) async {
    if (address.isEmpty) return null;
    final clean = address.replaceAll(RegExp(r'\s+(?:\d+[Ff층호]|B\d+|지하\d+층?).*$'), '').trim();
    for (final q in [clean, address]) {
      try {
        final res = await http.get(
          Uri.parse('https://dapi.kakao.com/v2/local/search/address.json?query=${Uri.encodeQueryComponent(q)}'),
          headers: {'Authorization': 'KakaoAK $kakaoRestApiKey'},
        );
        if (res.statusCode == 200) {
          final docs = jsonDecode(res.body)['documents'] as List;
          if (docs.isNotEmpty) return {'lat': double.parse(docs[0]['y'].toString()), 'lng': double.parse(docs[0]['x'].toString())};
        }
      } catch (_) {}
    }
    return null;
  }

  Future<List<PlaceResult>> _searchKakao(String query, String categoryCode,
      {double? centerLat, double? centerLng, int radius = 3000, int size = 5}) async {
    final cat = categoryCode.isNotEmpty ? '&category_group_code=$categoryCode' : '';
    final loc = (centerLat != null && centerLng != null)
        ? '&x=$centerLng&y=$centerLat&radius=$radius&sort=distance' : '&sort=accuracy';
    final res = await http.get(
      Uri.parse('https://dapi.kakao.com/v2/local/search/keyword.json?query=${Uri.encodeQueryComponent(query)}$cat$loc&size=$size'),
      headers: {'Authorization': 'KakaoAK $kakaoRestApiKey'},
    );
    if (res.statusCode == 400) return [];
    if (res.statusCode != 200) throw Exception('카카오 API ${res.statusCode}');
    return (jsonDecode(res.body)['documents'] as List).map((p) => PlaceResult(
      name: p['place_name'] ?? '', address: p['address_name'] ?? '',
      roadAddress: p['road_address_name'] ?? '', category: p['category_name'] ?? '',
      phone: p['phone'] ?? '',
      lat: double.tryParse(p['y']?.toString() ?? ''), lng: double.tryParse(p['x']?.toString() ?? ''),
      source: 'kakao', placeUrl: p['place_url'] ?? '',
    )).toList();
  }

  Future<(String, bool)> _fetchOpenStatus(String placeId, String bandTime) async {
    if (placeId.isEmpty) return ('', true);
    try {
      final res = await http.get(Uri.parse('https://place.map.kakao.com/main/v/$placeId'),
        headers: {'Referer': 'https://map.kakao.com'});
      if (res.statusCode != 200) return ('', true);
      final data = jsonDecode(res.body);
      final openHour = data['basicInfo']?['openHour'];
      if (openHour == null) return ('', true);
      final offdayList = openHour['offdayList'];
      if (offdayList is List) {
        final now = DateTime.now();
        for (final offday in offdayList) {
          final wd = offday['weekAndDay']?.toString() ?? '';
          final parts = wd.split('/');
          if (parts.length == 2) {
            final week = int.tryParse(parts[0]) ?? -1, day = int.tryParse(parts[1]) ?? -1;
            final todayWeek = ((now.day - 1) ~/ 7) + 1;
            if (day == now.weekday && (week == 0 || week == todayWeek)) return ('휴무', false);
          }
        }
      }
      final periodList = openHour['periodList'];
      if (periodList is List && periodList.isNotEmpty) {
        final timeList = periodList[0]['timeList'];
        if (timeList is List && timeList.isNotEmpty) {
          final t = timeList[0];
          final open = t['startTime']?.toString() ?? '', close = t['endTime']?.toString() ?? '';
          if (open.isNotEmpty && close.isNotEmpty) return ('$open~$close', _isOpenAtBandTime(open, close, bandTime));
        }
      }
    } catch (_) {}
    return ('', true);
  }

  static bool _isOpenAtBandTime(String start, String end, String bandTime) {
    try {
      int toMin(String t) => int.parse(t.substring(0,2))*60 + int.parse(t.substring(2,4));
      final bp = bandTime.split(':');
      final bandMin = int.parse(bp[0])*60 + int.parse(bp[1]);
      final openMin = toMin(start), closeMin = toMin(end);
      if (closeMin <= openMin) return bandMin >= openMin || bandMin <= closeMin;
      return bandMin >= openMin && bandMin <= closeMin;
    } catch (_) { return true; }
  }

  static const _blocked = [
    '구내식당','직원식당','학생식당','사원식당','급식소','여성전용','남성전용',
    '구청','시청','주민센터','동사무소','구의회','시의회','세무서','경찰서',
    '소방서','우체국','보건소','복지관','관공서','행정복지센터','출입국',
  ];
  List<PlaceResult> _filter(List<PlaceResult> r) => r.where((p) {
    final s = '${p.name} ${p.category} ${p.address}';
    return !_blocked.any((k) => s.contains(k));
  }).toList();

  Future<void> searchPlaces(String query, {String categoryCode = '', String engine = 'naver', bool fromChat = false}) async {
    if (query.isEmpty) return;
    setState(() { isLoading = true; errorMessage = ''; places = []; selectedPlaceIndex = null; currentCategoryCode = categoryCode; });
    globalContext.callMethod('clearMarkers'.toJS);
    try {
      List<PlaceResult> results = engine == 'naver' ? await _searchNaver(query) : await _searchKakao(query, categoryCode);
      if (results.isEmpty && engine != 'naver') results = await _searchNaver(query);
      setState(() => places = results);
      if (results.isNotEmpty) { _showPlaceOnMap(results[0]); setState(() => selectedPlaceIndex = 0); }
      if (fromChat) {
        final lbl = categoryLabels[categoryCode] ?? '';
        setState(() => chatMessages.add(ChatMessage(
          text: results.isNotEmpty
              ? '[검색결과] "$query"${lbl.isNotEmpty ? " [$lbl]" : ""} ${results.length}개:\n'
                  + results.asMap().entries.map((e) { final p = e.value; final a = p.roadAddress.isNotEmpty ? p.roadAddress : p.address; return '${e.key+1}. ${p.name} | $a | ${p.category}'; }).join('\n')
              : '[검색결과] "$query" 결과 없음.',
          isUser: false, isSystem: true)));
      }
    } catch (e) { setState(() => errorMessage = '검색 오류: $e'); }
    finally { setState(() => isLoading = false); }
  }

  String _shoppingCode(String name) {
    const kw = ['아이파크몰','현대백화점','롯데백화점','신세계','갤러리아','코엑스몰','타임스퀘어','스타필드','더현대','몰','백화점','쇼핑몰','아울렛'];
    return kw.any((k) => name.contains(k)) ? 'MT1' : '';
  }

  String? _extractMandatory(String query) {
    for (final p in [
      RegExp(r'(.{1,20}?)(?:는|을|이|가)?\s*(?:꼭|반드시|무조건)\s*(?:넣어|포함|추가)'),
      RegExp(r'([가-힣a-zA-Z0-9 ·&]{2,20}?)\s*(?:이|가|을|를|은|는|에)?\s*(?:꼭\s*)?(?:가고\s*싶|가보고\s*싶|들르고\s*싶|방문하고\s*싶|가봐야)'),
    ]) {
      final m = p.firstMatch(query);
      if (m != null) return m.group(1)?.trim();
    }
    return null;
  }

  Future<void> _generateCourse({String? queryOverride}) async {
    final query = queryOverride ?? _courseInputController.text.trim();
    if (query.isEmpty || _isCourseLoading) return;
    setState(() { _isCourseLoading = true; _courseSteps = []; _courseError = ''; });
    globalContext.callMethod('clearMarkers'.toJS);

    try {
      const validDistricts = {
        '강남구','강동구','강북구','강서구','관악구','광진구','구로구','금천구',
        '노원구','도봉구','동대문구','동작구','마포구','서대문구','서초구',
        '성동구','성북구','송파구','양천구','영등포구','용산구','은평구','종로구','중구','중랑구',
      };
      final dm = RegExp(r'강남|강동|강북|강서|관악|광진|구로|금천|노원|도봉|동대문|동작|마포|서대문|서초|성동|성북|송파|양천|영등포|용산|은평|종로|중구|중랑').firstMatch(query);
      final rm = RegExp(r'^(\S+?)(?:에서|에|의|은|는|,|\s)').firstMatch(query);
      final raw = dm?.group(0) ?? rm?.group(1) ?? query.split(' ').first;
      final region = raw.endsWith('구') ? raw : '${raw}구';

      if (!validDistricts.contains(region)) {
        setState(() { _courseError = '어느 구에서 코스를 원하세요?\n예: "용산에서 코스 짜줘"'; _isCourseLoading = false; });
        return;
      }

      const centers = {
        '용산구':[37.5340,126.9947],'강남구':[37.5172,127.0473],'마포구':[37.5560,126.9234],
        '종로구':[37.5704,126.9831],'중구':[37.5640,126.9979],'서초구':[37.4836,127.0323],
        '송파구':[37.5145,127.1058],'강서구':[37.5509,126.8495],'영등포구':[37.5260,126.8963],
        '성동구':[37.5633,127.0368],'광진구':[37.5384,127.0823],'동대문구':[37.5744,127.0395],
        '중랑구':[37.6063,127.0928],'성북구':[37.5894,127.0167],'강북구':[37.6397,127.0255],
        '도봉구':[37.6688,127.0470],'노원구':[37.6549,127.0563],'은평구':[37.6027,126.9291],
        '서대문구':[37.5791,126.9368],'양천구':[37.5170,126.8664],'강동구':[37.5301,127.1237],
        '동작구':[37.5124,126.9395],'관악구':[37.4784,126.9516],'금천구':[37.4600,126.9001],'구로구':[37.4954,126.8872],
      };
      double? cLat, cLng;
      if (centers.containsKey(region)) { cLat = centers[region]![0].toDouble(); cLng = centers[region]![1].toDouble(); }
      else { final c = await _getCoordFromAddress(region); cLat = c?['lat']; cLng = c?['lng']; }

      final mandatory = _extractMandatory(query);
      final rawD = region.replaceAll('구', '');
      final mandStripped = mandatory != null ? mandatory.replaceAll(region, '').replaceAll(rawD, '').trim() : '';
      final mandLabel = mandStripped.isNotEmpty ? mandStripped : (mandatory ?? '');
      final isMandShop = _shoppingCode(mandLabel) == 'MT1';
      final mandNote = mandatory != null
          ? '\n\n[사용자 명시 장소 — 절대 규칙]\n"$mandLabel"을 반드시 1~2번째 step에 배치하세요.\ntype: "${isMandShop ? "쇼핑" : mandLabel}", search: "$mandLabel"' : '';

      final theme = _selectedThemeKey.isNotEmpty ? _themes.firstWhere((t) => t['key'] == _selectedThemeKey) : null;
      final themeCategories = theme != null ? _getCategoriesForTheme(_selectedThemeKey) : ['문화관광','자연관광','역사관광','체험관광','기타관광','쇼핑','레저스포츠'];
      final topSpots = _getSpotsForRegion(region).where((s) => themeCategories.contains(s['category'] as String)).take(2).toList();

      final Map<String, PlaceResult> preResolved = {};
      for (final spot in topSpots) {
        final name = spot['name'] as String;
        try {
          final r = _filter(await _searchKakao(name, 'AT4', centerLat: cLat, centerLng: cLng, radius: 2000));
          final f = r.where((p) => '${p.address} ${p.roadAddress}'.contains(region)).toList();
          if (f.isNotEmpty) preResolved[name] = f[0];
        } catch (_) {}
      }

      PlaceResult? mandResult;
      if (mandatory != null) {
        try {
          final cat = _shoppingCode(mandLabel);
          var r = await _searchKakao(mandLabel, cat, centerLat: cLat, centerLng: cLng, radius: 5000, size: 10);
          if (r.isEmpty) r = await _searchKakao('$region $mandLabel', cat, centerLat: cLat, centerLng: cLng, radius: 5000, size: 10);
          if (r.isNotEmpty) {
            r.sort((a, b) => _nameScore(a.name, mandLabel).compareTo(_nameScore(b.name, mandLabel)));
            mandResult = r[0];
            for (final key in [mandatory, '$region $mandatory', mandStripped, '$region $mandStripped', mandLabel]) {
              if (key.isNotEmpty) preResolved[key] = r[0];
            }
          }
        } catch (_) {}
      }

      final spotsCtx = topSpots.isNotEmpty ? '\n\n[필수 관광지]\n' + topSpots.map((s) => '- "${s['name']}" (${s['category']})').join('\n') : '';
      final lunch = _getTopRestaurants(mealType: 'meal', limit: 5);
      final dinner = _getTopRestaurants(mealType: 'dinner', limit: 5);
      final cafe = _getTopRestaurants(mealType: 'cafe', limit: 3);
      final restCtx = _restaurants.isNotEmpty
          ? '\n\n[인기 맛집]\n점심: ${lunch.map((r) => '"${r['name']}"').join(', ')}\n저녁: ${dinner.map((r) => '"${r['name']}"').join(', ')}\n카페: ${cafe.map((r) => '"${r['name']}"').join(', ')}' : '';
      final themeLine = theme != null
          ? 'Theme: ${theme['label']} (${theme['desc']})\nActivities: ${theme['places']}' : 'Theme: 인기 관광지 코스';

      String rawReply = '';
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          rawReply = await _callGroq([
            {'role': 'system', 'content': _buildCoursePrompt(region: region, themeLine: themeLine, mandatoryNote: mandNote, spotsContext: spotsCtx, restaurantCtx: restCtx, userPreferences: '')},
            {'role': 'user', 'content': query},
          ]);
          break;
        } catch (e) {
          if (attempt == 3 || !e.toString().contains('429')) rethrow;
          final retryMatch = RegExp(r'(?:retry|again) in (\d+(?:\.\d+)?)s').firstMatch(e.toString());
          final waitSecs = retryMatch != null ? double.parse(retryMatch.group(1)!).ceil() : 65;
          for (int i = waitSecs; i > 0; i--) {
            setState(() => _courseError = '⏳ API 한도 초과 — $i초 후 자동 재시도 ($attempt/3)...');
            await Future.delayed(const Duration(seconds: 1));
          }
          setState(() => _courseError = '');
        }
      }

      final cleaned = rawReply.replaceAll(RegExp(r'```json\s*'), '').replaceAll(RegExp(r'```\s*'), '').trim();
      List<dynamic> stepsJson;
      final arrMatch = RegExp(r'\[[\s\S]+\]').firstMatch(cleaned);
      if (arrMatch != null) { stepsJson = jsonDecode(arrMatch.group(0)!) as List; }
      else { final dec = jsonDecode(cleaned); stepsJson = dec is List ? dec : (dec['steps'] ?? dec['course'] ?? dec.values.firstWhere((v) => v is List)) as List; }
      if (stepsJson.isEmpty) throw Exception('코스 파싱 실패');

      String bandToTime(String band) => switch (band) { 'lunch' => '12:00', 'afternoon' => '14:00', 'dinner' => '18:00', 'night' => '20:00', _ => '10:00' };
      const bandOrder = {'morning':0,'lunch':1,'afternoon':2,'dinner':3,'night':4};
      stepsJson.sort((a, b) { final ba = bandOrder[(a['band'] ?? 'morning').toString()] ?? 0; final bb = bandOrder[(b['band'] ?? 'morning').toString()] ?? 0; return ba.compareTo(bb); });

      final steps = stepsJson.map((item) {
        final band = (item['band'] ?? 'morning').toString();
        return CourseStep(
          time: item['time'] != null ? item['time'].toString() : bandToTime(band),
          emoji: (item['emoji'] ?? '📍').toString(), type: (item['type'] ?? '').toString(), band: band,
          duration: (item['duration'] ?? '1시간').toString(), description: (item['description'] ?? '').toString(),
          searchQuery: (item['search'] ?? '').toString(), categoryCode: (item['category'] ?? '').toString(),
          engine: (item['engine'] ?? 'kakao').toString(),
        );
      }).toList();

      for (int i = 0; i < steps.length; i++) {
        PlaceResult? r = preResolved[steps[i].searchQuery];
        if (r == null) for (final e in preResolved.entries) { if (e.key.length > 2 && steps[i].searchQuery.contains(e.key)) { r = e.value; break; } }
        if (r != null) steps[i].place = r;
      }

      setState(() { _courseSteps = steps; _isCourseLoading = false; });
      final usedNames = <String>{...preResolved.values.map((p) => p.name)};

      setState(() { for (int i = 0; i < _courseSteps.length; i++) { if (_courseSteps[i].place == null && _courseSteps[i].searchQuery.isNotEmpty) _courseSteps[i].isSearching = true; } });

      final allCandidates = await Future.wait(_courseSteps.map((s) =>
        (s.place != null || s.searchQuery.isEmpty) ? Future.value(<PlaceResult>[]) : _searchStepCandidates(s, region, cLat, cLng)));

      for (int i = 0; i < _courseSteps.length; i++) {
        if (_courseSteps[i].place != null) { _addCourseMarker(_courseSteps[i].place!, i + 1); continue; }
        final candidates = allCandidates[i].where((p) => !usedNames.contains(p.name)).toList();
        if (candidates.isEmpty) { setState(() => _courseSteps[i].isSearching = false); continue; }
        PlaceResult best = candidates[0]; String bestHours = '';
        for (final candidate in candidates.take(3)) {
          final idMatch = candidate.placeUrl.isNotEmpty ? RegExp(r'/(\d+)$').firstMatch(candidate.placeUrl) : null;
          if (idMatch == null) { best = candidate; break; }
          final (hours, isOpen) = await _fetchOpenStatus(idMatch.group(1)!, _courseSteps[i].time);
          if (isOpen) { best = candidate; bestHours = hours; break; }
          best = candidate;
        }
        if (bestHours.isNotEmpty) {
          best = PlaceResult(name: best.name, address: best.address, roadAddress: best.roadAddress,
            category: best.category, phone: best.phone, lat: best.lat, lng: best.lng,
            source: best.source, placeUrl: best.placeUrl, openHours: bestHours);
        }
        setState(() { _courseSteps[i].place = best; _courseSteps[i].isSearching = false; });
        usedNames.add(best.name);
        _addCourseMarker(best, i + 1);
      }

      if (mandatory != null && mandResult?.lat != null) {
        final existIdx = _courseSteps.indexWhere((s) => s.place != null && _nameScore(s.place!.name, mandLabel) <= 2);
        if (existIdx >= 0) { setState(() => _courseSteps[existIdx].place = mandResult); }
        else {
          final matchIdx = _courseSteps.indexWhere((s) => mandLabel.isNotEmpty && s.searchQuery.contains(mandLabel));
          if (matchIdx >= 0) { setState(() => _courseSteps[matchIdx].place = mandResult); }
          else {
            final lunchIdx = _courseSteps.indexWhere((s) => s.type.contains('점심'));
            final at = ((lunchIdx > 0) ? lunchIdx : 1).clamp(0, _courseSteps.length);
            setState(() => _courseSteps.insert(at, CourseStep(time: '11:00', emoji: isMandShop ? '🛍️' : '📍',
              type: isMandShop ? '쇼핑' : mandLabel, duration: '1시간 30분', description: '$mandLabel 방문',
              searchQuery: mandLabel, categoryCode: '', engine: 'kakao', place: mandResult)));
          }
        }
        usedNames.add(mandResult!.name);
      }

      setState(() { _courseSteps.removeWhere((s) => s.place == null); });
      _optimizeRoute();
      _redrawAllMarkers();
      await _drawRoute();
      await _recalculateTimes();

    } catch (e) { setState(() => _courseError = '코스 생성 오류: $e'); }
    finally { if (_isCourseLoading) setState(() => _isCourseLoading = false); }
  }

  Future<List<PlaceResult>> _searchStepCandidates(CourseStep step, String region, double? cLat, double? cLng) async {
    if (step.searchQuery.isEmpty) return [];
    String withR(String q) => q.contains(region) ? q : '$region $q';
    bool inDistrict(PlaceResult p) => '${p.address} ${p.roadAddress}'.contains(region);
    List<PlaceResult> best = [];
    for (final (lat, lng, rad) in [(cLat, cLng, 1000), (cLat, cLng, 2000), (cLat, cLng, 5000)]) {
      if (lat == null || lng == null) continue;
      try { final r = _filter(await _searchKakao(withR(step.searchQuery), step.categoryCode, centerLat: lat, centerLng: lng, radius: rad)).where(inDistrict).toList(); if (r.isNotEmpty) { best = r; break; } } catch (_) {}
    }
    if (best.isEmpty) { try { final r = _filter(await _searchNaver(withR(step.searchQuery))).where(inDistrict).toList(); if (r.isNotEmpty) best = r; } catch (_) {} }
    if (best.isEmpty && step.categoryCode.isNotEmpty) {
      final cn = categoryLabels[step.categoryCode] ?? '';
      if (cn.isNotEmpty) { try { final r = _filter(await _searchKakao('$region $cn', step.categoryCode, centerLat: cLat, centerLng: cLng, radius: 3000)).where(inDistrict).toList(); if (r.isNotEmpty) best = r; } catch (_) {} }
    }
    return best;
  }

  void _redrawAllMarkers() {
    globalContext.callMethod('clearMarkers'.toJS);
    for (int i = 0; i < _courseSteps.length; i++) {
      final p = _courseSteps[i].place;
      if (p?.lat != null) globalContext.callMethod('addCourseMarker'.toJS, p!.lat!.toJS, p.lng!.toJS, (i+1).toJS, p.name.toJS);
    }
  }

  void _addCourseMarker(PlaceResult place, int number) {
    if (place.lat == null || place.lng == null) return;
    globalContext.callMethod('addCourseMarker'.toJS, place.lat!.toJS, place.lng!.toJS, number.toJS, place.name.toJS);
  }

  Future<List<Map<String, double>>?> _fetchWalkingRoutePath(PlaceResult from, PlaceResult to) async {
    try {
      final res = await http.get(Uri.parse('https://router.project-osrm.org/route/v1/foot/${from.lng},${from.lat};${to.lng},${to.lat}?overview=full&geometries=geojson'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final coords = data['routes']?[0]?['geometry']?['coordinates'] as List?;
        if (coords != null && coords.isNotEmpty) return coords.map<Map<String, double>>((c) => {'lat': (c[1] as num).toDouble(), 'lng': (c[0] as num).toDouble()}).toList();
      }
    } catch (_) {}
    return null;
  }

  Future<void> _drawRoute() async {
    final steps = _courseSteps.where((s) => s.place?.lat != null).toList();
    if (steps.length < 2) return;
    final segments = <List<Map<String, double>>>[];
    for (int i = 0; i < steps.length - 1; i++) {
      final from = steps[i].place!, to = steps[i+1].place!;
      final path = await _fetchWalkingRoutePath(from, to);
      segments.add(path ?? [{'lat': from.lat!, 'lng': from.lng!}, {'lat': to.lat!, 'lng': to.lng!}]);
    }
    globalContext.callMethod('drawRoute'.toJS, jsonEncode(segments).toJS);
  }

  void _showPlaceOnMap(PlaceResult place) {
    if (place.lat == null || place.lng == null) return;
    globalContext.callMethod('moveMapTo'.toJS, place.lat!.toJS, place.lng!.toJS, place.name.toJS);
  }

  double _haversineKm(double la1, double lo1, double la2, double lo2) {
    final dLa = (la2-la1)*math.pi/180, dLo = (lo2-lo1)*math.pi/180;
    final a = math.sin(dLa/2)*math.sin(dLa/2) + math.cos(la1*math.pi/180)*math.cos(la2*math.pi/180)*math.sin(dLo/2)*math.sin(dLo/2);
    return 6371 * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
  }

  void _optimizeRoute() {
    final withPlaces = _courseSteps.where((s) => s.place?.lat != null).toList();
    if (withPlaces.length < 2) return;
    PlaceResult? axisFrom, axisTo; double maxD = 0;
    for (int i = 0; i < withPlaces.length; i++) for (int j = i+1; j < withPlaces.length; j++) {
      final d = _haversineKm(withPlaces[i].place!.lat!, withPlaces[i].place!.lng!, withPlaces[j].place!.lat!, withPlaces[j].place!.lng!);
      if (d > maxD) { maxD = d; axisFrom = withPlaces[i].place; axisTo = withPlaces[j].place; }
    }
    if (axisFrom == null || axisTo == null) return;
    final af = axisFrom; final dLat = axisTo.lat! - af.lat!, dLng = axisTo.lng! - af.lng!;
    double proj(PlaceResult p) => (p.lat! - af.lat!)*dLat + (p.lng! - af.lng!)*dLng;
    String getBand(CourseStep s) { if (s.band.isNotEmpty) return s.band; if (s.type.contains('점심')) return 'lunch'; if (s.type.contains('저녁')) return 'dinner'; if (s.type.contains('야경') || s.type.contains('야간')) return 'night'; return 'morning'; }
    const bandOrder = {'morning':0,'lunch':1,'afternoon':2,'dinner':3,'night':4};
    final groups = <String, List<CourseStep>>{};
    for (final s in withPlaces) (groups[getBand(s)] ??= []).add(s);
    final result = <CourseStep>[];
    for (final b in ['morning','lunch','afternoon','dinner','night']) { final g = groups[b]; if (g != null) result.addAll(g..sort((a,b) => proj(a.place!).compareTo(proj(b.place!)))); }
    setState(() => _courseSteps = [...result, ..._courseSteps.where((s) => s.place?.lat == null)]);
  }

  Future<int?> _getTravelMinutes(PlaceResult from, PlaceResult to) async {
    if (from.lat == null || from.lng == null || to.lat == null || to.lng == null) return null;
    final distKm = _haversineKm(from.lat!, from.lng!, to.lat!, to.lng!);
    return math.max(3, (distKm * 1.25 / 4.5 * 60).ceil());
  }

  Future<void> _recalculateTimes() async {
    if (_courseSteps.isEmpty) return;
    int parseDur(String s) { int m=0; final h=RegExp(r'(\d+)시간').firstMatch(s); final n=RegExp(r'(\d+)분').firstMatch(s); if(h!=null)m+=int.parse(h.group(1)!)*60; if(n!=null)m+=int.parse(n.group(1)!); return m>0?m:60; }
    int toM(String t){ final p=t.split(':'); return int.parse(p[0])*60+int.parse(p[1]); }
    String fmt(int m)=>'${(m~/60).toString().padLeft(2,'0')}:${(m%60).toString().padLeft(2,'0')}';
    int cursor = toM(_courseSteps[0].time);
    for (int i=1; i<_courseSteps.length; i++) {
      final prev=_courseSteps[i-1], curr=_courseSteps[i];
      int? tr=(prev.place!=null&&curr.place!=null)?await _getTravelMinutes(prev.place!,curr.place!):null;
      tr??=15; cursor+=parseDur(prev.duration)+tr;
      if (_courseSteps[i].type.contains('점심')) cursor=12*60;
      if (_courseSteps[i].type.contains('저녁')) cursor=18*60;
      if (_courseSteps[i].type.contains('야간')||_courseSteps[i].type.contains('야경')) cursor=math.max(cursor,20*60);
      setState(() { _courseSteps[i].travelMinutesFromPrev=tr; _courseSteps[i].time=fmt(cursor); });
    }
  }

  void _showPlaceDetail(BuildContext context, PlaceResult place) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) {
        final addr = place.roadAddress.isNotEmpty ? place.roadAddress : place.address;
        final cat  = place.category.isNotEmpty ? place.category.split(' > ').last : '';
        return Container(
          margin: const EdgeInsets.fromLTRB(8,0,8,8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0,-2))]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.fromLTRB(20,0,20,24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(place.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              if (cat.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(20)),
                child: Text(cat, style: TextStyle(fontSize: 12, color: kRoseDk))),
              if (place.openHours.isNotEmpty) ...[const SizedBox(height: 8),
                Row(children: [Icon(Icons.access_time, size: 15, color: Colors.green.shade600), const SizedBox(width: 6),
                  Text('영업시간: ${place.openHours}', style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600))])],
              const SizedBox(height: 16), const Divider(height: 1), const SizedBox(height: 14),
              if (addr.isNotEmpty) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.location_on, size: 17, color: Colors.grey.shade600), const SizedBox(width: 8),
                Expanded(child: Text(addr, style: const TextStyle(fontSize: 13)))]),
              if (addr.isNotEmpty) const SizedBox(height: 10),
              if (place.phone.isNotEmpty) Row(children: [Icon(Icons.phone, size: 17, color: Colors.grey.shade600), const SizedBox(width: 8), Text(place.phone, style: const TextStyle(fontSize: 13))]),
              if (place.phone.isNotEmpty) const SizedBox(height: 10),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: () { Navigator.pop(ctx); _showPlaceOnMap(place); },
                icon: const Icon(Icons.map, size: 16), label: const Text('지도에서 위치 보기'),
                style: ElevatedButton.styleFrom(backgroundColor: kRose, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 13)))),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () {
                    final url = place.placeUrl.isNotEmpty ? place.placeUrl : 'https://map.kakao.com/link/search/${Uri.encodeComponent(place.name)}';
                    web.window.open(url, '_blank');
                  },
                  icon: const Icon(Icons.open_in_new, size: 15), label: const Text('카카오맵', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFFCD00), side: const BorderSide(color: Color(0xFFFFCD00)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 11)))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(
                  onPressed: () => web.window.open('https://map.naver.com/v5/search/${Uri.encodeComponent(place.name)}', '_blank'),
                  icon: const Icon(Icons.search, size: 15), label: const Text('네이버지도', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF03C75A), side: const BorderSide(color: Color(0xFF03C75A)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), padding: const EdgeInsets.symmetric(vertical: 11)))),
              ]),
            ])),
          ]),
        );
      });
  }

  Future<void> sendMessage() async {
    final text = chatInputController.text.trim();
    if (text.isEmpty || text.length == 1 || isChatLoading || _isCourseLoading) return;
    chatInputController.clear();
    setState(() => chatMessages.add(ChatMessage(text: text, isUser: true)));
    _scrollToBottom();

    if (RegExp(r'추가해\s*줘|추가시켜\s*줘|넣어\s*줘|포함시켜\s*줘|포함해\s*줘').hasMatch(text) && _courseSteps.isNotEmpty) {
      setState(() => isChatLoading = true);
      await _addPlaceToCourse(text);
      return;
    }

    final isCourse = RegExp(r'코스|데이트|여행|당일치기|나들이|짜줘|만들어').hasMatch(text);
    final hasReg   = RegExp(r'강남|강동|강북|강서|관악|광진|구로|금천|노원|도봉|동대문|동작|마포|서대문|서초|성동|성북|송파|양천|영등포|용산|은평|종로|중구|중랑|[가-힣]{1,4}(?:구|동|시|에서)').hasMatch(text);
    final isMand   = RegExp(r'중심으로|위주로|포함해서|포함하여|포함시켜').hasMatch(text);
    final hasModify = RegExp(r'말고|대신|바꿔|빼|제외|변경|교체|싫어|다른\s*(?:걸|것|곳|데|장소)|없애|수정|고쳐|별로').hasMatch(text);
    final isNewCourse = (hasReg && isCourse) || RegExp(r'코스\s*짜줘|코스\s*만들어|새로\s*짜|처음부터\s*짜|다시\s*짜').hasMatch(text);

    if (_courseSteps.isNotEmpty && !isNewCourse && hasModify) {
      setState(() => isChatLoading = true);
      await _modifyCourseByRequest(text);
      return;
    }

    if (hasReg || isCourse || isMand) {
      setState(() => chatMessages.add(ChatMessage(text: '코스를 생성하고 있어요! 코스 탭을 확인해주세요 🗺️', isUser: false)));
      _scrollToBottom();
      _tabController.animateTo(2);
      await _generateCourse(queryOverride: text);
      return;
    }

    setState(() => isChatLoading = true);
    try {
      final rm = RegExp(r'([가-힣]{2,4}(?:구|동))').firstMatch(text);
      final dr = rm?.group(1);
      String spotsCtx = '';
      if (dr != null) {
        final spots = _getSpotsForRegion(dr).where((s) => s['category'] != '숙박').take(10).toList();
        if (spots.isNotEmpty) spotsCtx = '\n\n[$dr 인기 관광지]\n${spots.map((s) => '- ${s['name']} (${s['category']})').join('\n')}';
      }
      final reply = await _callGroq([
        {'role': 'system', 'content': _systemPrompt + spotsCtx},
        ...chatMessages.map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text}),
      ]);
      final sm = RegExp(r'\[SEARCH:([^:\]]+):([^:\]]*):([^\]]+)\]').firstMatch(reply);
      if (sm != null) {
        final q = sm.group(1)!.trim(), cat = sm.group(2)!.trim(), eng = sm.group(3)!.trim();
        searchController.text = q; _tabController.animateTo(0);
        await searchPlaces(q, categoryCode: cat, engine: eng, fromChat: true);
      }
      final disp = reply.replaceAll(RegExp(r'\[SEARCH:[^\]]*\]'), '').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
      setState(() => chatMessages.add(ChatMessage(text: disp, isUser: false)));
    } catch (e) { setState(() => chatMessages.add(ChatMessage(text: '오류: $e', isUser: false))); }
    finally { setState(() => isChatLoading = false); _scrollToBottom(); }
  }

  Future<void> _addPlaceToCourse(String userText) async {
    String name = userText.replaceAll(RegExp(r'코스에?'), '').replaceAll(RegExp(r'추가해\s*줘|추가시켜\s*줘|넣어\s*줘|포함시켜\s*줘|포함해\s*줘|추가해|넣어'), '').replaceAll(RegExp(r'[을를도]\s*$'), '').replaceAll(RegExp(r'^\s*[을를도]\s*'), '').trim();
    if (name.isEmpty) { setState(() { chatMessages.add(ChatMessage(text: '어떤 장소를 추가할까요?', isUser: false)); isChatLoading = false; }); _scrollToBottom(); return; }
    setState(() => chatMessages.add(ChatMessage(text: '"$name"을(를) 코스에 추가하고 있어요...', isUser: false)));
    _scrollToBottom();
    try {
      final valid = _courseSteps.where((s) => s.place?.lat != null).toList();
      final lastPlace = valid.isNotEmpty ? valid.last.place : null;
      final cLat = lastPlace?.lat, cLng = lastPlace?.lng;
      var r = _filter(await _searchKakao(name, '', centerLat: cLat, centerLng: cLng, radius: 3000, size: 10));
      if (r.isEmpty) r = _filter(await _searchKakao(name, '', centerLat: cLat, centerLng: cLng, radius: 10000, size: 10));
      if (r.isEmpty) { setState(() => chatMessages.add(ChatMessage(text: '"$name"을(를) 찾을 수 없어요.', isUser: false))); return; }
      r.sort((a,b) => _nameScore(a.name,name).compareTo(_nameScore(b.name,name)));
      final place = r[0];
      int insertIdx = (_courseSteps.length-1).clamp(1, _courseSteps.length);
      for (int i=1; i<_courseSteps.length; i++) { if (RegExp(r'저녁|야경|야간').hasMatch(_courseSteps[i].type)) { insertIdx=i; break; } }
      const emojiMap = {'카페':'☕','음식점':'🍽️','관광명소':'🏛️','쇼핑':'🛍️','문화시설':'🎭','공원':'🌿'};
      final cat = place.category.isNotEmpty ? place.category.split(' > ').last : '장소';
      final emoji = emojiMap.entries.firstWhere((e) => cat.contains(e.key), orElse: () => const MapEntry('','📍')).value;
      setState(() => _courseSteps.insert(insertIdx, CourseStep(time: '', emoji: emoji, type: cat, duration: '1시간', description: place.name, searchQuery: name, categoryCode: '', engine: 'kakao', place: place)));
      _redrawAllMarkers(); await _drawRoute(); await _recalculateTimes();
      setState(() => chatMessages.add(ChatMessage(text: '"${place.name}"을(를) ${insertIdx+1}번째에 추가했어요!', isUser: false)));
      _tabController.animateTo(2);
    } catch (e) { setState(() => chatMessages.add(ChatMessage(text: '장소 추가 오류: $e', isUser: false))); }
    finally { setState(() => isChatLoading = false); _scrollToBottom(); }
  }

  Future<void> _modifyCourseByRequest(String userText) async {
    setState(() => chatMessages.add(ChatMessage(text: '코스를 수정하고 있어요...', isUser: false)));
    _scrollToBottom();
    try {
      final courseSummary = _courseSteps.asMap().entries.map((e) { final p = e.value.place; return '${e.key}: [${e.value.type}] ${e.value.description}${p != null ? " → ${p.name}" : ""}'; }).join('\n');
      String region = '';
      for (final s in _courseSteps) { if (s.place != null) { final addr='${s.place!.address} ${s.place!.roadAddress}'; final m=RegExp(r'([가-힣]{2,4}구)').firstMatch(addr); if (m!=null) { region=m.group(1)!; break; } } }
      final reply = await _callGroq([
        {'role':'system','content':'You are a course editor. Respond ONLY with valid JSON. No explanation, no markdown.'},
        {'role':'user','content':'현재 코스:\n$courseSummary\n\n사용자 요청: "$userText"\n지역: $region\n\n아래 JSON 형식으로만 응답:\n{"action":"replace","step_index":<0-based>,"replacement":{"type":"<타입>","emoji":"<이모지>","duration":"<시간>","description":"<설명>","search":"<검색어>","category":"<FD6|CE7|AT4|CT1|MT1>"}}'},
      ]);
      final jsonStr = RegExp(r'\{[\s\S]+\}').firstMatch(reply)?.group(0);
      if (jsonStr == null) throw Exception('응답 파싱 실패');
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final action = data['action'] as String? ?? 'replace';
      final stepIdx = (data['step_index'] as num).toInt();
      if (stepIdx < 0 || stepIdx >= _courseSteps.length) throw Exception('수정할 스텝을 찾지 못했어요.');
      if (action == 'remove') {
        final removedName = _courseSteps[stepIdx].place?.name ?? _courseSteps[stepIdx].type;
        setState(() => _courseSteps.removeAt(stepIdx));
        globalContext.callMethod('clearMarkers'.toJS);
        for (int i=0;i<_courseSteps.length;i++) { if (_courseSteps[i].place!=null) _addCourseMarker(_courseSteps[i].place!,i+1); }
        await _drawRoute(); await _recalculateTimes();
        setState(() => chatMessages.add(ChatMessage(text: '"$removedName"을(를) 코스에서 제거했어요.', isUser: false)));
      } else {
        final rep = data['replacement'] as Map<String, dynamic>;
        final searchQuery = rep['search'] as String, categoryCode = rep['category'] as String? ?? '';
        final vp = _courseSteps.where((s) => s.place?.lat != null).toList();
        double? cLat, cLng;
        if (vp.isNotEmpty) { cLat=vp.map((s)=>s.place!.lat!).reduce((a,b)=>a+b)/vp.length; cLng=vp.map((s)=>s.place!.lng!).reduce((a,b)=>a+b)/vp.length; }
        var results = _filter(await _searchKakao(searchQuery, categoryCode, centerLat: cLat, centerLng: cLng, radius: 3000, size: 10));
        if (results.isEmpty && region.isNotEmpty) results = _filter(await _searchKakao('$region ${rep['type']}', categoryCode, centerLat: cLat, centerLng: cLng, radius: 5000, size: 10));
        final usedNames = _courseSteps.map((s) => s.place?.name ?? '').toSet();
        results = results.where((p) => !usedNames.contains(p.name)).toList();
        final oldStep = _courseSteps[stepIdx];
        setState(() => _courseSteps[stepIdx] = CourseStep(time: oldStep.time, emoji: rep['emoji'] as String? ?? '📍', type: rep['type'] as String? ?? '장소', duration: rep['duration'] as String? ?? '1시간', description: rep['description'] as String? ?? searchQuery, searchQuery: searchQuery, categoryCode: categoryCode, engine: 'kakao', place: results.isNotEmpty ? results[0] : null));
        globalContext.callMethod('clearMarkers'.toJS);
        for (int i=0;i<_courseSteps.length;i++) { if (_courseSteps[i].place!=null) _addCourseMarker(_courseSteps[i].place!,i+1); }
        await _drawRoute(); await _recalculateTimes();
        setState(() => chatMessages.add(ChatMessage(text: results.isNotEmpty ? '"${results[0].name}"으로 교체했어요!' : '"${rep['type']}" 관련 장소를 찾지 못했어요.', isUser: false)));
        if (results.isNotEmpty) _tabController.animateTo(2);
      }
    } catch (e) { setState(() => chatMessages.add(ChatMessage(text: '코스 수정 중 오류: $e', isUser: false))); }
    finally { setState(() => isChatLoading = false); _scrollToBottom(); }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (chatScrollController.hasClients) chatScrollController.animateTo(chatScrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });
  }

  int _nameScore(String name, String target) {
    final n=name.replaceAll(' ',''), t=target.replaceAll(' ','');
    if (name==target) return 0; if (n==t) return 1;
    if (n.startsWith(t)||t.startsWith(n)) return 2;
    if (n.contains(t)) return 3; if (t.contains(n)) return 4;
    return 5;
  }

  // 💡 여기에 2번 코드를 쏙 붙여넣으세요!
  void _saveCurrentCourse() {
    if (_courseSteps.isEmpty) return;
    
    // 장소가 확정된 스텝만 필터링
    final validSteps = _courseSteps.where((s) => s.place != null).toList();
    if (validSteps.isEmpty) return;

    // 제목은 첫 번째 장소 이름으로 자동 생성
    final title = '${validSteps.first.place!.name} 중심 코스';

    // 소요 시간 계산
    int totalMinutes = 0;
    for (var s in validSteps) {
      final h = RegExp(r'(\d+)시간').firstMatch(s.duration);
      final m = RegExp(r'(\d+)분').firstMatch(s.duration);
      if (h != null) totalMinutes += int.parse(h.group(1)!) * 60;
      if (m != null) totalMinutes += int.parse(m.group(1)!);
      if (s.travelMinutesFromPrev != null) totalMinutes += s.travelMinutesFromPrev!;
    }
    final hours = totalMinutes > 0 ? (totalMinutes / 60).round() : 1;
    final sub = '${validSteps.length}곳 · 약 $hours시간';

    // 랜덤 파스텔 그라데이션 배경 생성
    final palettes = [
      [const Color(0xFFF7C5CD), const Color(0xFFC5D5F7)], 
      [const Color(0xFFC5F7D5), const Color(0xFFF7F0C5)], 
      [const Color(0xFFE2C5F7), const Color(0xFFF7C5D4)], 
      [const Color(0xFFC5E0F7), const Color(0xFFC5F7ED)], 
    ];
    final colorPair = palettes[DateTime.now().millisecondsSinceEpoch % palettes.length];

    // 저장할 코스 데이터 생성
    final newCourse = {
      'emoji': validSteps.first.emoji,
      'color1': colorPair[0],
      'color2': colorPair[1],
      'title': title,
      'sub': sub,
      'steps': validSteps,
    };

    // 프로바이더에 저장
    context.read<UserProvider>().addCourse(newCourse);

    // 저장 완료 알림
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('코스가 저장되었어요! 홈 화면에서 확인해보세요 💕', style: GoogleFonts.dmSans()),
        backgroundColor: kRose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── UI ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('✨ AI 코스 추천', style: GoogleFonts.playfairDisplay(fontSize: 20, color: kText)),
        
        actions: [
          if (_courseSteps.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: IconButton(
                icon: const Icon(Icons.bookmark_border, color: kRose, size: 28),
                onPressed: _saveCurrentCourse,
              ),
            ),
        ],

        bottom: TabBar(
          controller: _tabController,
          labelColor: kRose, unselectedLabelColor: kMuted,
          indicatorColor: kRose,
          tabs: const [Tab(icon: Icon(Icons.search), text: '검색'), Tab(icon: Icon(Icons.chat_bubble_outline), text: '챗봇'), Tab(icon: Icon(Icons.route), text: '코스')],
        ),
      ),
      body: Row(children: [
        SizedBox(width: 400, child: TabBarView(controller: _tabController, children: [
          _buildSearchTab(), _buildChatTab(), _buildCourseTab(),
        ])),
        const VerticalDivider(width: 1),
        Expanded(child: const HtmlElementView(viewType: 'kakao-map-view')),
      ]),
    );
  }

  Widget _buildSearchTab() {
    return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [const Icon(Icons.info_outline, size: 14, color: kRose), const SizedBox(width: 8),
          Expanded(child: Text('장소를 직접 검색하거나 챗봇에서 추천받으면 여기에 표시돼요.', style: GoogleFonts.dmSans(fontSize: 11, color: kRoseDk, height: 1.5)))])),
      Row(children: [
        Expanded(child: TextField(controller: searchController,
          decoration: InputDecoration(hintText: '예: 강남 파스타, 성수동 카페', prefixIcon: const Icon(Icons.search, color: kMuted),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
          onSubmitted: (v) => searchPlaces(v.trim(), categoryCode: currentCategoryCode, engine: 'naver'))),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => searchPlaces(searchController.text.trim(), categoryCode: currentCategoryCode, engine: 'naver'),
          style: ElevatedButton.styleFrom(backgroundColor: kRose, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('검색')),
      ]),
      const SizedBox(height: 8),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        Padding(padding: const EdgeInsets.only(right: 6), child: FilterChip(label: const Text('전체'), selected: currentCategoryCode.isEmpty, onSelected: (_) => setState(() => currentCategoryCode = ''), selectedColor: kBlush, checkmarkColor: kRose)),
        ...categoryLabels.entries.map((e) => Padding(padding: const EdgeInsets.only(right: 6),
          child: FilterChip(label: Text(e.value), selected: currentCategoryCode == e.key, onSelected: (_) => setState(() => currentCategoryCode = e.key), selectedColor: kBlush, checkmarkColor: kRose))),
      ])),
      const SizedBox(height: 12),
      if (isLoading) const Expanded(child: Center(child: CircularProgressIndicator(color: kRose)))
      else if (errorMessage.isNotEmpty) Expanded(child: Center(child: Text(errorMessage, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)))
      else if (places.isEmpty) Expanded(child: Center(child: Text('검색어를 입력하거나\n챗봇에서 장소를 추천받아보세요!', textAlign: TextAlign.center, style: GoogleFonts.dmSans(color: kMuted))))
      else ...[
        Text('검색 결과 ${places.length}개', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: kMuted)),
        const SizedBox(height: 8),
        Expanded(child: ListView.builder(itemCount: places.length, itemBuilder: (ctx, i) {
          final p = places[i]; final sel = selectedPlaceIndex == i;
          return Card(elevation: sel ? 4 : 1, color: sel ? kBlush : null,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: sel ? const BorderSide(color: kRoseLt, width: 1.5) : BorderSide.none),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: sel ? kRose : kNude, child: Text('${i+1}', style: TextStyle(color: sel ? Colors.white : kMuted, fontWeight: FontWeight.bold))),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 2),
                Text(p.roadAddress.isNotEmpty ? p.roadAddress : p.address, style: const TextStyle(fontSize: 12)),
                if (p.category.isNotEmpty) Text(p.category, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (p.phone.isNotEmpty) Text(p.phone, style: TextStyle(fontSize: 11, color: Colors.blue.shade700)),
                if (p.openHours.isNotEmpty) Row(children: [Icon(Icons.access_time, size: 12, color: Colors.green.shade600), const SizedBox(width: 3), Text(p.openHours, style: TextStyle(fontSize: 11, color: Colors.green.shade700))]),
              ]),
              isThreeLine: true,
              onTap: p.lat != null ? () { setState(() => selectedPlaceIndex = i); _showPlaceOnMap(p); } : null,
            ));
        })),
      ],
    ]));
  }

  Widget _buildChatTab() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(12,10,12,8),
        decoration: BoxDecoration(color: Colors.grey.shade50, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(8)),
            child: Text('💬 지역을 말하면 자동으로 코스를 짜드려요!\n🔍 장소 추천 요청 → 검색 탭에 결과 표시\n➕ "OO 추가해줘" → 현재 코스에 장소 추가',
              style: GoogleFonts.dmSans(fontSize: 11, color: kRoseDk, height: 1.5))),
          Text('코스 테마 (선택)', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: kMuted)),
          const SizedBox(height: 6),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            if (_selectedThemeKey.isNotEmpty) GestureDetector(onTap: () => setState(() => _selectedThemeKey = ''),
              child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: kNude, borderRadius: BorderRadius.circular(20), border: Border.all(color: kMuted)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.close, size: 12, color: Colors.grey), SizedBox(width: 2), Text('해제', style: TextStyle(fontSize: 12, color: Colors.grey))]))),
            ..._themes.map((theme) {
              final sel = _selectedThemeKey == theme['key'];
              return GestureDetector(onTap: () => setState(() => _selectedThemeKey = sel ? '' : theme['key']!),
                child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: sel ? kRose : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: sel ? kRose : kRoseLt)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(theme['emoji']!, style: const TextStyle(fontSize: 14)), const SizedBox(width: 4),
                    Text(theme['label']!, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: sel ? Colors.white : kText)),
                  ])));
            }),
          ])),
        ]),
      ),
      Expanded(
        child: chatMessages.where((m) => !m.isSystem).isEmpty
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey), const SizedBox(height: 12),
                Text('"용산에서 데이트 코스 짜줘"\n"성북구 힐링 코스 추천해줘"\n"홍대 분위기 좋은 카페 어디야?"',
                  textAlign: TextAlign.center, style: GoogleFonts.dmSans(color: kMuted, height: 1.8))])))
            : ListView.builder(controller: chatScrollController, padding: const EdgeInsets.all(12),
                itemCount: chatMessages.length,
                itemBuilder: (ctx, i) {
                  final msg = chatMessages[i];
                  if (msg.isSystem) return const SizedBox.shrink();
                  return Align(
                    alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      constraints: const BoxConstraints(maxWidth: 300),
                      decoration: BoxDecoration(
                        color: msg.isUser ? kRose : kBlush,
                        borderRadius: BorderRadius.only(topLeft: const Radius.circular(12), topRight: const Radius.circular(12),
                          bottomLeft: Radius.circular(msg.isUser ? 12 : 0), bottomRight: Radius.circular(msg.isUser ? 0 : 12))),
                      child: Text(msg.text, style: TextStyle(color: msg.isUser ? Colors.white : kText)),
                    ));
                }),
      ),
      if (isChatLoading) const LinearProgressIndicator(color: kRose),
      Container(padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade300))),
        child: Row(children: [
          Expanded(child: TextField(controller: chatInputController,
            decoration: InputDecoration(hintText: '예: 용산에서 코스 짜줘, 아이파크몰 중심으로',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            onSubmitted: (_) { if (!isChatLoading && !_isCourseLoading) sendMessage(); },
            maxLines: null)),
          const SizedBox(width: 8),
          IconButton(onPressed: (isChatLoading || _isCourseLoading) ? null : sendMessage,
            icon: const Icon(Icons.send),
            style: IconButton.styleFrom(backgroundColor: kRose, foregroundColor: Colors.white)),
        ]),
      ),
    ]);
  }

  Widget _buildCourseTab() {
    return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(8)),
        child: Text('🗺️ AI가 동선을 최적화해서 코스를 짜드려요.\n💡 챗봇 탭에서 "용산 코스 짜줘"라고 말해보세요!',
          style: GoogleFonts.dmSans(fontSize: 11, color: kRoseDk, height: 1.5))),
      if (_isCourseLoading)
        const Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: kRose), SizedBox(height: 12),
          Text('AI가 코스를 생성하고 있어요...', style: TextStyle(color: Colors.grey))])))
      else if (_courseError.isNotEmpty)
        Expanded(child: Center(child: Text(_courseError, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)))
      else if (_courseSteps.isEmpty)
        Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.map_outlined, size: 48, color: Colors.grey), const SizedBox(height: 12),
          Text('챗봇 탭에서 코스를 요청하면\n여기에 표시됩니다!', textAlign: TextAlign.center, style: GoogleFonts.dmSans(color: kMuted, height: 1.8))])))
      else
        Expanded(child: ListView.builder(itemCount: _courseSteps.length, itemBuilder: (ctx, idx) {
          final step = _courseSteps[idx]; final isLast = idx == _courseSteps.length-1;
          return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 48, child: Column(children: [
              Container(width: 36, height: 36, decoration: const BoxDecoration(color: kRose, shape: BoxShape.circle),
                child: Center(child: Text(step.emoji, style: const TextStyle(fontSize: 18)))),
              if (!isLast) Expanded(child: Stack(alignment: Alignment.center, children: [
                Container(width: 2, color: kRoseLt),
                if (_courseSteps[idx+1].travelMinutesFromPrev != null)
                  Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white, border: Border.all(color: kRoseLt), borderRadius: BorderRadius.circular(8)),
                    child: Text('🚶 ${_courseSteps[idx+1].travelMinutesFromPrev}분', style: TextStyle(fontSize: 10, color: kRoseDk))),
              ])),
            ])),
            Expanded(child: Padding(padding: EdgeInsets.only(bottom: isLast ? 0 : 16, left: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 20, height: 20, decoration: const BoxDecoration(color: kRose, shape: BoxShape.circle),
                    child: Center(child: Text('${idx+1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)))),
                  const SizedBox(width: 6),
                  Text(step.time, style: GoogleFonts.dmSans(fontSize: 12, color: kMuted, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Text(step.type, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold, color: kText)),
                  const SizedBox(width: 6),
                  Text('(${step.duration})', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ]),
                Text(step.description, style: GoogleFonts.dmSans(fontSize: 12, color: kMuted)),
                const SizedBox(height: 6),
                if (step.isSearching)
                  const Row(children: [SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: kRose)), SizedBox(width: 6), Text('장소 검색 중...', style: TextStyle(fontSize: 12, color: Colors.grey))])
                else if (step.place != null)
                  GestureDetector(onTap: () => _showPlaceOnMap(step.place!),
                    child: Container(padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(8), border: Border.all(color: kRoseLt)),
                      child: Row(children: [
                        const Icon(Icons.place, size: 16, color: kRose), const SizedBox(width: 4),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(step.place!.name, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold, color: kText)),
                          Text(step.place!.roadAddress.isNotEmpty ? step.place!.roadAddress : step.place!.address,
                            style: GoogleFonts.dmSans(fontSize: 11, color: kMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (step.place!.openHours.isNotEmpty)
                            Row(children: [Icon(Icons.access_time, size: 11, color: Colors.green.shade600), const SizedBox(width: 3),
                              Text(step.place!.openHours, style: TextStyle(fontSize: 10, color: Colors.green.shade700))]),
                        ])),
                        GestureDetector(onTap: () => _showPlaceDetail(ctx, step.place!),
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.chevron_right, size: 16, color: kRose))),
                      ])))
                else Text('장소를 찾지 못했습니다', style: TextStyle(fontSize: 12, color: Colors.red.shade300)),
              ]))),
          ]));
        })),
    ]));
  }
}

// ────────────────────────────────────────────────────────────
// 타임라인 탭
// ────────────────────────────────────────────────────────────
class TimelineTab extends StatefulWidget {
  const TimelineTab({super.key});
  @override
  State<TimelineTab> createState() => _TimelineTabState();
}

class _TimelineTabState extends State<TimelineTab> {
  final ScrollController _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final roomProvider = context.watch<RoomProvider>();
    final postProvider = context.watch<PostProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });

    return Scaffold(
      backgroundColor: kCream,
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('우리의 피드 💌', style: GoogleFonts.playfairDisplay(fontSize: 20, color: kText)),
            Row(children: [
              GestureDetector(onTap: () => _showInviteCode(context, roomProvider.currentRoom.inviteCode),
                child: Container(width: 36, height: 36, margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(18)),
                  child: const Center(child: Text('🔗', style: TextStyle(fontSize: 16))))),
              GestureDetector(onTap: () => _showPostWrite(context, postProvider),
                child: Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(18)),
                  child: const Center(child: Text('✏️', style: TextStyle(fontSize: 16))))),
            ]),
          ])),
        SizedBox(height: 38, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20), children: [
          ...roomProvider.rooms.asMap().entries.map((e) {
            final selected = roomProvider.selectedIndex == e.key;
            return GestureDetector(onTap: () => roomProvider.selectRoom(e.key),
              child: Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(color: selected ? kRose : kNude, borderRadius: BorderRadius.circular(20)),
                child: Text(e.value.name, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500, color: selected ? Colors.white : kMuted))));
          }),
          GestureDetector(onTap: () => _showRoomOptions(context, roomProvider),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(color: kNude, borderRadius: BorderRadius.circular(20)),
              child: Text('+ 새방', style: GoogleFonts.dmSans(fontSize: 11, color: kMuted)))),
        ])),
        const SizedBox(height: 12),
        Expanded(child: postProvider.posts.isEmpty
            ? Center(child: Text('아직 게시물이 없어요 💕\n첫 게시물을 올려봐요!', textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 13, color: kMuted)))
            : ListView.builder(controller: _scrollController, padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: postProvider.posts.length,
                itemBuilder: (context, i) => _PostItem(post: postProvider.posts[i]))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF0E0E4), width: 1))),
          child: GestureDetector(onTap: () => _showPostWrite(context, postProvider),
            child: Row(children: [
              Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(color: kNude, borderRadius: BorderRadius.circular(20)),
                child: Text('게시물 작성...', style: GoogleFonts.dmSans(fontSize: 12, color: kMuted)))),
              const SizedBox(width: 8),
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: kRose, borderRadius: BorderRadius.circular(18)),
                child: const Center(child: Text('↑', style: TextStyle(color: Colors.white, fontSize: 16)))),
            ]))),
      ])),
    );
  }

  void _showInviteCode(BuildContext context, String code) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheet(children: [
        Text('초대 코드', style: GoogleFonts.playfairDisplay(fontSize: 20, color: kText)),
        const SizedBox(height: 8),
        Text('친구에게 아래 코드를 공유해줘!', style: GoogleFonts.dmSans(fontSize: 12, color: kMuted)),
        const SizedBox(height: 20),
        Container(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(16), border: Border.all(color: kRoseLt, width: 1.5)),
          child: Text(code, style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w700, color: kRose, letterSpacing: 6))),
        const SizedBox(height: 16),
        _PrimaryButton(label: '코드 복사하기', onTap: () {
          Clipboard.setData(ClipboardData(text: code));
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('코드가 복사됐어! 💕', style: GoogleFonts.dmSans()), backgroundColor: kRose, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
        }),
      ]));
  }

  void _showPostWrite(BuildContext context, PostProvider provider) {
    final controller = TextEditingController();
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _BottomSheet(children: [
          Text('게시물 작성', style: GoogleFonts.playfairDisplay(fontSize: 20, color: kText)),
          const SizedBox(height: 16),
          TextField(controller: controller, maxLines: 4,
            style: GoogleFonts.dmSans(fontSize: 14, color: kText, height: 1.6),
            decoration: InputDecoration(hintText: '오늘 어땠나요? 친구들과 공유해보세요 💕', hintStyle: GoogleFonts.dmSans(fontSize: 14, color: kMuted),
              filled: true, fillColor: kNude, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(16))),
          const SizedBox(height: 16),
          _PrimaryButton(label: '게시하기', onTap: () {
            if (controller.text.isNotEmpty) { provider.addPost(text: controller.text); Navigator.pop(context); }
          }),
        ])));
  }

  void _showRoomOptions(BuildContext context, RoomProvider provider) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheet(children: [
        Text('새 방 만들기', style: GoogleFonts.playfairDisplay(fontSize: 20, color: kText)),
        const SizedBox(height: 20),
        _PrimaryButton(label: '✨ 새 방 만들기', onTap: () { Navigator.pop(context); _showCreateRoom(context, provider); }),
        const SizedBox(height: 10),
        _OutlineButton(label: '🔗 초대코드로 참가하기', onTap: () { Navigator.pop(context); _showJoinRoom(context, provider); }),
      ]));
  }

  void _showCreateRoom(BuildContext context, RoomProvider provider) {
    final controller = TextEditingController();
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _BottomSheet(children: [
          Text('방 이름을 입력해줘', style: GoogleFonts.playfairDisplay(fontSize: 20, color: kText)),
          const SizedBox(height: 20),
          _TextInput(controller: controller, hint: '예) 지민♥수아'),
          const SizedBox(height: 16),
          _PrimaryButton(label: '만들기', onTap: () {
            if (controller.text.isNotEmpty) { provider.createRoom(controller.text); Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('방이 만들어졌어! 💕', style: GoogleFonts.dmSans()), backgroundColor: kRose, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))); }
          }),
        ])));
  }

  void _showJoinRoom(BuildContext context, RoomProvider provider) {
    final controller = TextEditingController();
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _BottomSheet(children: [
          Text('초대 코드 입력', style: GoogleFonts.playfairDisplay(fontSize: 20, color: kText)),
          const SizedBox(height: 8),
          Text('친구에게 받은 6자리 코드를 입력해줘', style: GoogleFonts.dmSans(fontSize: 12, color: kMuted)),
          const SizedBox(height: 20),
          _TextInput(controller: controller, hint: 'XXXXXX', isCode: true),
          const SizedBox(height: 16),
          _PrimaryButton(label: '참가하기', onTap: () {
            final room = provider.findRoomByCode(controller.text);
            Navigator.pop(context);
            if (room != null) { provider.joinRoom(controller.text); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${room.name} 방에 참가했어! 💕', style: GoogleFonts.dmSans()), backgroundColor: kRose, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))); }
            else { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('코드를 찾을 수 없어 😢', style: GoogleFonts.dmSans()), backgroundColor: kMuted, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))); }
          }),
        ])));
  }
}

class _PostItem extends StatelessWidget {
  final PostModel post;
  const _PostItem({required this.post});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: kRoseLt, borderRadius: BorderRadius.circular(18)),
        child: Center(child: Text(post.initial, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: kRoseDk)))),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(color: kBlush, borderRadius: BorderRadius.only(topRight: Radius.circular(14), bottomLeft: Radius.circular(14), bottomRight: Radius.circular(14))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(post.name, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500, color: kRoseDk)),
            const SizedBox(height: 3),
            Text(post.text, style: GoogleFonts.dmSans(fontSize: 11, color: kText, height: 1.4)),
            if (post.hasImage) ...[const SizedBox(height: 8), Container(width: double.infinity, height: 80,
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [kRoseLt, Color(0xFFE8AAB5)]), borderRadius: BorderRadius.circular(10)),
              child: Center(child: Text(post.imageEmoji, style: const TextStyle(fontSize: 28))))],
          ])),
        const SizedBox(height: 4),
        GestureDetector(onTap: () => context.read<PostProvider>().toggleLike(post.id),
          child: Text('${post.time} · ♡ ${post.likes}', style: GoogleFonts.dmSans(fontSize: 10, color: kMuted))),
      ])),
    ]),
  );
}

// ────────────────────────────────────────────────────────────
// 마이페이지 탭
// ────────────────────────────────────────────────────────────
class MypageTab extends StatelessWidget {
  const MypageTab({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>();
    return Scaffold(
      backgroundColor: kCream,
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('MY 페이지', style: GoogleFonts.playfairDisplay(fontSize: 20, color: kText)),
            GestureDetector(onTap: () => _showNotificationSettings(context, user),
              child: Container(width: 36, height: 36, decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(18)),
                child: const Center(child: Text('⚙️', style: TextStyle(fontSize: 16))))),
          ])),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(children: [
          // 프로필 카드
          Container(width: double.infinity, padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [kRose, kRoseDk], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20)),
            child: Column(children: [
              GestureDetector(onTap: () => _showEditProfile(context, user),
                child: Stack(children: [
                  Container(width: 72, height: 72,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(36), border: Border.all(color: Colors.white, width: 2)),
                    child: Center(child: Text(user.avatarEmoji, style: const TextStyle(fontSize: 32)))),
                  Positioned(bottom: 0, right: 0, child: Container(width: 22, height: 22,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(11)),
                    child: const Center(child: Text('✏️', style: TextStyle(fontSize: 11))))),
                ])),
              const SizedBox(height: 12),
              Text(user.name, style: GoogleFonts.playfairDisplay(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(user.email, style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white.withOpacity(0.8))),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _StatItem(label: '저장한 코스', value: '${user.savedCourses.length}'),
                _StatItem(label: '친구', value: '${user.friends.length}'),
                const _StatItem(label: '게시물', value: '8'),
              ]),
            ])),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _SectionLabel('저장한 코스'),
            GestureDetector(onTap: () {}, child: Text('전체보기', style: GoogleFonts.dmSans(fontSize: 11, color: kRose))),
          ]),
          const SizedBox(height: 10),
          ...user.savedCourses.asMap().entries.map((e) => _SavedCourseCard(
            course: e.value, 
            onDelete: () => user.deleteCourse(e.key),
            onTap: () => _showCourseDetail(context, e.value), // 💡 팝업 띄우기 함수 연결
          )),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _SectionLabel('친구'),
            GestureDetector(onTap: () => _showFriendManage(context, user), child: Text('관리', style: GoogleFonts.dmSans(fontSize: 11, color: kRose))),
          ]),
          const SizedBox(height: 10),
          SizedBox(height: 70, child: ListView(scrollDirection: Axis.horizontal, children: [
            ...user.friends.map((f) => _FriendAvatar(name: f['name'], initial: f['initial'])),
            _FriendAvatarAdd(onTap: () => _showFriendManage(context, user)),
          ])),
          const SizedBox(height: 20),
          _SectionLabel('설정'),
          const SizedBox(height: 10),
          _MenuItem(icon: '🔔', label: '알림 설정', onTap: () => _showNotificationSettings(context, user)),
          _MenuItem(icon: '👥', label: '친구 관리', onTap: () => _showFriendManage(context, user)),
          _MenuItem(icon: '🔒', label: '개인정보 보호', onTap: () {}),
          _MenuItem(icon: '📞', label: '고객센터', onTap: () {}),
          _MenuItem(icon: '🚪', label: '로그아웃', onTap: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false), isRed: true),
          const SizedBox(height: 20),
        ]))),
      ])),
    );
  }

  void _showEditProfile(BuildContext context, UserProvider user) {
    final nameCtrl = TextEditingController(text: user.name);
    final emailCtrl = TextEditingController(text: user.email);
    final avatars = ['👤','🐱','🐶','🦊','🐼','🐨','🦋','🌸'];
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: StatefulBuilder(builder: (ctx, setModalState) => _BottomSheet(children: [
          Text('프로필 편집', style: GoogleFonts.playfairDisplay(fontSize: 20, color: kText)),
          const SizedBox(height: 16),
          Wrap(spacing: 12, children: avatars.map((a) => GestureDetector(onTap: () { user.updateAvatar(a); setModalState((){}); },
            child: Container(width: 44, height: 44,
              decoration: BoxDecoration(color: user.avatarEmoji==a ? kBlush : kNude, borderRadius: BorderRadius.circular(22), border: Border.all(color: user.avatarEmoji==a ? kRose : Colors.transparent, width: 2)),
              child: Center(child: Text(a, style: const TextStyle(fontSize: 22)))))).toList()),
          const SizedBox(height: 16),
          _TextInput(controller: nameCtrl, hint: '이름'),
          const SizedBox(height: 10),
          _TextInput(controller: emailCtrl, hint: '이메일'),
          const SizedBox(height: 16),
          _PrimaryButton(label: '저장하기', onTap: () { user.updateName(nameCtrl.text); user.updateEmail(emailCtrl.text); Navigator.pop(context); }),
        ]))));
  }

  void _showFriendManage(BuildContext context, UserProvider user) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => StatefulBuilder(builder: (ctx, setModalState) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: kNude, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('친구 관리', style: GoogleFonts.playfairDisplay(fontSize: 20, color: kText)),
            GestureDetector(onTap: () => _showAddFriend(context, user),
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [kRose, kRoseDk]), borderRadius: BorderRadius.circular(20)),
                child: Text('+ 추가', style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)))),
          ]),
          const SizedBox(height: 16),
          Expanded(child: user.friends.isEmpty
              ? Center(child: Text('친구를 추가해봐요 💕', style: GoogleFonts.dmSans(fontSize: 14, color: kMuted)))
              : ListView.builder(itemCount: user.friends.length, itemBuilder: (ctx, i) {
                  final friend = user.friends[i];
                  return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Container(width: 40, height: 40, decoration: BoxDecoration(color: kRoseLt, borderRadius: BorderRadius.circular(20), border: Border.all(color: kRose, width: 2)),
                        child: Center(child: Text(friend['initial'], style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: kRoseDk)))),
                      const SizedBox(width: 14),
                      Expanded(child: Text(friend['name'], style: GoogleFonts.dmSans(fontSize: 14, color: kText))),
                      GestureDetector(onTap: () { user.removeFriend(i); setModalState((){}); },
                        child: Text('삭제', style: GoogleFonts.dmSans(fontSize: 12, color: kRose))),
                    ]));
                })),
        ]),
      )));
  }

  void _showAddFriend(BuildContext context, UserProvider user) {
    final controller = TextEditingController();
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _BottomSheet(children: [
          Text('친구 추가', style: GoogleFonts.playfairDisplay(fontSize: 20, color: kText)),
          const SizedBox(height: 8),
          Text('친구의 코드를 입력해줘', style: GoogleFonts.dmSans(fontSize: 12, color: kMuted)),
          const SizedBox(height: 12),
          Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(14), border: Border.all(color: kRoseLt, width: 1.5)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('내 코드', style: GoogleFonts.dmSans(fontSize: 11, color: kMuted)),
                const SizedBox(height: 2),
                Text(user.myFriendCode, style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: kRose, letterSpacing: 4)),
              ]),
              GestureDetector(onTap: () { Clipboard.setData(ClipboardData(text: user.myFriendCode)); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('코드가 복사됐어! 💕', style: GoogleFonts.dmSans()), backgroundColor: kRose, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))); },
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7), decoration: BoxDecoration(color: kRose, borderRadius: BorderRadius.circular(20)), child: Text('복사', style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)))),
            ])),
          const SizedBox(height: 16),
          _TextInput(controller: controller, hint: 'XXXXXX', isCode: true),
          const SizedBox(height: 16),
          _PrimaryButton(label: '추가하기', onTap: () {
            final result = user.addFriendByCode(controller.text);
            Navigator.pop(context);
            String msg; Color bg;
            if (result == null) { msg = '코드를 찾을 수 없어 😢'; bg = kMuted; }
            else if (result == 'already') { msg = '이미 친구야! 💕'; bg = kMuted; }
            else { msg = '$result 님과 친구가 됐어! 💕'; bg = kRose; }
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: GoogleFonts.dmSans()), backgroundColor: bg, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
          }),
        ])));
  }

  void _showNotificationSettings(BuildContext context, UserProvider user) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setModalState) => _BottomSheet(children: [
        Text('알림 설정', style: GoogleFonts.playfairDisplay(fontSize: 20, color: kText)),
        const SizedBox(height: 16),
        _NotifItem(title: '푸시 알림', sub: '앱 알림을 받아요', value: user.pushNotification, onChanged: (v) { user.togglePushNotification(v); setModalState((){}); }),
        _NotifItem(title: '친구 활동 알림', sub: '친구가 게시물을 올리면 알려줘요', value: user.friendActivity, onChanged: (v) { user.toggleFriendActivity(v); setModalState((){}); }),
        _NotifItem(title: '코스 추천 알림', sub: '새로운 코스 추천을 받아요', value: user.courseRecommend, onChanged: (v) { user.toggleCourseRecommend(v); setModalState((){}); }),
      ])));
  }
}

class _StatItem extends StatelessWidget {
  final String label, value;
  const _StatItem({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: GoogleFonts.playfairDisplay(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w600)),
    const SizedBox(height: 2),
    Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: Colors.white.withOpacity(0.8))),
  ]);
}

class _SavedCourseCard extends StatelessWidget {
  final Map<String, dynamic> course;
  final VoidCallback onDelete;
  final VoidCallback onTap; // 💡 1. onTap 속성 추가

  const _SavedCourseCard({required this.course, required this.onDelete, required this.onTap}); // 💡 2. 생성자에 필수값으로 추가

  @override
  Widget build(BuildContext context) => GestureDetector( // 💡 3. GestureDetector로 가장 바깥을 감싸기
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(width: 48, height: 48,
          decoration: BoxDecoration(gradient: LinearGradient(colors: [course['color1'], course['color2']]), borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(course['emoji'], style: const TextStyle(fontSize: 22)))),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(course['title'], style: GoogleFonts.playfairDisplay(fontSize: 13, color: kText)),
          const SizedBox(height: 3),
          Text(course['sub'], style: GoogleFonts.dmSans(fontSize: 11, color: kMuted)),
        ])),
        GestureDetector(onTap: onDelete, child: const Text('🗑️', style: TextStyle(fontSize: 16))), // 휴지통 삭제 기능은 유지
      ]),
    ),
  );
}

class _MenuItem extends StatelessWidget {
  final String icon, label;
  final VoidCallback onTap;
  final bool isRed;
  const _MenuItem({required this.icon, required this.label, required this.onTap, this.isRed = false});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Text(icon, style: const TextStyle(fontSize: 18)), const SizedBox(width: 14),
        Expanded(child: Text(label, style: GoogleFonts.dmSans(fontSize: 13, color: isRed ? kRose : kText))),
        Text('→', style: TextStyle(color: isRed ? kRose : kMuted)),
      ])),
  );
}

class _NotifItem extends StatelessWidget {
  final String title, sub;
  final bool value;
  final Function(bool) onChanged;
  const _NotifItem({required this.title, required this.sub, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(14)),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: GoogleFonts.dmSans(fontSize: 13, color: kText, fontWeight: FontWeight.w500)),
        const SizedBox(height: 3),
        Text(sub, style: GoogleFonts.dmSans(fontSize: 11, color: kMuted)),
      ])),
      Switch(value: value, onChanged: onChanged, activeColor: kRose),
    ]),
  );
}

// ────────────────────────────────────────────────────────────
// 공통 위젯
// ────────────────────────────────────────────────────────────
class _BottomSheet extends StatelessWidget {
  final List<Widget> children;
  const _BottomSheet({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(28),
    decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 40, height: 4, decoration: BoxDecoration(color: kNude, borderRadius: BorderRadius.circular(2))),
      const SizedBox(height: 20),
      ...children,
      const SizedBox(height: 12),
    ]),
  );
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineButton({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(28), border: Border.all(color: kRoseLt, width: 1.5)),
      child: Text(label, textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500, color: kRose))),
  );
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isCode;
  const _TextInput({required this.controller, required this.hint, this.isCode = false});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    textCapitalization: isCode ? TextCapitalization.characters : TextCapitalization.none,
    textAlign: isCode ? TextAlign.center : TextAlign.start,
    maxLength: isCode ? 6 : null,
    style: isCode
        ? GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: kRose, letterSpacing: 4)
        : GoogleFonts.dmSans(fontSize: 14, color: kText),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: isCode ? GoogleFonts.dmSans(fontSize: 20, color: kMuted, letterSpacing: 4) : GoogleFonts.dmSans(color: kMuted),
      filled: true, fillColor: isCode ? kBlush : kNude,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    ),
  );
}

// ────────────────────────────────────────────────────────────
// 후기 탭 (유다예 브랜치)
// Firebase Firestore 기반 장소 후기 작성/조회/수정/삭제
// ────────────────────────────────────────────────────────────
class ReviewTab extends StatefulWidget {
  const ReviewTab({super.key});
  @override
  State<ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<ReviewTab> {
  static const String _kakaoRestApiKey = '8ddff68bae409484fe211e99220c0bd1';
  static const String _sbizServiceKey =
      'bcc7bd3642c235f3be36850b43c02c5a5e59c26871dc48502273a47c569644c3';

  static const Map<String, String> _regionCodeMap = {
    '종로구': '11110', '중구': '11140', '용산구': '11170', '성동구': '11200',
    '광진구': '11215', '동대문구': '11230', '중랑구': '11260', '성북구': '11290',
    '강북구': '11305', '도봉구': '11320', '노원구': '11350', '은평구': '11380',
    '서대문구': '11410', '마포구': '11440', '양천구': '11470', '강서구': '11500',
    '구로구': '11530', '금천구': '11545', '영등포구': '11560', '동작구': '11590',
    '관악구': '11620', '서초구': '11650', '강남구': '11680', '송파구': '11710',
    '강동구': '11740',
  };

  final TextEditingController _regionController = TextEditingController();
  final TextEditingController _keywordController = TextEditingController();

  List<dynamic> _places = [];
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) _loadCommentMarkers();
    });
  }

  @override
  void dispose() {
    _regionController.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _searchPlaces() async {
    final region = _regionController.text.trim();
    final keyword = _keywordController.text.trim();
    if (region.isEmpty) return;

    final regionCode = _regionCodeMap[region];
    if (regionCode == null) {
      setState(() => _errorMessage = '지원하지 않는 지역입니다.\n예: 성북구, 강남구, 마포구');
      return;
    }

    setState(() { _isLoading = true; _errorMessage = ''; _places = []; });
    globalContext.callMethod('clearCommentMarkers'.toJS);

    List<dynamic> allResults = [];
    try {
      for (int page = 1; page <= 10; page++) {
        final uri = Uri.parse(
          'https://apis.data.go.kr/B553077/api/open/sdsc2/storeListInDong'
          '?serviceKey=$_sbizServiceKey'
          '&pageNo=$page&numOfRows=100&type=json'
          '&divId=signguCd&key=$regionCode',
        );
        final response = await http.get(uri);
        final data = jsonDecode(response.body);
        final items = data['body']['items'];
        if (items == null || (items as List).isEmpty) break;

        final filtered = items.where((store) {
          final name = store['bizesNm']?.toString() ?? '';
          final small = store['indsSclsNm']?.toString() ?? '';
          final middle = store['indsMclsNm']?.toString() ?? '';
          return keyword.isEmpty ||
              name.contains(keyword) ||
              small.contains(keyword) ||
              middle.contains(keyword);
        }).toList();

        allResults.addAll(filtered);
        if (allResults.length >= 200) break; // 너무 많으면 제한
      }
      setState(() => _places = allResults);
      if (allResults.isNotEmpty) _showPlaceOnMap(allResults[0]);
    } catch (e) {
      setState(() => _errorMessage = '검색 오류: $e');
    } finally {
      setState(() => _isLoading = false);
      await _loadCommentMarkers();
    }
  }

  void _showPlaceOnMap(dynamic store) {
    final lat = double.tryParse(store['lat']?.toString() ?? '');
    final lng = double.tryParse(store['lon']?.toString() ?? '');
    if (lat == null || lng == null) return;
    globalContext.callMethod('moveReviewMapTo'.toJS, lat.toJS, lng.toJS);
  }

  Future<void> _loadCommentMarkers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('place_comments').get();

      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final lat = data['latitude'], lng = data['longitude'];
        if (lat == null || lng == null) continue;
        final key = '${lat}_$lng';
        grouped.putIfAbsent(key, () => []).add(data);
      }

      globalContext.callMethod('clearCommentMarkers'.toJS);

      grouped.forEach((key, reviews) {
        final first = reviews.first;
        final placeName = (first['placeName'] ?? '상호명 없음').toString();
        final lat = first['latitude'].toString();
        final lng = first['longitude'].toString();
        final avgRating = reviews
            .map((r) => (r['rating'] ?? 5) as num)
            .reduce((a, b) => a + b) / reviews.length;
        final commentsText = reviews.map((r) {
          final username = r['username'] ?? '익명';
          final rating = r['rating'] ?? 5;
          final comment = r['comment'] ?? '';
          return '⭐ $rating | $username: $comment';
        }).join('<br/><br/>');

        globalContext.callMethod(
          'addCommentMarker'.toJS,
          lat.toJS, lng.toJS,
          '<b>$placeName</b><br/>⭐ ${avgRating.toStringAsFixed(1)} · 후기 ${reviews.length}개'.toJS,
          commentsText.toJS,
        );
      });
    } catch (e) {
      debugPrint('후기 마커 로드 오류: $e');
    }
  }

  Future<void> _showCommentDialog(BuildContext context, dynamic place) async {
    final commentController = TextEditingController();
    double rating = 5;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(place['bizesNm'] ?? '상호명 없음',
              style: GoogleFonts.playfairDisplay(fontSize: 16, color: kText)),
            const SizedBox(height: 2),
            Text(place['rdnmAdr'] ?? place['lnoAdr'] ?? '',
              style: GoogleFonts.dmSans(fontSize: 11, color: kMuted)),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) => IconButton(
                onPressed: () => setDialogState(() => rating = (i + 1).toDouble()),
                icon: Icon(
                  (i + 1) <= rating ? Icons.star : Icons.star_border,
                  color: const Color(0xFFFFB800), size: 28,
                ),
                padding: EdgeInsets.zero, constraints: const BoxConstraints(),
              ))),
            const SizedBox(height: 12),
            TextField(
              controller: commentController, maxLines: 4,
              style: GoogleFonts.dmSans(fontSize: 13, color: kText),
              decoration: InputDecoration(
                hintText: '이 장소에 대한 후기를 남겨주세요',
                hintStyle: GoogleFonts.dmSans(fontSize: 13, color: kMuted),
                filled: true, fillColor: kNude,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
              child: Text('취소', style: GoogleFonts.dmSans(color: kMuted))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kRose, foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              onPressed: () async {
                final comment = commentController.text.trim();
                if (comment.isEmpty) return;
                final loggedInId = Provider.of<UserProvider>(context, listen: false).loggedInUsername ?? '익명';
                await FirebaseFirestore.instance.collection('place_comments').add({
                  'uid': loggedInId,
                  'username': loggedInId,
                  'placeName': place['bizesNm'] ?? '상호명 없음',
                  'address': place['rdnmAdr'] ?? place['lnoAdr'] ?? '',
                  'comment': comment,
                  'rating': rating,
                  'latitude': double.tryParse(place['lat']?.toString() ?? ''),
                  'longitude': double.tryParse(place['lon']?.toString() ?? ''),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                if (context.mounted) Navigator.pop(context);
                await _loadCommentMarkers();
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(SnackBar(
                    content: Text('후기가 등록됐어요! 💕', style: GoogleFonts.dmSans()),
                    backgroundColor: kRose, behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                }
              },
              child: Text('저장', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMyComments(BuildContext context) async {
    final username = Provider.of<UserProvider>(context, listen: false).loggedInUsername;
    if (username == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('place_comments').where('username', isEqualTo: username).get();

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx2, setS) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('내 후기 목록', style: GoogleFonts.playfairDisplay(fontSize: 18, color: kText)),
        content: SizedBox(
          width: 400, height: 400,
          child: snapshot.docs.isEmpty
              ? Center(child: Text('아직 작성한 후기가 없어요 🌸', style: GoogleFonts.dmSans(color: kMuted)))
              : ListView(children: snapshot.docs.map((doc) {
                  final data = doc.data();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(12)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(data['placeName'] ?? '', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: kText)),
                      const SizedBox(height: 4),
                      Text('⭐ ${data['rating']} · ${data['comment'] ?? ''}',
                        style: GoogleFonts.dmSans(fontSize: 12, color: kMuted)),
                      const SizedBox(height: 8),
                      Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                        GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx2);
                            _editComment(context, doc.id, data['comment'] ?? '');
                          },
                          child: Text('수정', style: GoogleFonts.dmSans(fontSize: 12, color: kRose))),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () async {
                            await FirebaseFirestore.instance
                                .collection('place_comments').doc(doc.id).delete();
                            await _loadCommentMarkers();
                            if (ctx2.mounted) Navigator.pop(ctx2);
                            _showMyComments(context);
                          },
                          child: Text('삭제', style: GoogleFonts.dmSans(fontSize: 12, color: Colors.red))),
                      ]),
                    ]),
                  );
                }).toList()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx2),
            child: Text('닫기', style: GoogleFonts.dmSans(color: kMuted))),
        ],
      )),
    );
  }

  Future<void> _editComment(BuildContext context, String docId, String oldComment) async {
    final controller = TextEditingController(text: oldComment);
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('후기 수정', style: GoogleFonts.playfairDisplay(fontSize: 18, color: kText)),
        content: TextField(
          controller: controller, maxLines: 4,
          style: GoogleFonts.dmSans(fontSize: 13, color: kText),
          decoration: InputDecoration(
            filled: true, fillColor: kNude,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
            child: Text('취소', style: GoogleFonts.dmSans(color: kMuted))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kRose, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('place_comments').doc(docId)
                  .update({'comment': controller.text.trim(), 'updatedAt': FieldValue.serverTimestamp()});
              if (context.mounted) Navigator.pop(context);
              await _loadCommentMarkers();
            },
            child: Text('수정', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCream,
      body: Row(children: [
        // ── 왼쪽 패널 ──
        SizedBox(
          width: 400,
          child: SafeArea(child: Column(children: [
            // 상단바
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('⭐ 장소 후기', style: GoogleFonts.playfairDisplay(fontSize: 20, color: kText)),
                GestureDetector(
                  onTap: () => _showMyComments(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [kRose, kRoseDk]),
                      borderRadius: BorderRadius.circular(20)),
                    child: Text('내 후기', style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                  )),
              ])),
            // 안내
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(8)),
              child: Text('🗺️ 지역과 업종을 검색해서 장소를 찾고\n후기를 남겨보세요! 지도에 마커로 표시돼요.',
                style: GoogleFonts.dmSans(fontSize: 11, color: kRoseDk, height: 1.5))),
            // 검색
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                TextField(
                  controller: _regionController,
                  style: GoogleFonts.dmSans(fontSize: 13, color: kText),
                  decoration: InputDecoration(
                    hintText: '지역 입력 (예: 성북구, 강남구)',
                    hintStyle: GoogleFonts.dmSans(fontSize: 13, color: kMuted),
                    prefixIcon: const Icon(Icons.location_on, color: kRose, size: 20),
                    filled: true, fillColor: kNude,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  )),
                const SizedBox(height: 8),
                TextField(
                  controller: _keywordController,
                  style: GoogleFonts.dmSans(fontSize: 13, color: kText),
                  decoration: InputDecoration(
                    hintText: '업종 키워드 (예: 카페, 식당)',
                    hintStyle: GoogleFonts.dmSans(fontSize: 13, color: kMuted),
                    prefixIcon: const Icon(Icons.search, color: kMuted, size: 20),
                    filled: true, fillColor: kNude,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  onSubmitted: (_) => _searchPlaces()),
                const SizedBox(height: 10),
                SizedBox(width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _searchPlaces,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kRose, foregroundColor: Colors.white, elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                    child: Text('검색', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500)))),
              ])),
            const SizedBox(height: 8),
            // 결과
            Expanded(child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: kRose))
                : _errorMessage.isNotEmpty
                    ? Center(child: Padding(padding: const EdgeInsets.all(20),
                        child: Text(_errorMessage, style: GoogleFonts.dmSans(color: Colors.red), textAlign: TextAlign.center)))
                    : _places.isEmpty
                        ? Center(child: Text('지역과 업종을 입력하고\n검색해보세요!',
                            textAlign: TextAlign.center, style: GoogleFonts.dmSans(color: kMuted, height: 1.8)))
                        : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              child: Text('검색 결과 ${_places.length}개',
                                style: GoogleFonts.dmSans(fontSize: 11, color: kMuted, fontWeight: FontWeight.w500))),
                            Expanded(child: ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _places.length,
                              itemBuilder: (ctx, i) {
                                final place = _places[i];
                                return GestureDetector(
                                  onTap: () {
                                    _showPlaceOnMap(place);
                                    _showCommentDialog(context, place);
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: kNude)),
                                    child: Row(children: [
                                      Container(width: 36, height: 36,
                                        decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(10)),
                                        child: const Center(child: Text('🏪', style: TextStyle(fontSize: 18)))),
                                      const SizedBox(width: 10),
                                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(place['bizesNm'] ?? '상호명 없음',
                                          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: kText)),
                                        const SizedBox(height: 2),
                                        Text(place['rdnmAdr'] ?? place['lnoAdr'] ?? '',
                                          style: GoogleFonts.dmSans(fontSize: 11, color: kMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        Text('${place['indsMclsNm'] ?? ''} · ${place['indsSclsNm'] ?? ''}',
                                          style: GoogleFonts.dmSans(fontSize: 10, color: kMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      ])),
                                      const Icon(Icons.chevron_right, color: kRoseLt, size: 18),
                                    ]),
                                  ),
                                );
                              },
                            )),
                          ])),
          ])),
        ),
        const VerticalDivider(width: 1),
        // ── 오른쪽 지도 ──
        const Expanded(child: HtmlElementView(viewType: 'kakao-review-map-view')),
      ]),
    );
  }
}


void _showCourseDetail(BuildContext context, Map<String, dynamic> course) {
  // 💡 저장된 상세 코스(steps)들을 불러옵니다.
  final steps = course['steps'] as List<CourseStep>? ?? [];

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      height: MediaQuery.of(context).size.height * 0.75, // 높이를 살짝 키웠어요
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: kNude, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 24),
          // 헤더: 타이틀과 아이콘
          Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [course['color1'], course['color2']]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(child: Text(course['emoji'], style: const TextStyle(fontSize: 28))),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course['title'], style: GoogleFonts.playfairDisplay(fontSize: 20, color: kText, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(course['sub'], style: GoogleFonts.dmSans(fontSize: 13, color: kMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // 💡 여기에 진짜 코스 타임라인이 그려집니다!
          Expanded(
            child: steps.isEmpty
                ? Center(
                    child: Text('상세 코스 정보가 없습니다.\n(새로 저장한 코스부터 타임라인이 표시됩니다!)',
                        textAlign: TextAlign.center, style: GoogleFonts.dmSans(color: kMuted, height: 1.5)))
                : ListView.builder(
                    itemCount: steps.length,
                    itemBuilder: (ctx, i) {
                      final step = steps[i];
                      final isLast = i == steps.length - 1;
                      final placeName = step.place?.name ?? step.description;

                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 왼쪽: 타임라인 동그라미 & 세로 선
                            SizedBox(
                              width: 40,
                              child: Column(
                                children: [
                                  Container(
                                    width: 32, height: 32,
                                    decoration: const BoxDecoration(color: kRose, shape: BoxShape.circle),
                                    child: Center(child: Text(step.emoji, style: const TextStyle(fontSize: 16))),
                                  ),
                                  if (!isLast)
                                    Expanded(
                                      child: Container(width: 2, color: kRoseLt, margin: const EdgeInsets.symmetric(vertical: 4)),
                                    ),
                                ],
                              ),
                            ),
                            // 오른쪽: 장소 상세 정보
                            Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(bottom: isLast ? 0 : 20, left: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(step.time, style: GoogleFonts.dmSans(fontSize: 13, color: kMuted, fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 8),
                                        Text(step.type, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold, color: kText)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(14), border: Border.all(color: kRoseLt)),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(placeName, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold, color: kText)),
                                                if (step.place != null) ...[
                                                  const SizedBox(height: 2),
                                                  Text(step.place!.roadAddress.isNotEmpty ? step.place!.roadAddress : step.place!.address,
                                                    style: GoogleFonts.dmSans(fontSize: 11, color: kMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                                                ]
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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