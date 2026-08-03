// ============================================================
// Datefit — 이지민_찐최종 + 이윤서 + 유다예 합본
// Flutter Web 전용
// 💡 병합: Firebase 인증/Firestore 연동 최종본(main__6_)을 기반으로,
//         서울 전체 동(洞) 단위 지역 인식 + "성수 추천" 같은 자연스러운
//         표현도 코스 생성 트리거로 잡히도록 개선한 로직(main__2_)을 통합
// ============================================================
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
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
// 로그인 사용자 식별 (Firestore users 컬렉션 기반 로그인)
// 로그인/회원가입 시 이 값이 채워지고, 방·게시물·후기가 이 아이디를 사용
// ────────────────────────────────────────────────────────────
class CurrentUser {
  static String? id; // 로그인한 아이디
  static String get idOrAnon => id ?? '익명';
}

// 사람마다 다른 6자리 친구 코드를 생성 (Firestore에 중복이 없을 때까지 재시도)
Future<String> generateUniqueFriendCode() async {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rnd = math.Random();
  for (int attempt = 0; attempt < 10; attempt++) {
    final code = List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join();
    try {
      final existing = await FirebaseFirestore.instance
          .collection('users')
          .where('friendCode', isEqualTo: code)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) return code;
    } catch (_) {
      return code; // 조회 실패 시에도 진행을 막지 않도록 생성한 코드를 그대로 사용
    }
  }
  // 매우 드문 경우: 타임스탬프 기반 코드로 대체
  return DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
}

// ────────────────────────────────────────────────────────────
// uid로 닉네임(Firestore 문서 id) 역조회
// users 컬렉션은 닉네임이 문서 id이므로, 로그인 시 Firebase의 uid를 가지고
// 해당 유저의 닉네임을 찾기 위해 uid 필드로 검색함
// ────────────────────────────────────────────────────────────
Future<String?> fetchNicknameByUid(String uid) async {
  final query = await FirebaseFirestore.instance
      .collection('users')
      .where('uid', isEqualTo: uid)
      .limit(1)
      .get();
  if (query.docs.isEmpty) return null;
  return query.docs.first.id;
}

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
  final String roomId;
  final String initial;
  final String name;
  final String text;
  final bool hasImage;
  final String imageEmoji;
  final Uint8List? imageBytes; // 첨부한 실제 사진 데이터 (웹)
  final String imageBase64;    // Firestore 저장/복원용 사진 (base64)
  final String time;
  int likes;
  List<String> likedBy;
  PostModel({required this.id, this.roomId = '', required this.initial, required this.name,
    required this.text, this.hasImage = false, this.imageEmoji = '',
    this.imageBytes, this.imageBase64 = '', required this.time, this.likes = 0, this.likedBy = const []});
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

  String _roomId = '';
  StreamSubscription? _sub;

  // 현재 보고 있는 방을 지정하면 그 방의 게시물만 실시간으로 불러옴
  void watchRoom(String roomId) {
    if (roomId == _roomId) return;
    _roomId = roomId;
    _sub?.cancel();
    _posts.clear();
    notifyListeners();
    if (roomId.isEmpty) return;
    _sub = FirebaseFirestore.instance
        .collection('room_posts')
        .where('roomId', isEqualTo: roomId)
        .snapshots()
        .listen((snap) {
      final list = snap.docs.map((d) {
        final data = d.data();
        final b64 = (data['imageBase64'] ?? '') as String;
        Uint8List? bytes;
        if (b64.isNotEmpty) { try { bytes = base64Decode(b64); } catch (_) {} }
        return PostModel(
          id: d.id,
          roomId: (data['roomId'] ?? '') as String,
          initial: (data['initial'] ?? '나') as String,
          name: (data['name'] ?? '') as String,
          text: (data['text'] ?? '') as String,
          hasImage: (data['hasImage'] ?? false) as bool,
          imageEmoji: (data['imageEmoji'] ?? '') as String,
          imageBytes: bytes,
          imageBase64: b64,
          time: (data['time'] ?? '') as String,
          likes: (data['likes'] ?? 0) as int,
          likedBy: List<String>.from(data['likedBy'] ?? const []),
        );
      }).toList();
      // 작성 시각(createdAtMs) 오름차순 정렬
      final order = <String, int>{};
      for (final d in snap.docs) {
        final v = d.data()['createdAtMs'];
        order[d.id] = (v is int) ? v : 0;
      }
      list.sort((a, b) => (order[a.id] ?? 0).compareTo(order[b.id] ?? 0));
      _posts
        ..clear()
        ..addAll(list);
      notifyListeners();
    });
  }

  Future<void> addPost({required String text, String? place, bool hasImage = false, String imageEmoji = '', Uint8List? imageBytes}) async {
    if (_roomId.isEmpty) return;
    final now = TimeOfDay.now();
    final h = now.hour > 12 ? now.hour - 12 : now.hour;
    final m = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    final b64 = imageBytes != null ? base64Encode(imageBytes) : '';
    await FirebaseFirestore.instance.collection('room_posts').add({
      'roomId': _roomId,
      'initial': CurrentUser.idOrAnon.isNotEmpty ? CurrentUser.idOrAnon[0] : '나',
      'name': CurrentUser.idOrAnon,
      'text': place != null ? '$text\n📍 $place' : text,
      'hasImage': hasImage || imageBytes != null,
      'imageEmoji': hasImage ? imageEmoji : '',
      'imageBase64': b64,
      'time': '$h:$m $period',
      'likes': 0,
      'likedBy': <String>[],
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // 실시간 리스너가 목록을 갱신함
  }

  Future<void> toggleLike(String id) async {
    final post = _posts.firstWhere((p) => p.id == id, orElse: () => PostModel(id: '', initial: '', name: '', text: '', time: ''));
    if (post.id.isEmpty) return;
    final me = CurrentUser.idOrAnon;
    final docRef = FirebaseFirestore.instance.collection('room_posts').doc(id);
    if (post.likedBy.contains(me)) {
      // 이미 좋아요 누른 상태 → 취소
      await docRef.update({
        'likedBy': FieldValue.arrayRemove([me]),
        'likes': FieldValue.increment(-1),
      });
    } else {
      // 아직 안 눌렀으면 → 좋아요
      await docRef.update({
        'likedBy': FieldValue.arrayUnion([me]),
        'likes': FieldValue.increment(1),
      });
    }
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }
}

class RoomProvider extends ChangeNotifier {
  final List<RoomModel> _rooms = [];
  int _selectedIndex = 0;
  bool _loaded = false;
  StreamSubscription? _sub;

  List<RoomModel> get rooms => _rooms;
  bool get isLoaded => _loaded;
  bool get hasRooms => _rooms.isNotEmpty;
  RoomModel? get currentRoom => (_rooms.isEmpty || _selectedIndex >= _rooms.length) ? null : _rooms[_selectedIndex];
  int get selectedIndex => _selectedIndex;

  // 로그인한 아이디를 사용자 식별자로 사용
  String get _myName => CurrentUser.idOrAnon;
  String get _myUid => CurrentUser.idOrAnon;

  RoomProvider();

  // 로그인 후 호출 — 해당 사용자의 방 구독 시작
  void startForUser() {
    _sub?.cancel();
    _loaded = false;
    _rooms.clear();
    _selectedIndex = 0;
    notifyListeners();
    _start();
  }

  // 로그아웃 시 호출 — 구독 해제 및 초기화
  void clear() {
    _sub?.cancel();
    _sub = null;
    _rooms.clear();
    _selectedIndex = 0;
    _loaded = false;
    notifyListeners();
  }

  void _start() {
    final uid = _myUid;
    if (uid.isEmpty || uid == '익명') { _loaded = true; notifyListeners(); return; }
    // 내가 멤버로 속한 방만 실시간 구독
    _sub = FirebaseFirestore.instance
        .collection('rooms')
        .where('memberUids', arrayContains: uid)
        .snapshots()
        .listen((snap) {
      final docs = snap.docs.toList()
        ..sort((a, b) {
          final av = a.data()['createdAtMs']; final bv = b.data()['createdAtMs'];
          return ((av is int ? av : 0)).compareTo(bv is int ? bv : 0);
        });
      _rooms
        ..clear()
        ..addAll(docs.map((d) {
          final data = d.data();
          return RoomModel(
            id: d.id,
            name: (data['name'] ?? '') as String,
            inviteCode: (data['inviteCode'] ?? '') as String,
            members: List<String>.from((data['members'] ?? []) as List),
          );
        }));
      if (_selectedIndex >= _rooms.length) _selectedIndex = _rooms.isEmpty ? 0 : _rooms.length - 1;
      _loaded = true;
      notifyListeners();
    });
  }

  void selectRoom(int i) { _selectedIndex = i; notifyListeners(); }

  Future<RoomModel?> _findDocByCode(String code) async {
    final q = await FirebaseFirestore.instance.collection('rooms')
        .where('inviteCode', isEqualTo: code.toUpperCase()).limit(1).get();
    if (q.docs.isEmpty) return null;
    final d = q.docs.first; final data = d.data();
    return RoomModel(id: d.id, name: (data['name'] ?? '') as String,
      inviteCode: (data['inviteCode'] ?? '') as String,
      members: List<String>.from((data['members'] ?? []) as List));
  }

  // 초대코드로 방 찾기 (가입 가능 여부 확인용)
  Future<RoomModel?> findRoomByCode(String code) => _findDocByCode(code);

  Future<bool> joinRoom(String code) async {
    final q = await FirebaseFirestore.instance.collection('rooms')
        .where('inviteCode', isEqualTo: code.toUpperCase()).limit(1).get();
    if (q.docs.isEmpty) return false;
    final doc = q.docs.first;
    await doc.reference.update({
      'members': FieldValue.arrayUnion([_myName]),
      'memberUids': FieldValue.arrayUnion([_myUid]),
    });
    return true;
  }

  Future<void> createRoom(String name) async {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = math.Random();
    final code = List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
    await FirebaseFirestore.instance.collection('rooms').add({
      'name': name,
      'inviteCode': code,
      'members': [_myName],
      'memberUids': [_myUid],
      'createdAtMs': DateTime.now().millisecondsSinceEpoch,
      'createdAt': FieldValue.serverTimestamp(),
    });
    // 새 방이 리스트에 들어오면 그 방으로 선택 (다음 스냅샷에서 반영)
  }

  // 방에서 나가기 — 내 멤버 정보만 제거 (방과 게시물은 남음)
  Future<void> leaveRoom(String roomId) async {
    if (_selectedIndex > 0) _selectedIndex -= 1;
    await FirebaseFirestore.instance.collection('rooms').doc(roomId).update({
      'members': FieldValue.arrayRemove([_myName]),
      'memberUids': FieldValue.arrayRemove([_myUid]),
    });
  }

  // 방 삭제 — 방과 그 방의 모든 게시물을 완전히 삭제
  Future<void> deleteRoom(String roomId) async {
    if (_selectedIndex > 0) _selectedIndex -= 1;
    final fs = FirebaseFirestore.instance;
    // 해당 방의 게시물 모두 삭제
    final posts = await fs.collection('room_posts').where('roomId', isEqualTo: roomId).get();
    for (final doc in posts.docs) {
      await doc.reference.delete();
    }
    // 방 문서 삭제
    await fs.collection('rooms').doc(roomId).delete();
  }

  @override
  void dispose() { _sub?.cancel(); super.dispose(); }
}

class UserProvider extends ChangeNotifier {
  String _name = '이윤서';
  String _email = '';
  String _avatarEmoji = '👤';
  bool _push = true, _friendAct = true, _courseRec = false;
  String _myCode = '';

  // 로그인한 사용자 아이디
  String? _loggedInUsername;
  String? get loggedInUsername => _loggedInUsername;

  void setLoggedInUser(String username) {
    _loggedInUsername = username;
    _name = username; 
    CurrentUser.id = username;
    _fetchUserData(); // 💡 DB에서 코스와 친구 목록 불러오기
    _watchPostCount(); // 💡 내가 쓴 게시물 수 실시간 반영
    notifyListeners();
  }

  // ─── 💡 내가 작성한 게시물 수를 실시간으로 반영 ───
  void _watchPostCount() {
    _postCountSub?.cancel();
    if (_loggedInUsername == null) return;
    _postCountSub = FirebaseFirestore.instance
        .collection('room_posts')
        .where('name', isEqualTo: _loggedInUsername)
        .snapshots()
        .listen((snap) {
      _postCount = snap.docs.length;
      notifyListeners();
    }, onError: (e) => debugPrint('게시물 수 불러오기 오류: $e'));
  }

  void logout() {
    _loggedInUsername = null;
    CurrentUser.id = null;
    _savedCourses.clear(); 
    _friends.clear(); // 💡 로그아웃 시 친구 목록도 비우기
    _email = '';
    _postCountSub?.cancel();
    _postCount = 0;
    notifyListeners();
  }

  final List<Map<String, dynamic>> _savedCourses = [];
  List<Map<String, dynamic>> _friends = []; // 💡 하드코딩된 친구 목록을 비우고 DB에서 불러옵니다.

  // 💡 실제 작성한 게시물 수 (Firestore room_posts 실시간 카운트)
  int _postCount = 0;
  StreamSubscription? _postCountSub;
  int get postCount => _postCount;

  String get name => _name;
  String get email => _email;
  String get avatarEmoji => _avatarEmoji;
  bool get pushNotification => _push;
  bool get friendActivity => _friendAct;
  bool get courseRecommend => _courseRec;
  String get myFriendCode => _myCode;
  List<Map<String, dynamic>> get savedCourses => _savedCourses;
  List<Map<String, dynamic>> get friends => _friends;

  void updateName(String v) { _name = v; notifyListeners(); }
  void updateEmail(String v) {
    _email = v;
    notifyListeners();
    if (_loggedInUsername != null) {
      FirebaseFirestore.instance.collection('users').doc(_loggedInUsername).set(
        {'email': v}, SetOptions(merge: true),
      ).catchError((e) => debugPrint('이메일 저장 오류: $e'));
    }
  }
  void updateAvatar(String v) { _avatarEmoji = v; notifyListeners(); }
  void togglePushNotification(bool v) { _push = v; notifyListeners(); }
  void toggleFriendActivity(bool v) { _friendAct = v; notifyListeners(); }
  void toggleCourseRecommend(bool v) { _courseRec = v; notifyListeners(); }
  
  void removeFriend(int i) { 
    _friends.removeAt(i); 
    _syncFriendsToFirestore(); // 💡 친구 삭제 시 DB에서도 영구 삭제
    notifyListeners(); 
  }
  
  void deleteCourse(int i) { 
    _savedCourses.removeAt(i); 
    _syncCoursesToFirestore(); 
    notifyListeners(); 
  }
  
  void addCourse(Map<String, dynamic> course) {
    _savedCourses.insert(0, course);
    _syncCoursesToFirestore(); 
    notifyListeners();
  }

  Future<String?> addFriendByCode(String code) async {
    final upper = code.trim().toUpperCase();
    if (upper.isEmpty) return null;
    if (upper == _myCode) return 'self';
    try {
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('friendCode', isEqualTo: upper)
          .limit(1)
          .get();
      if (query.docs.isEmpty) return null;
      final friendId = query.docs.first.id;
      if (friendId == _loggedInUsername) return 'self';
      if (_friends.any((f) => f['name'] == friendId)) return 'already';
      final friend = {'initial': friendId.isNotEmpty ? friendId[0] : '?', 'name': friendId};
      _friends.add(friend);
      _syncFriendsToFirestore(); // 💡 친구 추가 시 DB에 저장
      notifyListeners();
      return friendId;
    } catch (e) {
      debugPrint('친구 추가 오류: $e');
      return null;
    }
  }

  // ─── 💡 친구 목록 DB 동기화 ───
  Future<void> _syncFriendsToFirestore() async {
    if (_loggedInUsername == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(_loggedInUsername).set(
        {'friends': _friends}, SetOptions(merge: true)
      );
    } catch (e) {
      debugPrint('친구 저장 오류: $e');
    }
  }

  // ─── 💡 코스 DB 동기화 ───
  Future<void> _syncCoursesToFirestore() async {
    if (_loggedInUsername == null) return;
    try {
      final serialized = _savedCourses.map((c) => {
        'emoji': c['emoji'],
        'color1': (c['color1'] as Color).value,
        'color2': (c['color2'] as Color).value,
        'title': c['title'],
        'sub': c['sub'],
        'steps': (c['steps'] as List<CourseStep>).map((s) => {
          'time': s.time, 'emoji': s.emoji, 'type': s.type, 'band': s.band,
          'duration': s.duration, 'description': s.description,
          'searchQuery': s.searchQuery, 'categoryCode': s.categoryCode, 'engine': s.engine,
          'isSearching': s.isSearching, 'travelMinutesFromPrev': s.travelMinutesFromPrev,
          'place': s.place == null ? null : {
            'name': s.place!.name, 'address': s.place!.address, 'roadAddress': s.place!.roadAddress,
            'category': s.place!.category, 'phone': s.place!.phone, 'lat': s.place!.lat, 'lng': s.place!.lng,
            'source': s.place!.source, 'placeUrl': s.place!.placeUrl, 'openHours': s.place!.openHours,
          }
        }).toList()
      }).toList();
      
      await FirebaseFirestore.instance.collection('users').doc(_loggedInUsername).set(
        {'savedCourses': serialized}, SetOptions(merge: true)
      );
    } catch (e) {
      debugPrint('코스 저장 오류: $e');
    }
  }

  // ─── 💡 DB에서 데이터 불러오기 (친구 + 코스) ───
  Future<void> _fetchUserData() async {
    if (_loggedInUsername == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(_loggedInUsername).get();
      if (doc.exists) {
        final data = doc.data()!;

        // 0. 이메일 불러오기 (직접 설정한 값이 있을 때만)
        _email = (data['email'] ?? '') as String;

        // 0-1. 내 친구 코드 불러오기 (기존 계정이라 코드가 없으면 새로 발급 후 저장)
        final existingCode = (data['friendCode'] ?? '') as String;
        if (existingCode.isNotEmpty) {
          _myCode = existingCode;
        } else {
          _myCode = await generateUniqueFriendCode();
          FirebaseFirestore.instance.collection('users').doc(_loggedInUsername).set(
            {'friendCode': _myCode}, SetOptions(merge: true),
          ).catchError((e) => debugPrint('친구 코드 저장 오류: $e'));
        }

        // 1. 친구 목록 불러오기
        if (data.containsKey('friends')) {
          _friends = List<Map<String, dynamic>>.from(data['friends']);
        } else {
          // 처음 가입한 유저는 친구 목록이 비어있는 상태로 시작
          _friends = [];
        }

        // 2. 코스 목록 불러오기
        if (data.containsKey('savedCourses')) {
          _savedCourses.clear();
          final coursesData = data['savedCourses'] as List;
          
          for (var c in coursesData) {
            _savedCourses.add({
              'emoji': c['emoji'] ?? '📍',
              'color1': Color((c['color1'] as num).toInt()),
              'color2': Color((c['color2'] as num).toInt()),
              'title': c['title'] ?? '',
              'sub': c['sub'] ?? '',
              'steps': (c['steps'] as List).map((s) {
                final p = s['place'];
                return CourseStep(
                  time: s['time'] ?? '', emoji: s['emoji'] ?? '📍', type: s['type'] ?? '',
                  band: s['band'] ?? '', duration: s['duration'] ?? '', description: s['description'] ?? '',
                  searchQuery: s['searchQuery'] ?? '', categoryCode: s['categoryCode'] ?? '', engine: s['engine'] ?? 'kakao',
                  isSearching: s['isSearching'] ?? false, travelMinutesFromPrev: s['travelMinutesFromPrev'] as int?,
                  place: p == null ? null : PlaceResult(
                    name: p['name'] ?? '', address: p['address'] ?? '', roadAddress: p['roadAddress'] ?? '',
                    category: p['category'] ?? '', phone: p['phone'] ?? '', 
                    lat: p['lat'] != null ? (p['lat'] as num).toDouble() : null, 
                    lng: p['lng'] != null ? (p['lng'] as num).toDouble() : null,
                    source: p['source'] ?? '', placeUrl: p['placeUrl'] ?? '', openHours: p['openHours'] ?? ''
                  )
                );
              }).toList(),
            });
          }
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('데이터 불러오기 오류: $e');
    }
  }

  @override
  void dispose() {
    _postCountSub?.cancel();
    super.dispose();
  }
}
// ────────────────────────────────────────────────────────────
// 앱 진입
// ────────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // 💡 익명 로그인 대신 이메일/비밀번호 인증 사용.
  // 앱 시작 시 자동 로그인은 하지 않고, AuthGate가 Firebase의 로그인 세션 유지 여부를 확인해서
  // 로그인 화면 / 메인 화면 중 어디로 보낼지 결정함.

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
    title: 'Course It',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xFFE8556D), scaffoldBackgroundColor: const Color(0xFFFBF7F5)),
    home: const AuthGate(),
  );
}

// ────────────────────────────────────────────────────────────
// 앱 시작 시 Firebase 로그인 세션이 남아있는지 확인해서
// 로그인 화면 / 메인 화면 중 하나로 자동 이동시켜주는 게이트
// (이메일 인증이 안 된 계정은 로그인 화면으로 돌려보냄)
// ────────────────────────────────────────────────────────────
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  static Widget loadingScaffold() => const Scaffold(
    backgroundColor: kCream,
    body: Center(child: CircularProgressIndicator(color: kRose)),
  );

  Future<Widget> _resolve(BuildContext context, User user) async {
    // 최신 인증 상태를 다시 받아옴 (다른 기기/메일에서 방금 인증했을 수도 있으므로)
    await user.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
    if (refreshed == null || !refreshed.emailVerified) {
      await FirebaseAuth.instance.signOut();
      return const LoginScreen();
    }

    final nickname = await fetchNicknameByUid(refreshed.uid);
    if (nickname == null) {
      // 프로필 문서를 찾을 수 없는 이례적인 경우 → 안전하게 로그아웃
      await FirebaseAuth.instance.signOut();
      return const LoginScreen();
    }

    final userProvider = context.read<UserProvider>();
    if (userProvider.loggedInUsername != nickname) {
      userProvider.setLoggedInUser(nickname);
      context.read<RoomProvider>().startForUser();
    }
    return const MainShell();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return loadingScaffold();
        }
        final user = snapshot.data;
        if (user == null) return const LoginScreen();

        return FutureBuilder<Widget>(
          future: _resolve(context, user),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) return loadingScaffold();
            return snap.data ?? const LoginScreen();
          },
        );
      },
    );
  }
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
// 로그인 화면 (Firestore users 컬렉션 기반)
// ────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text.trim();
    if (email.isEmpty || pw.isEmpty) {
      setState(() => _error = '이메일과 비밀번호를 입력해주세요.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pw);
      await cred.user?.reload();
      final user = FirebaseAuth.instance.currentUser;

      if (user == null || !user.emailVerified) {
        await FirebaseAuth.instance.signOut();
        setState(() {
          _error = '이메일 인증 후 이용해주세요. 메일함에서 인증 링크를 클릭해주세요.';
          _loading = false;
        });
        return;
      }

      final nickname = await fetchNicknameByUid(user.uid);
      if (nickname == null) {
        setState(() { _error = '계정 정보를 찾을 수 없습니다. 다시 가입해주세요.'; _loading = false; });
        return;
      }

      if (!mounted) return;
      context.read<UserProvider>().setLoggedInUser(nickname);
      context.read<RoomProvider>().startForUser(); // 로그인 사용자의 방 구독 시작
      Navigator.pushAndRemoveUntil(context,
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false);
    } on FirebaseAuthException catch (e) {
      String msg = '로그인에 실패했습니다. 다시 시도해주세요.';
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          msg = '비밀번호가 일치하지 않습니다.';
          break;
        case 'invalid-email':
          msg = '올바른 이메일 형식이 아닙니다.';
          break;
        case 'user-disabled':
          msg = '사용이 제한된 계정입니다.';
          break;
        case 'too-many-requests':
          msg = '시도 횟수가 너무 많습니다. 잠시 후 다시 시도해주세요.';
          break;
      }
      setState(() { _error = msg; _loading = false; });
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
              Text('✿ Course It', style: GoogleFonts.playfairDisplay(fontSize: 36, color: kRoseDk, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('둘이서 만드는 완벽한 하루', style: GoogleFonts.dmSans(fontSize: 13, color: kMuted, letterSpacing: 0.5)),
              const SizedBox(height: 48),
              _InputField(hint: '이메일', obscure: false, controller: _emailCtrl, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _InputField(hint: '비밀번호', obscure: true, controller: _pwCtrl),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: GoogleFonts.dmSans(fontSize: 12, color: Colors.red)),
              ],
              const SizedBox(height: 20),
              _loading
                ? const CircularProgressIndicator(color: kRose)
                : _PrimaryButton(label: '로그인', onTap: _login),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PasswordResetScreen())),
                child: Text('비밀번호를 잊으셨나요?', style: GoogleFonts.dmSans(fontSize: 12, color: kMuted, fontWeight: FontWeight.w500))),
              const SizedBox(height: 14),
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

// ────────────────────────────────────────────────────────────
// 회원가입 화면
// ────────────────────────────────────────────────────────────
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nicknameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nicknameCtrl.dispose();
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pwConfirmCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String v) => RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$').hasMatch(v);

  Future<void> _signup() async {
    final nickname = _nicknameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final pw = _pwCtrl.text.trim();
    final pwConfirm = _pwConfirmCtrl.text.trim();

    if (nickname.isEmpty || email.isEmpty || pw.isEmpty || pwConfirm.isEmpty) {
      setState(() => _error = '모든 항목을 입력해주세요.');
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() => _error = '올바른 이메일 주소를 입력해주세요.');
      return;
    }
    if (pw.length < 6) {
      setState(() => _error = '비밀번호는 6자 이상이어야 합니다.');
      return;
    }
    if (pw != pwConfirm) {
      setState(() => _error = '비밀번호가 일치하지 않습니다.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      // 닉네임 중복 확인 (users 컬렉션의 문서 id로 닉네임을 사용)
      final existing = await FirebaseFirestore.instance.collection('users').doc(nickname).get();
      if (existing.exists) {
        setState(() { _error = '이미 사용 중인 닉네임입니다.'; _loading = false; });
        return;
      }

      // Firebase Authentication으로 실제 계정 생성 (닉네임은 여기에 저장하지 않음)
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: pw);
      await cred.user?.sendEmailVerification();

      // 닉네임 등 프로필 정보는 Firestore에 저장
      final friendCode = await generateUniqueFriendCode();
      await FirebaseFirestore.instance.collection('users').doc(nickname).set({
        'nickname': nickname,
        'email': email,
        'uid': cred.user?.uid,
        'friendCode': friendCode,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 아직 이메일 인증 전이므로 바로 로그인시키지 않고 로그아웃 처리
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      setState(() => _loading = false);

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('인증 메일을 보냈습니다', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: kText)),
          content: Text('메일함에서 인증 링크를 클릭한 후 로그인해주세요.',
            style: GoogleFonts.dmSans(fontSize: 13, color: kMuted)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('확인', style: GoogleFonts.dmSans(color: kRose, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.pop(context); // 로그인 화면으로 돌아가기
    } on FirebaseAuthException catch (e) {
      String msg = '회원가입에 실패했습니다. 다시 시도해주세요.';
      switch (e.code) {
        case 'email-already-in-use':
          msg = '이미 가입된 이메일입니다.';
          break;
        case 'invalid-email':
          msg = '올바른 이메일 형식이 아닙니다.';
          break;
        case 'weak-password':
          msg = '비밀번호가 너무 약합니다. 6자 이상 입력해주세요.';
          break;
      }
      setState(() { _error = msg; _loading = false; });
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
              Text('Course It과 함께하세요', style: GoogleFonts.dmSans(fontSize: 13, color: kMuted)),
              const SizedBox(height: 40),
              _InputField(hint: '닉네임', obscure: false, controller: _nicknameCtrl),
              const SizedBox(height: 12),
              _InputField(hint: '이메일', obscure: false, controller: _emailCtrl, keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              _InputField(hint: '비밀번호', obscure: true, controller: _pwCtrl),
              const SizedBox(height: 12),
              _InputField(hint: '비밀번호 확인', obscure: true, controller: _pwConfirmCtrl),
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


// ────────────────────────────────────────────────────────────
// 비밀번호 재설정 화면
// 이메일을 입력하면 Firebase가 재설정 메일을 발송해줌
// ────────────────────────────────────────────────────────────
class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key});
  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String v) => RegExp(r'^[\w\.\-]+@[\w\-]+\.[\w\.\-]+$').hasMatch(v);

  Future<void> _sendResetEmail() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = '이메일을 입력해주세요.');
      return;
    }
    if (!_isValidEmail(email)) {
      setState(() => _error = '올바른 이메일 주소를 입력해주세요.');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() { _loading = false; _sent = true; });
    } on FirebaseAuthException catch (e) {
      String msg = '메일 전송에 실패했습니다. 다시 시도해주세요.';
      switch (e.code) {
        case 'user-not-found':
          msg = '존재하지 않는 이메일입니다.';
          break;
        case 'invalid-email':
          msg = '올바른 이메일 형식이 아닙니다.';
          break;
        case 'too-many-requests':
          msg = '시도 횟수가 너무 많습니다. 잠시 후 다시 시도해주세요.';
          break;
      }
      setState(() { _error = msg; _loading = false; });
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
              Text('비밀번호 재설정', style: GoogleFonts.playfairDisplay(fontSize: 26, color: kRoseDk, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text('비밀번호를 재설정할 이메일을 입력해주세요.',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(fontSize: 13, color: kMuted)),
              const SizedBox(height: 32),
              if (_sent) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(14), border: Border.all(color: kRoseLt)),
                  child: Column(children: [
                    Text('재설정 메일을 보냈습니다', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: kText)),
                    const SizedBox(height: 6),
                    Text('메일함에서 안내에 따라 비밀번호를 재설정한 후 로그인해주세요.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(fontSize: 12, color: kMuted)),
                  ]),
                ),
                const SizedBox(height: 20),
                _PrimaryButton(label: '로그인 화면으로', onTap: () => Navigator.pop(context)),
              ] else ...[
                _InputField(hint: '이메일', obscure: false, controller: _emailCtrl, keyboardType: TextInputType.emailAddress),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(_error!, style: GoogleFonts.dmSans(fontSize: 12, color: Colors.red)),
                ],
                const SizedBox(height: 20),
                _loading
                  ? const CircularProgressIndicator(color: kRose)
                  : _PrimaryButton(label: '재설정 메일 보내기', onTap: _sendResetEmail),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final String hint; final bool obscure;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  const _InputField({required this.hint, required this.obscure, this.controller, this.keyboardType});
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    obscureText: obscure,
    keyboardType: keyboardType,
    style: GoogleFonts.dmSans(fontSize: 13, color: kText),
    decoration: InputDecoration(
      hintText: hint, hintStyle: GoogleFonts.dmSans(fontSize: 13, color: kMuted),
      filled: true, fillColor: kNude,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    ),
  );
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

  late final List<Widget> _pages = [
    HomeTab(onRequestCourse: _goToCourseWithRegion),
    const CoursePage(),
    const TimelineTab(),
    const ReviewTab(),
    const MypageTab(),
  ];

  void _goToCourseWithRegion(String region) {
    // 코스 페이지가 (재)생성될 때 initState에서 읽어 자동 생성
    _CoursePageState.pendingAutoRegion = region;
    setState(() => _currentIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        onTap: (i) {
          setState(() => _currentIndex = i);
          if (i == 3) {
            Future.delayed(const Duration(milliseconds: 300), () {
              globalContext.callMethod('relayoutReviewMap'.toJS);
            });
          }
        },
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
class HomeTab extends StatefulWidget {
  final void Function(String region) onRequestCourse;
  const HomeTab({super.key, required this.onRequestCourse});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  // 오늘의 추천 코스용 구 목록 (대표 동네 함께 표시)
  static const Map<String, String> _districts = {
    '강남구': '신사 · 압구정 · 청담', '용산구': '이태원 · 한남 · 해방촌',
    '마포구': '홍대 · 연남 · 망원', '성동구': '성수 · 서울숲',
    '종로구': '북촌 · 인사동 · 광화문', '중구': '명동 · 을지로 · 충무로',
    '서초구': '반포 · 방배', '송파구': '잠실 · 방이',
    '강서구': '마곡 · 발산', '영등포구': '여의도 · 당산',
    '광진구': '건대 · 뚝섬', '성북구': '성신여대 · 삼청동',
    '은평구': '연신내 · 불광', '동작구': '흑석 · 노량진',
    '강동구': '천호 · 둔촌', '강북구': '수유 · 미아사거리',
    '관악구': '서울대입구 · 샤로수길', '구로구': '신도림 · 구로디지털단지',
    '금천구': '가산디지털단지 · 독산', '노원구': '노원역 · 공릉',
    '도봉구': '창동 · 쌍문', '동대문구': '청량리 · 회기',
    '서대문구': '신촌 · 연희 · 홍제', '양천구': '목동 · 오목교',
    '중랑구': '상봉 · 면목',
  };

  late String _todayDistrict;
  late String _todayHotspot;
  bool _hasUnreadNotif = true;

  @override
  void initState() {
    super.initState();
    _pickTodayDistrict();
  }

  void _pickTodayDistrict() {
    // 날짜를 시드로 사용해 "오늘 하루"는 같은 구가 유지되도록
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final keys = _districts.keys.toList();
    final idx = seed % keys.length;
    _todayDistrict = keys[idx];
    _todayHotspot = _districts[_todayDistrict]!;
  }

  void _shuffleDistrict() {
    final keys = _districts.keys.toList();
    String next;
    do {
      next = keys[math.Random().nextInt(keys.length)];
    } while (next == _todayDistrict && keys.length > 1);
    setState(() {
      _todayDistrict = next;
      _todayHotspot = _districts[next]!;
    });
  }

  void _showNotifications() {
    setState(() => _hasUnreadNotif = false);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kNude, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Text('알림', style: GoogleFonts.playfairDisplay(fontSize: 20, color: kText, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Center(child: Padding(padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(children: [
              const Text('🔔', style: TextStyle(fontSize: 32)),
              const SizedBox(height: 12),
              Text('아직 새로운 알림이 없어요', style: GoogleFonts.dmSans(fontSize: 13, color: kMuted)),
            ]))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCream,
      body: SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('안녕하세요 💕', style: GoogleFonts.playfairDisplay(fontSize: 20, color: kText)),
            GestureDetector(
              onTap: _showNotifications,
              child: Stack(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(18)),
                  child: const Center(child: Text('🔔', style: TextStyle(fontSize: 16)))),
                if (_hasUnreadNotif)
                  Positioned(top: 0, right: 0, child: Container(width: 9, height: 9,
                    decoration: BoxDecoration(color: kRose, borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: Colors.white, width: 1.5)))),
              ]),
            ),
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
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('오늘의 추천 코스', style: GoogleFonts.playfairDisplay(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w600)),
                  GestureDetector(
                    onTap: _shuffleDistrict,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(20)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Text('🎲', style: TextStyle(fontSize: 12)),
                        const SizedBox(width: 4),
                        Text('다른 동네', style: GoogleFonts.dmSans(fontSize: 10, color: Colors.white)),
                      ]),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                Text('📍 $_todayDistrict · $_todayHotspot',
                  style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text('AI가 $_todayDistrict 데이트 코스를 짜드려요',
                  style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white.withOpacity(0.85))),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    // 선택된 구로 자동 코스 생성 요청
                    widget.onRequestCourse(_todayDistrict);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.25), borderRadius: BorderRadius.circular(20)),
                    child: Text('✨ 이 코스 만들기 →', style: GoogleFonts.dmSans(fontSize: 11, color: Colors.white)),
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 20),
            _SectionLabel('함께하는 친구'),
            const SizedBox(height: 10),
            SizedBox(height: 70, child: ListView(scrollDirection: Axis.horizontal, children: [
              // 💡 하드코딩된 이름을 지우고, DB와 연동된 실제 친구 목록을 그려줍니다!
              ...context.watch<UserProvider>().friends.map((f) => 
                _FriendAvatar(name: f['name'], initial: f['initial'])
              ),
              _FriendAvatarAdd(onTap: () {
                final user = context.read<UserProvider>();
                const MypageTab()._showFriendManage(context, user);
              }),
            ])),
            _SectionLabel('최근 저장한 코스'),
            const SizedBox(height: 10),
            Builder(builder: (context) {
              final savedCourses = context.watch<UserProvider>().savedCourses;
              if (savedCourses.isEmpty) {
                return Container(
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
                );
              }
              return Column(children: savedCourses.map((course) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => _showCourseDetail(context, course),
                  child: _CourseCard(
                    emoji: course['emoji'] as String,
                    color1: course['color1'] as Color,
                    color2: course['color2'] as Color,
                    title: course['title'] as String,
                    sub: course['sub'] as String,
                  ),
                ),
              )).toList());
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
  static const String _groqApiKey        = String.fromEnvironment('GROQ_API_KEY');
  static const String _groqModel         = 'llama-3.3-70b-versatile';
  static const String _tmapApiKey        = String.fromEnvironment('TMAP_API_KEY');

  static const Map<String, String> _districtHotspot = {
    '강남구': '신사동, 압구정동, 청담동, 삼성동', '용산구': '이태원동, 한남동, 해방촌',
    '마포구': '홍대입구, 연남동, 망원동', '성동구': '성수동, 서울숲',
    '종로구': '북촌, 인사동, 광화문', '중구': '명동, 을지로, 충무로',
    '서초구': '반포동, 방배동', '송파구': '잠실동, 방이동',
    '강서구': '마곡동, 발산동', '영등포구': '여의도, 당산동',
    '광진구': '건대입구, 뚝섬', '성북구': '성신여대입구, 삼청동',
    '은평구': '연신내, 불광동', '동작구': '흑석동, 노량진',
    '강동구': '천호동, 강동역, 둔촌동', '강북구': '수유역, 미아사거리',
    '관악구': '서울대입구, 샤로수길, 신림동', '구로구': '신도림, 구로디지털단지',
    '금천구': '가산디지털단지, 독산동', '노원구': '노원역, 공릉동',
    '도봉구': '창동, 쌍문동', '동대문구': '청량리, 회기동, 휘경동',
    '서대문구': '신촌, 연희동, 홍제동', '양천구': '목동, 오목교',
    '중랑구': '상봉동, 면목동',
  };

  // 💡 추가: 자주 쓰이는 동네 별칭 → 정확한 (구, 동) 직접 매핑
  //   카카오 키워드 검색만 믿으면 "성수"를 광진구로 잘못 잡는 등 오인식이 생길 수 있어서,
  //   잘 알려진 동네는 여기서 먼저 정확히 매칭시키고, 좌표만 API로 조회함.
  static const Map<String, Map<String, String>> _knownNeighborhoods = {
    '성수': {'gu': '성동구', 'dong': '성수동'}, '성수동': {'gu': '성동구', 'dong': '성수동'},
    '뚝섬': {'gu': '성동구', 'dong': '성수동'}, '왕십리': {'gu': '성동구', 'dong': '행당동'},
    '옥수': {'gu': '성동구', 'dong': '옥수동'}, '금호': {'gu': '성동구', 'dong': '금호동'},
    '서울숲': {'gu': '성동구', 'dong': '성수동'},
    '홍대': {'gu': '마포구', 'dong': '동교동'}, '홍대입구': {'gu': '마포구', 'dong': '동교동'},
    '연남': {'gu': '마포구', 'dong': '연남동'}, '연남동': {'gu': '마포구', 'dong': '연남동'},
    '합정': {'gu': '마포구', 'dong': '합정동'}, '상수': {'gu': '마포구', 'dong': '상수동'},
    '망원': {'gu': '마포구', 'dong': '망원동'}, '공덕': {'gu': '마포구', 'dong': '공덕동'},
    '상암': {'gu': '마포구', 'dong': '상암동'}, '서교': {'gu': '마포구', 'dong': '서교동'},
    '대흥': {'gu': '마포구', 'dong': '대흥동'},
    '연희': {'gu': '서대문구', 'dong': '연희동'}, '신촌': {'gu': '서대문구', 'dong': '신촌동'},
    '이대': {'gu': '서대문구', 'dong': '대현동'},
    '한남': {'gu': '용산구', 'dong': '한남동'}, '한남동': {'gu': '용산구', 'dong': '한남동'},
    '이태원': {'gu': '용산구', 'dong': '이태원동'}, '해방촌': {'gu': '용산구', 'dong': '용산동2가'},
    '청담': {'gu': '강남구', 'dong': '청담동'}, '압구정': {'gu': '강남구', 'dong': '압구정동'},
    '신사': {'gu': '강남구', 'dong': '신사동'}, '삼성': {'gu': '강남구', 'dong': '삼성동'},
    '역삼': {'gu': '강남구', 'dong': '역삼동'}, '논현': {'gu': '강남구', 'dong': '논현동'},
    '대치': {'gu': '강남구', 'dong': '대치동'},
    '잠실': {'gu': '송파구', 'dong': '잠실동'}, '방이': {'gu': '송파구', 'dong': '방이동'},
    '가락': {'gu': '송파구', 'dong': '가락동'}, '문정': {'gu': '송파구', 'dong': '문정동'},
    '여의도': {'gu': '영등포구', 'dong': '여의도동'}, '당산': {'gu': '영등포구', 'dong': '당산동'},
    '문래': {'gu': '영등포구', 'dong': '문래동'}, '대림': {'gu': '영등포구', 'dong': '대림동'},
    '건대': {'gu': '광진구', 'dong': '화양동'}, '건대입구': {'gu': '광진구', 'dong': '화양동'},
    '구의': {'gu': '광진구', 'dong': '구의동'}, '자양': {'gu': '광진구', 'dong': '자양동'},
    '명동': {'gu': '중구', 'dong': '명동'}, '을지로': {'gu': '중구', 'dong': '을지로동'},
    '종로': {'gu': '종로구', 'dong': '종로1가'}, '익선동': {'gu': '종로구', 'dong': '익선동'},
    '서촌': {'gu': '종로구', 'dong': '체부동'}, '북촌': {'gu': '종로구', 'dong': '가회동'},
    '삼청동': {'gu': '종로구', 'dong': '삼청동'}, '인사동': {'gu': '종로구', 'dong': '인사동'},
    '노량진': {'gu': '동작구', 'dong': '노량진동'}, '흑석': {'gu': '동작구', 'dong': '흑석동'},
    '사당': {'gu': '동작구', 'dong': '사당동'},
    '방배': {'gu': '서초구', 'dong': '방배동'}, '반포': {'gu': '서초구', 'dong': '반포동'},
    '서초': {'gu': '서초구', 'dong': '서초동'},
    '목동': {'gu': '양천구', 'dong': '목동'},
    '마곡': {'gu': '강서구', 'dong': '마곡동'}, '발산': {'gu': '강서구', 'dong': '발산동'},
    '화곡': {'gu': '강서구', 'dong': '화곡동'}, '가양': {'gu': '강서구', 'dong': '가양동'},
    '신림': {'gu': '관악구', 'dong': '신림동'}, '봉천': {'gu': '관악구', 'dong': '봉천동'},
    '연신내': {'gu': '은평구', 'dong': '불광동'}, '불광': {'gu': '은평구', 'dong': '불광동'},
    '수유': {'gu': '강북구', 'dong': '수유동'}, '미아': {'gu': '강북구', 'dong': '미아동'},
    '노원': {'gu': '노원구', 'dong': '상계동'}, '상계': {'gu': '노원구', 'dong': '상계동'},
    '중계': {'gu': '노원구', 'dong': '중계동'},
    '청량리': {'gu': '동대문구', 'dong': '청량리동'}, '회기': {'gu': '동대문구', 'dong': '회기동'},
    '답십리': {'gu': '동대문구', 'dong': '답십리동'},
    '면목': {'gu': '중랑구', 'dong': '면목동'}, '상봉': {'gu': '중랑구', 'dong': '상봉동'},
    '천호': {'gu': '강동구', 'dong': '천호동'}, '고덕': {'gu': '강동구', 'dong': '고덕동'},
    '암사': {'gu': '강동구', 'dong': '암사동'},
    '신도림': {'gu': '구로구', 'dong': '신도림동'}, '구로': {'gu': '구로구', 'dong': '구로동'},
    '독산': {'gu': '금천구', 'dong': '독산동'}, '가산': {'gu': '금천구', 'dong': '가산동'},
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

  // 탭 전환 시 상태 보존용 static 변수
  static List<ChatMessage>                    _savedChatMessages   = [];
  static List<CourseStep>                     _savedCourseSteps    = [];
  static String                               _savedThemeKey       = '';
  static int                                  _savedTabIndex       = 0;
  static List<List<Map<String, double>>>?     _savedRouteSegments;

  // 홈 배너에서 설정: 코스 페이지 진입 시 이 구로 자동 코스 생성
  static String? pendingAutoRegion;

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
    String? displayRegion, // 💡 추가: 사람이 읽을 지역명(동+구)을 프롬프트에 그대로 보여줌
  }) {
    final hotspot = _districtHotspot[region] ?? '';
    final hotspotHint = hotspot.isNotEmpty ? '\n[핵심 동네]: $hotspot' : '';
    final shownRegion = displayRegion ?? region; // 💡 추가
    return '''
You are a Korean date course planner for Seoul couples.
Reply ONLY with a valid JSON array. No markdown, no explanation.

$themeLine
Region: $shownRegion$hotspotHint$mandatoryNote$spotsContext$restaurantCtx$userPreferences

[필수 코스 구조 — 6개 슬롯 전부 반드시 포함, 생략 절대 금지]
슬롯 1. band="morning"    → 오전 활동 1개: 카페·관광지·공원·전시 중 택1 (시작 10:00)
슬롯 2. band="lunch"      → 점심 식사 (12:00 고정) category="FD6" engine="kakao"
슬롯 3. band="afternoon"  → 오후 활동 1개: 카페·디저트·쇼핑·체험 중 택1
슬롯 4. band="afternoon2" → 오후 활동 2개: 전시·산책·관광지·체험 중 택1 (슬롯3과 다른 유형)
슬롯 5. band="dinner"     → 저녁 식사 (18:00 고정) category="FD6" engine="kakao"
슬롯 6. band="night"      → 저녁 활동 1개: 야경·루프탑·한강·야간 카페 중 택1

[규칙]
- 위 6개 슬롯은 하나라도 빠지면 안 됨
- search 필드: "<동네명> <구체적 특성>" 형식 필수 (예: "이태원 감성 루프탑 바")
- 같은 장소명 중복 사용 금지
- duration: 활동은 "1시간 30분", 식사는 "1시간"

출력 형식 (이 형식 그대로):
[{"band":"morning","emoji":"☕","type":"카페","duration":"1시간 30분","description":"이태원 감성 카페","search":"이태원 감성 브런치 카페","category":"CE7","engine":"naver"},
{"band":"lunch","emoji":"🍽️","type":"레스토랑","duration":"1시간","description":"이태원 맛집","search":"이태원 점심 맛집","category":"FD6","engine":"kakao"},
{"band":"afternoon","emoji":"🛍️","type":"쇼핑","duration":"1시간 30분","description":"한남동 편집숍","search":"한남동 편집숍","category":"MT1","engine":"kakao"},
{"band":"afternoon2","emoji":"🏛️","type":"전시","duration":"1시간 30분","description":"갤러리 관람","search":"이태원 갤러리 전시","category":"CT1","engine":"naver"},
{"band":"dinner","emoji":"🍖","type":"저녁식사","duration":"1시간","description":"한남동 저녁 맛집","search":"한남동 저녁 맛집","category":"FD6","engine":"kakao"},
{"band":"night","emoji":"🌃","type":"야경","duration":"1시간 30분","description":"남산 야경","search":"남산 야경 명소","category":"AT4","engine":"naver"}]
''';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this, initialIndex: _savedTabIndex);
    chatMessages      = List.from(_savedChatMessages);
    _courseSteps      = List.from(_savedCourseSteps);
    _selectedThemeKey = _savedThemeKey;
    _loadLocalSpots();
    _loadRestaurants();
    // 홈 배너에서 "오늘의 추천 코스"로 진입한 경우 자동 생성
    if (pendingAutoRegion != null) {
      final region = pendingAutoRegion!;
      pendingAutoRegion = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _tabController.index = 2; // 코스 결과 탭
        _generateCourse(queryOverride: '$region에서 오늘의 데이트 코스 짜줘');
      });
    }
    if (_savedCourseSteps.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        for (int i = 0; i < 5; i++) {
          await Future.delayed(const Duration(milliseconds: 700));
          if (!mounted) return;
          _redrawAllMarkers();
          if (_savedRouteSegments != null) {
            globalContext.callMethod('drawRoute'.toJS, jsonEncode(_savedRouteSegments).toJS);
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _savedChatMessages = List.from(chatMessages);
    _savedCourseSteps  = List.from(_courseSteps);
    _savedThemeKey     = _selectedThemeKey;
    _savedTabIndex     = _tabController.index;
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
    final body = <String, dynamic>{'model': _groqModel, 'messages': messages};
    if (jsonMode) body['response_format'] = {'type': 'json_object'};
    final res = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $_groqApiKey'},
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

  // 💡 재작성: 트리거 단어를 지우고 남는 한글 덩어리를 지역명 후보로 사용 (더 안정적)
  String? _extractLocationPhrase(String query) {
    final q = query.trim();
    if (q.isEmpty) return null;

    // 1) "성수동", "마포구"처럼 접미사가 명시된 경우 최우선
    final explicit = RegExp(r'[가-힣]{2,6}(?:동|구|가)').firstMatch(q);
    if (explicit != null) return explicit.group(0);

    // 2) 코스/추천 관련 트리거 단어들을 전부 제거하고 남는 한글 덩어리를 지역명 후보로 사용
    const triggerWords = [
      '코스', '데이트', '여행', '당일치기', '나들이', '짜줘', '짜서', '만들어줘', '만들어',
      '추천해줘요', '추천해줘', '추천해요', '추천해', '추천', '중심으로', '위주로',
      '가고싶어요', '가고 싶어요', '가고싶어', '가고 싶어', '가자', '뭐있어', '뭐 있어',
      '알려줘', '보여줘',
    ];
    var stripped = q;
    for (final w in triggerWords) {
      stripped = stripped.replaceAll(w, ' ');
    }
    stripped = stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (stripped.isEmpty) return null;

    // 3) 남은 텍스트에서 첫 한글 덩어리(2자 이상)를 후보로
    final candidate = RegExp(r'[가-힣]{2,12}').firstMatch(stripped)?.group(0);
    if (candidate == null) return null;

    // 4) 끝에 조사 하나 붙어 있으면 제거 (예: "성수에서" → "성수")
    final trimmed = candidate.replaceFirst(
      RegExp(r'(에서|에는|으로|이서|에게|한테|까지|부터|이|가|은|는|을|를|와|과|에)$'), '');
    return trimmed.length >= 2 ? trimmed : candidate;
  }

  // 💡 카카오 API로 "서울 안에 있는 지역"인지 확인하고 좌표/구/동을 반환
  Future<Map<String, dynamic>?> _resolveSeoulLocation(String phrase) async {
    Map<String, dynamic>? parseAddrDoc(Map doc) {
      final addr = (doc['address'] ?? doc['road_address']) as Map?;
      if (addr == null) return null;
      final addrName = (addr['address_name'] ?? '').toString();
      if (!addrName.contains('서울')) return null;
      final gu = (addr['region_2depth_name'] ?? '').toString();
      final dong = (addr['region_3depth_name'] ?? '').toString();
      final y = doc['y']?.toString(), x = doc['x']?.toString();
      if (y == null || x == null) return null;
      return {
        'lat': double.tryParse(y), 'lng': double.tryParse(x),
        'region': gu.endsWith('구') ? gu : null,
        'dong': dong, 'addressName': addrName,
      };
    }

    // 0차: 잘 알려진 동네는 표에서 정확한 구/동으로 먼저 확정 (키워드 검색의 오인식 방지)
    final known = _knownNeighborhoods[phrase];
    if (known != null) {
      final gu = known['gu']!;
      final dong = known['dong']!;
      for (final q in ['서울 $gu $dong', '$gu $dong']) {
        try {
          final res = await http.get(
            Uri.parse('https://dapi.kakao.com/v2/local/search/address.json?query=${Uri.encodeQueryComponent(q)}'),
            headers: {'Authorization': 'KakaoAK $kakaoRestApiKey'},
          );
          if (res.statusCode == 200) {
            final docs = jsonDecode(res.body)['documents'] as List;
            if (docs.isNotEmpty) {
              final y = docs[0]['y']?.toString(), x = docs[0]['x']?.toString();
              if (y != null && x != null) {
                return {'lat': double.tryParse(y), 'lng': double.tryParse(x), 'region': gu, 'dong': dong, 'addressName': '서울 $gu $dong'};
              }
            }
          }
        } catch (_) {}
      }
      // 좌표 조회는 실패해도 구/동 정보 자체는 표에서 확정된 값이라 신뢰할 수 있음 → 좌표 없이 반환
      return {'lat': null, 'lng': null, 'region': gu, 'dong': dong, 'addressName': '서울 $gu $dong'};
    }

    // 1차: 주소 검색 (동/구 이름이 정확할 때 가장 신뢰도 높음)
    for (final q in ['서울 $phrase', phrase]) {
      try {
        final res = await http.get(
          Uri.parse('https://dapi.kakao.com/v2/local/search/address.json?query=${Uri.encodeQueryComponent(q)}'),
          headers: {'Authorization': 'KakaoAK $kakaoRestApiKey'},
        );
        if (res.statusCode == 200) {
          final docs = jsonDecode(res.body)['documents'] as List;
          for (final d in docs) {
            final r = parseAddrDoc(d as Map);
            if (r != null) return r;
          }
        }
      } catch (_) {}
    }

    // 2차: 키워드 검색 (성수, 한남처럼 접미사 없는 유명 지명 fallback)
    for (final q in ['서울 $phrase', phrase]) {
      try {
        final res = await http.get(
          Uri.parse('https://dapi.kakao.com/v2/local/search/keyword.json?query=${Uri.encodeQueryComponent(q)}&size=5'),
          headers: {'Authorization': 'KakaoAK $kakaoRestApiKey'},
        );
        if (res.statusCode == 200) {
          final docs = jsonDecode(res.body)['documents'] as List;
          for (final d in docs) {
            final addrName = (d['address_name'] ?? '').toString();
            if (!addrName.contains('서울')) continue;
            final parts = addrName.split(' ');
            String gu = parts.firstWhere((p) => p.endsWith('구'), orElse: () => '');
            String dong = parts.firstWhere((p) => p.endsWith('동') || p.endsWith('가'), orElse: () => '');
            final y = d['y']?.toString(), x = d['x']?.toString();
            if (y == null || x == null) continue;
            return {
              'lat': double.tryParse(y), 'lng': double.tryParse(x),
              'region': gu.isNotEmpty ? gu : null,
              'dong': dong.isNotEmpty ? dong : phrase, 'addressName': addrName,
            };
          }
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
      // 💡 수정: 구 하드코딩 리스트 대신 카카오 API로 서울 내 모든 동/구를 동적으로 인식
      final locationPhrase = _extractLocationPhrase(query) ?? query.trim();
      final resolvedLoc = await _resolveSeoulLocation(locationPhrase);

      if (resolvedLoc == null) {
        setState(() {
          _courseError = '서울 어느 동네에서 코스를 원하세요?\n예: "성수 추천", "한남동 코스 짜줘"';
          _isCourseLoading = false;
        });
        return;
      }

      final region = (resolvedLoc['region'] as String?) ?? '';
      final dong = ((resolvedLoc['dong'] as String?)?.isNotEmpty == true)
          ? resolvedLoc['dong'] as String
          : locationPhrase;
      double? cLat = resolvedLoc['lat'] as double?;
      double? cLng = resolvedLoc['lng'] as double?;
      // 💡 동 단위 좌표 조회에 실패했으면 구 단위로라도 좌표를 확보 (완전히 못 찾는 상황 방지)
      if ((cLat == null || cLng == null) && region.isNotEmpty) {
        final fallback = await _getCoordFromAddress('서울 $region');
        cLat ??= fallback?['lat'];
        cLng ??= fallback?['lng'];
      }
      final regionLabel = region.isNotEmpty ? '$dong ($region)' : dong;

      final mandatory = _extractMandatory(query);
      final rawD = region.isNotEmpty ? region.replaceAll('구', '') : '';
      String mandStripped = mandatory ?? '';
      if (mandatory != null) {
        for (final t in [region, rawD, dong].where((s) => s.isNotEmpty)) {
          mandStripped = mandStripped.replaceAll(t, '');
        }
        mandStripped = mandStripped.trim();
      }
      final mandLabel = mandStripped.isNotEmpty ? mandStripped : (mandatory ?? '');
      final isMandShop = _shoppingCode(mandLabel) == 'MT1';
      final mandNote = mandatory != null
          ? '\n\n[사용자 명시 장소 — 절대 규칙]\n"$mandLabel"을 반드시 1~2번째 step에 배치하세요.\ntype: "${isMandShop ? "쇼핑" : mandLabel}", search: "$mandLabel"' : '';

      final theme = _selectedThemeKey.isNotEmpty ? _themes.firstWhere((t) => t['key'] == _selectedThemeKey) : null;
      final themeCategories = theme != null ? _getCategoriesForTheme(_selectedThemeKey) : ['문화관광','자연관광','역사관광','체험관광','기타관광','쇼핑','레저스포츠'];
      // 💡 region이 비어있으면(동만 인식된 경우) 전체 스팟이 잘못 매칭되지 않도록 방어
      final topSpots = region.isNotEmpty
          ? _getSpotsForRegion(region).where((s) => themeCategories.contains(s['category'] as String)).take(2).toList()
          : <Map<String, dynamic>>[];

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
          if (r.isEmpty) r = await _searchKakao('$dong $mandLabel', cat, centerLat: cLat, centerLng: cLng, radius: 5000, size: 10);
          if (r.isNotEmpty) {
            r.sort((a, b) => _nameScore(a.name, mandLabel).compareTo(_nameScore(b.name, mandLabel)));
            mandResult = r[0];
            for (final key in [mandatory, '$dong $mandatory', mandStripped, '$dong $mandStripped', mandLabel]) {
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
            {'role': 'system', 'content': _buildCoursePrompt(region: region, displayRegion: regionLabel, themeLine: themeLine, mandatoryNote: mandNote, spotsContext: spotsCtx, restaurantCtx: restCtx, userPreferences: '')},
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

      String bandToTime(String band) => switch (band) { 'lunch' => '12:00', 'afternoon' => '14:00', 'afternoon2' => '15:30', 'dinner' => '18:00', 'night' => '20:00', _ => '10:00' };
      const bandOrder = {'morning':0,'lunch':1,'afternoon':2,'afternoon2':3,'dinner':4,'night':5};
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

      // 💡 region이 비어있을 수 있으므로(동만 인식된 경우) areaKeyword로 폴백
      final areaKeyword = region.isNotEmpty ? region : dong;
      final allCandidates = await Future.wait(_courseSteps.map((s) =>
        (s.place != null || s.searchQuery.isEmpty) ? Future.value(<PlaceResult>[]) : _searchStepCandidates(s, areaKeyword, cLat, cLng)));

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
      await _replaceFarSteps(areaKeyword);
      _redrawAllMarkers();
      await _drawRouteAndTimes();

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
    if (from.lat == null || from.lng == null || to.lat == null || to.lng == null) return null;

    // 1순위: T map 보행자 경로 (이동시간 계산과 동일 엔진 → 선·시간 일치)
    if (_tmapApiKey.isNotEmpty) {
      try {
        final res = await http.post(
          Uri.parse('https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1'),
          headers: {'Content-Type': 'application/json', 'appKey': _tmapApiKey},
          body: jsonEncode({
            'startX': from.lng.toString(), 'startY': from.lat.toString(),
            'endX':   to.lng.toString(),   'endY':   to.lat.toString(),
            'reqCoordType': 'WGS84GEO', 'resCoordType': 'WGS84GEO',
            'startName': '출발', 'endName': '도착',
          }),
        ).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final features = data['features'] as List?;
          if (features != null && features.isNotEmpty) {
            final path = <Map<String, double>>[];
            for (final f in features) {
              final geom = f['geometry'] as Map?;
              if (geom == null) continue;
              if (geom['type'] == 'LineString') {
                for (final c in (geom['coordinates'] as List)) {
                  path.add({'lat': (c[1] as num).toDouble(), 'lng': (c[0] as num).toDouble()});
                }
              } else if (geom['type'] == 'Point') {
                final c = geom['coordinates'] as List;
                path.add({'lat': (c[1] as num).toDouble(), 'lng': (c[0] as num).toDouble()});
              }
            }
            if (path.isNotEmpty) return path;
          }
        }
      } catch (_) {}
    }

    // 2순위: OSRM
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

  // T맵 1회 호출로 경로 좌표 + 소요시간(분)을 동시에 반환
  // 반환: (경로좌표, 소요분, 소스라벨)
  Future<(List<Map<String, double>>?, int?, String)> _fetchWalkingRouteAndTime(PlaceResult from, PlaceResult to) async {
    if (from.lat == null || from.lng == null || to.lat == null || to.lng == null) return (null, null, 'none');
    final straightKm = _haversineKm(from.lat!, from.lng!, to.lat!, to.lng!);
    debugPrint('[경로] ${from.name}(${from.lat},${from.lng}) → ${to.name}(${to.lat},${to.lng}) 직선 ${straightKm.toStringAsFixed(2)}km');

    if (_tmapApiKey.isNotEmpty) {
      try {
        final res = await http.post(
          Uri.parse('https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1'),
          headers: {'Content-Type': 'application/json', 'appKey': _tmapApiKey},
          body: jsonEncode({
            'startX': from.lng.toString(), 'startY': from.lat.toString(),
            'endX':   to.lng.toString(),   'endY':   to.lat.toString(),
            'reqCoordType': 'WGS84GEO', 'resCoordType': 'WGS84GEO',
            'startName': '출발', 'endName': '도착',
          }),
        ).timeout(const Duration(seconds: 8));
        debugPrint('[Tmap] status=${res.statusCode}');
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final features = data['features'] as List?;
          if (features != null && features.isNotEmpty) {
            int? totalSec;       // 전체 경로 시간 (첫 Point의 totalTime)
            int sumSegSec = 0;   // 구간 time 합계 (대조용)
            final path = <Map<String, double>>[];
            for (final f in features) {
              final props = f['properties'] as Map?;
              final tt = props?['totalTime'];
              if (tt is num) totalSec = math.max(totalSec ?? 0, tt.toInt());
              final segT = props?['time'];
              if (segT is num) sumSegSec += segT.toInt();
              final geom = f['geometry'] as Map?;
              if (geom == null) continue;
              if (geom['type'] == 'LineString') {
                for (final c in (geom['coordinates'] as List)) {
                  path.add({'lat': (c[1] as num).toDouble(), 'lng': (c[0] as num).toDouble()});
                }
              } else if (geom['type'] == 'Point') {
                final c = geom['coordinates'] as List;
                path.add({'lat': (c[1] as num).toDouble(), 'lng': (c[0] as num).toDouble()});
              }
            }
            // totalTime이 비정상(0/누락)이면 구간 합계 사용
            final sec = (totalSec != null && totalSec > 0) ? totalSec : sumSegSec;
            debugPrint('[Tmap] totalTime=${totalSec}s, sumSeg=${sumSegSec}s → 사용 ${sec}s (${(sec/60).ceil()}분), 좌표 ${path.length}개');
            if (sec > 0) {
              final minutes = math.max(1, (sec / 60).ceil());
              return (path.isNotEmpty ? path : null, minutes, 'tmap');
            }
          }
        }
      } catch (e) { debugPrint('[Tmap] 오류: $e'); }
    }

    // 폴백: OSRM — 경로 좌표와 시간을 같은 응답에서 함께 사용 (선·시간 일치)
    try {
      final res = await http.get(Uri.parse('https://router.project-osrm.org/route/v1/foot/${from.lng},${from.lat};${to.lng},${to.lat}?overview=full&geometries=geojson'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final route = data['routes']?[0];
        final coords = route?['geometry']?['coordinates'] as List?;
        final dur = route?['duration'];
        if (coords != null && coords.isNotEmpty && dur is num) {
          final path = coords.map<Map<String, double>>((c) => {'lat': (c[1] as num).toDouble(), 'lng': (c[0] as num).toDouble()}).toList();
          // OSRM foot는 5km/h 가정 — 한국 보행 현실에 맞춰 1.15배 보정
          final minutes = math.max(1, (dur / 60 * 1.15).ceil());
          debugPrint('[OSRM] ${dur}초 → ${minutes}분');
          return (path, minutes, 'osrm');
        }
      }
    } catch (e) { debugPrint('[OSRM] 오류: $e'); }

    // 최종 폴백: 직선거리 추정 (우회계수 1.4, 도보 4.5km/h)
    final distKm = _haversineKm(from.lat!, from.lng!, to.lat!, to.lng!);
    final est = math.max(1, (distKm * 1.4 / 4.5 * 60).ceil());
    debugPrint('[추정] 직선 ${distKm.toStringAsFixed(2)}km → ${est}분');
    return (null, est, 'estimate');
  }

  // 경로선과 이동시간을 한 번에 계산 (구간당 T맵 1회 호출)
  // 한 구간 도보 시간이 제한(분)을 넘으면, 이전 장소 근처에서 같은 종류의 장소로 자동 교체
  static const int _maxWalkMinutes = 25;
  Future<void> _replaceFarSteps(String region) async {
    for (int i = 1; i < _courseSteps.length; i++) {
      final prev = _courseSteps[i-1], curr = _courseSteps[i];
      if (prev.place?.lat == null || curr.place?.lat == null) continue;
      if (curr.searchQuery.isEmpty) continue; // 재검색 불가(필수 장소 등)는 건너뜀

      // 현재 구간 도보 시간 확인
      final cur = await _fetchWalkingRouteAndTime(prev.place!, curr.place!);
      final minutes = cur.$2;
      if ((minutes ?? 0) <= _maxWalkMinutes) continue;

      // 이전 장소 1.2km 반경에서 같은 카테고리·검색어로 거리순 재검색
      final used = _courseSteps.map((s) => s.place?.name ?? '').toSet();
      List<PlaceResult> candidates = [];
      try {
        final q = curr.searchQuery.contains(region) ? curr.searchQuery : '$region ${curr.searchQuery}';
        candidates = _filter(await _searchKakao(q, curr.categoryCode,
            centerLat: prev.place!.lat, centerLng: prev.place!.lng, radius: 1200, size: 10));
      } catch (_) {}
      if (candidates.isEmpty && curr.categoryCode.isNotEmpty) {
        final cn = categoryLabels[curr.categoryCode] ?? '';
        if (cn.isNotEmpty) {
          try {
            candidates = _filter(await _searchKakao('$region $cn', curr.categoryCode,
                centerLat: prev.place!.lat, centerLng: prev.place!.lng, radius: 1500, size: 10));
          } catch (_) {}
        }
      }

      // 아직 안 쓴 후보 중 도보 제한 이내인 첫 장소로 교체
      for (final cand in candidates) {
        if (cand.lat == null || used.contains(cand.name)) continue;
        final chk = await _fetchWalkingRouteAndTime(prev.place!, cand);
        final m2 = chk.$2;
        if ((m2 ?? 999) <= _maxWalkMinutes) {
          debugPrint('[재검색] ${curr.place!.name}(${minutes}분) → ${cand.name}(${m2}분)로 교체');
          setState(() => _courseSteps[i].place = cand);
          break;
        }
      }
    }
  }

  Future<void> _drawRouteAndTimes() async {
    final steps = _courseSteps.where((s) => s.place?.lat != null).toList();
    if (steps.isEmpty) return;

    int parseDur(String s) { int m=0; final h=RegExp(r'(\d+)시간').firstMatch(s); final n=RegExp(r'(\d+)분').firstMatch(s); if(h!=null)m+=int.parse(h.group(1)!)*60; if(n!=null)m+=int.parse(n.group(1)!); return m>0?m:60; }
    int toM(String t){ final p=t.split(':'); return p.length>=2 ? int.parse(p[0])*60+int.parse(p[1]) : 600; }
    String fmt(int m)=>'${(m~/60).toString().padLeft(2,'0')}:${(m%60).toString().padLeft(2,'0')}';

    final segments = <List<Map<String, double>>>[];
    final sources = <String>{};
    int maxTravel = 0;
    int cursor = toM(steps[0].time);
    for (int i = 0; i < steps.length; i++) {
      if (i > 0) {
        final from = steps[i-1].place!, to = steps[i].place!;
        final (path, minutes, source) = await _fetchWalkingRouteAndTime(from, to);
        sources.add(source);
        segments.add(path ?? [{'lat': from.lat!, 'lng': from.lng!}, {'lat': to.lat!, 'lng': to.lng!}]);
        final tr = minutes ?? 15;
        if (tr > maxTravel) maxTravel = tr;
        cursor += parseDur(steps[i-1].duration) + tr;
        // 저녁 식사는 무조건 17:00 이후가 되도록 보정 (이르면 17:00으로 미룸)
        final isDinner = steps[i].band == 'dinner' || steps[i].type.contains('저녁');
        if (isDinner && cursor < 17 * 60) cursor = 17 * 60;
        steps[i].travelMinutesFromPrev = tr;
        steps[i].time = fmt(cursor);
      }
    }
    setState(() {}); // 시간/이동분 갱신 반영
    _savedRouteSegments = segments;
    globalContext.callMethod('drawRoute'.toJS, jsonEncode(segments).toJS);

    // 진단: 어떤 경로 엔진이 쓰였는지 안내 (T맵이 아니면 부정확할 수 있음)
    if (mounted && sources.isNotEmpty && !sources.contains('tmap')) {
      final label = sources.contains('osrm') ? 'OSRM(보정 추정)' : '직선거리 추정';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('도보 시간이 $label 기준이에요. 정확한 시간은 TMAP_API_KEY 설정이 필요해요.', style: GoogleFonts.dmSans(fontSize: 12)),
        backgroundColor: kMuted, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4)));
    }
    // 재검색 후에도 제한 초과 구간이 남으면 안내
    else if (mounted && maxTravel > _maxWalkMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('일부 구간 도보가 $maxTravel분으로 멀어요. 근처에 대체할 장소가 마땅치 않았어요 🥲', style: GoogleFonts.dmSans(fontSize: 12)),
        backgroundColor: kMuted, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4)));
    }
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
    _savedRouteSegments = segments;
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

    // 1순위: T map 보행자 경로 API (한국 도보 특화)
    if (_tmapApiKey.isNotEmpty) {
      try {
        debugPrint('[Tmap] 호출: (${from.lat},${from.lng}) → (${to.lat},${to.lng}) key=${_tmapApiKey.substring(0,6)}...');
        final res = await http.post(
          Uri.parse('https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1'),
          headers: {'Content-Type': 'application/json', 'appKey': _tmapApiKey},
          body: jsonEncode({
            'startX': from.lng.toString(), 'startY': from.lat.toString(),
            'endX':   to.lng.toString(),   'endY':   to.lat.toString(),
            'reqCoordType': 'WGS84GEO', 'resCoordType': 'WGS84GEO',
            'startName': '출발', 'endName': '도착',
          }),
        ).timeout(const Duration(seconds: 8));
        debugPrint('[Tmap] 응답 status=${res.statusCode} body=${res.body.substring(0, math.min(200, res.body.length))}');
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final features = data['features'] as List?;
          if (features != null && features.isNotEmpty) {
            final props = features[0]['properties'] as Map?;
            final totalTime = props?['totalTime'] as int?;
            debugPrint('[Tmap] totalTime=${totalTime}초');
            if (totalTime != null) return math.max(1, (totalTime / 60).ceil());
          }
        }
      } catch (e) { debugPrint('[Tmap] 오류: $e'); }
    } else {
      debugPrint('[Tmap] 키 없음 — TMAP_API_KEY 미설정');
    }

    // 2순위: OSRM
    try {
      final res = await http.get(
        Uri.parse('https://router.project-osrm.org/route/v1/foot/${from.lng},${from.lat};${to.lng},${to.lat}?overview=false'),
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        if (data['code'] == 'Ok') {
          final sec = (data['routes'][0]['duration'] as num).toDouble();
          debugPrint('[OSRM] ${sec.toInt()}초');
          return math.max(1, (sec / 60).ceil());
        }
      }
    } catch (e) { debugPrint('[OSRM] 오류: $e'); }

    // 3순위: haversine 추정 (도보 4.5km/h, 우회계수 1.3)
    final distKm = _haversineKm(from.lat!, from.lng!, to.lat!, to.lng!);
    debugPrint('[추정] 직선 ${distKm.toStringAsFixed(2)}km');
    return math.max(1, (distKm * 1.3 / 4.5 * 60).ceil());
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
      setState(() { _courseSteps[i].travelMinutesFromPrev=tr; _courseSteps[i].time=fmt(cursor); });
    }
  }

  void _showPlaceDetail(BuildContext context, PlaceResult place) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) {
        final addr = place.roadAddress.isNotEmpty ? place.roadAddress : place.address;
        final cat  = place.category.isNotEmpty ? place.category.split(' > ').last : '';
        final commentController = TextEditingController();
        double rating = 5;
        bool isSaving = false;

        return StatefulBuilder(builder: (ctx2, setSheet) => SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -2))]),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                  onPressed: () { Navigator.pop(ctx2); _showPlaceOnMap(place); },
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

                // ── 후기 작성 섹션 ──
                const SizedBox(height: 20),
                const Divider(height: 1),
                const SizedBox(height: 16),
                Text('내 평점 남기기', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: kText)),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) => GestureDetector(
                    onTap: () => setSheet(() => rating = (i + 1).toDouble()),
                    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon((i + 1) <= rating ? Icons.star : Icons.star_border,
                        color: const Color(0xFFFFB800), size: 32))))),
                const SizedBox(height: 12),
                TextField(
                  controller: commentController,
                  maxLines: 3,
                  style: GoogleFonts.dmSans(fontSize: 13, color: kText),
                  decoration: InputDecoration(
                    hintText: '이 장소에 대한 후기를 남겨주세요',
                    hintStyle: GoogleFonts.dmSans(fontSize: 13, color: kMuted),
                    filled: true, fillColor: kNude,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.all(14))),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kRoseDk, foregroundColor: Colors.white, elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13)),
                  onPressed: isSaving ? null : () async {
                    final comment = commentController.text.trim();
                    if (comment.isEmpty) return;
                    setSheet(() => isSaving = true);
                    await FirebaseFirestore.instance.collection('place_comments').add({
                      'uid': CurrentUser.idOrAnon,
                      'username': CurrentUser.idOrAnon,
                      'placeName': place.name,
                      'address': addr,
                      'comment': comment,
                      'rating': rating,
                      'latitude': place.lat,
                      'longitude': place.lng,
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    if (ctx2.mounted) Navigator.pop(ctx2);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('후기가 등록됐어요! 💕', style: GoogleFonts.dmSans()),
                        backgroundColor: kRose, behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                    }
                  },
                  child: Text(isSaving ? '저장 중...' : '후기 저장',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)))),
              ])),
            ]),
          ),
        ));
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

    // 💡 "추천"을 코스 트리거 단어에 포함
    final isCourse = RegExp(r'코스|데이트|여행|당일치기|나들이|짜줘|만들어|추천|가고\s*싶|가자|뭐\s*있').hasMatch(text);
    final locationCandidate = _extractLocationPhrase(text);
    final hasReg = locationCandidate != null && locationCandidate.trim().length >= 2;
    final isMand   = RegExp(r'중심으로|위주로|포함해서|포함하여|포함시켜').hasMatch(text);
    final hasModify = RegExp(r'말고|대신|바꿔|빼|제외|변경|교체|싫어|다른\s*(?:걸|것|곳|데|장소)|없애|수정|고쳐|별로').hasMatch(text);
    final isNewCourse = (hasReg && isCourse) || RegExp(r'코스\s*짜줘|코스\s*만들어|새로\s*짜|처음부터\s*짜|다시\s*짜').hasMatch(text);

    if (_courseSteps.isNotEmpty && !isNewCourse && hasModify) {
      setState(() => isChatLoading = true);
      await _modifyCourseByRequest(text);
      return;
    }

    // 💡 핵심 수정: "추천/코스" 등 코스 의도가 있는 문장이면 여기서 무조건 처리를 끝냄.
    //    지역을 못 찾아도 검색/일반채팅 분기로 절대 내려가지 않고, 되묻는 메시지를 보여줌.
    if (isCourse || isMand) {
      if (hasReg) {
        setState(() => chatMessages.add(ChatMessage(text: '코스를 생성하고 있어요! 코스 탭을 확인해주세요 🗺️', isUser: false)));
        _scrollToBottom();
        _tabController.animateTo(2);
        await _generateCourse(queryOverride: text);
      } else {
        setState(() => chatMessages.add(ChatMessage(text: '서울 어느 동네에서 코스를 원하세요? 예: "성수동", "홍대", "한남동"', isUser: false)));
        _scrollToBottom();
      }
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
      _redrawAllMarkers(); await _drawRouteAndTimes();
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
        await _drawRouteAndTimes();
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
        await _drawRouteAndTimes();
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

  // 현재 만들어진 코스를 저장 (홈/마이페이지의 "저장한 코스"에 추가)
  void _saveCurrentCourse() {
    if (_courseSteps.isEmpty) return;
    final validSteps = _courseSteps.where((s) => s.place != null).toList();
    if (validSteps.isEmpty) return;

    final title = '${validSteps.first.place!.name} 중심 코스';

    int totalMinutes = 0;
    for (final s in validSteps) {
      final h = RegExp(r'(\d+)시간').firstMatch(s.duration);
      final m = RegExp(r'(\d+)분').firstMatch(s.duration);
      if (h != null) totalMinutes += int.parse(h.group(1)!) * 60;
      if (m != null) totalMinutes += int.parse(m.group(1)!);
      if (s.travelMinutesFromPrev != null) totalMinutes += s.travelMinutesFromPrev!;
    }
    final hours = totalMinutes > 0 ? (totalMinutes / 60).round() : 1;
    final sub = '${validSteps.length}곳 · 약 $hours시간';

    final palettes = [
      [const Color(0xFFF7C5CD), const Color(0xFFC5D5F7)],
      [const Color(0xFFC5F7D5), const Color(0xFFF7F0C5)],
      [const Color(0xFFE2C5F7), const Color(0xFFF7C5D4)],
      [const Color(0xFFC5E0F7), const Color(0xFFC5F7ED)],
    ];
    final colorPair = palettes[DateTime.now().millisecondsSinceEpoch % palettes.length];

    final newCourse = {
      'emoji': validSteps.first.emoji,
      'color1': colorPair[0],
      'color2': colorPair[1],
      'title': title,
      'sub': sub,
      'steps': validSteps,
    };

    context.read<UserProvider>().addCourse(newCourse);

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('코스가 저장되었어요! 홈 화면에서 확인해보세요 💕', style: GoogleFonts.dmSans()),
      backgroundColor: kRose, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
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
            Padding(padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                icon: const Icon(Icons.bookmark_border, color: kRose, size: 26),
                tooltip: '코스 저장',
                onPressed: _saveCurrentCourse,
              )),
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
            child: Text('💬 지역을 말하면 자동으로 코스를 짜드려요! (예: "성수 추천")\n🔍 장소 추천 요청 → 검색 탭에 결과 표시\n➕ "OO 추가해줘" → 현재 코스에 장소 추가',
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
                Text('"성수 추천"\n"용산에서 데이트 코스 짜줘"\n"한남동 힐링 코스 추천해줘"',
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
            decoration: InputDecoration(hintText: '예: 성수 추천, 아이파크몰 중심으로',
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

    // 현재 선택된 방의 게시물만 구독 (방이 바뀌면 자동 전환)
    final current = roomProvider.currentRoom;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      postProvider.watchRoom(current?.id ?? '');
      if (_scrollController.hasClients) _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    });

    // 방 목록 로딩 중
    if (!roomProvider.isLoaded) {
      return const Scaffold(backgroundColor: kCream, body: Center(child: CircularProgressIndicator(color: kRose)));
    }

    // 방이 하나도 없으면 — 방 만들기 / 참가하기 화면
    if (!roomProvider.hasRooms) {
      return Scaffold(
        backgroundColor: kCream,
        body: SafeArea(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('💌', style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text('우리의 피드', style: GoogleFonts.playfairDisplay(fontSize: 24, color: kText)),
            const SizedBox(height: 8),
            Text('친구와 함께할 방을 만들어보세요!\n방을 만들면 그 방에서만 게시물을 공유해요.',
              textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 13, color: kMuted, height: 1.6)),
            const SizedBox(height: 28),
            _PrimaryButton(label: '✨ 새 방 만들기', onTap: () => _showCreateRoom(context, roomProvider)),
            const SizedBox(height: 10),
            _OutlineButton(label: '🔗 초대코드로 참가하기', onTap: () => _showJoinRoom(context, roomProvider)),
          ]),
        )),
      );
    }

    return Scaffold(
      backgroundColor: kCream,
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('우리의 피드 💌', style: GoogleFonts.playfairDisplay(fontSize: 20, color: kText)),
            Row(children: [
              GestureDetector(onTap: () { if (current != null) _showInviteCode(context, current.inviteCode); },
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
            return GestureDetector(
              onTap: () => roomProvider.selectRoom(e.key),
              onLongPress: () => _showRoomManage(context, roomProvider, e.value),
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
    Uint8List? pickedBytes;
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _BottomSheet(children: [
          Text('게시물 작성', style: GoogleFonts.playfairDisplay(fontSize: 20, color: kText)),
          const SizedBox(height: 16),
          TextField(controller: controller, maxLines: 4,
            style: GoogleFonts.dmSans(fontSize: 14, color: kText, height: 1.6),
            decoration: InputDecoration(hintText: '오늘 어땠나요? 친구들과 공유해보세요 💕', hintStyle: GoogleFonts.dmSans(fontSize: 14, color: kMuted),
              filled: true, fillColor: kNude, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(16))),
          const SizedBox(height: 12),
          // 선택한 사진 미리보기
          if (pickedBytes != null) ...[
            ClipRRect(borderRadius: BorderRadius.circular(14),
              child: Stack(children: [
                Image.memory(pickedBytes!, width: double.infinity, fit: BoxFit.fitWidth),
                Positioned(top: 8, right: 8,
                  child: GestureDetector(onTap: () => setSheetState(() => pickedBytes = null),
                    child: Container(width: 28, height: 28,
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(14)),
                      child: const Center(child: Text('✕', style: TextStyle(color: Colors.white, fontSize: 14)))))),
              ])),
            const SizedBox(height: 12),
          ],
          // 사진 첨부 버튼
          GestureDetector(
            onTap: () async {
              final bytes = await _pickImage();
              if (bytes != null) setSheetState(() => pickedBytes = bytes);
            },
            child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: kNude, borderRadius: BorderRadius.circular(14)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('📷', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Text(pickedBytes == null ? '사진 첨부' : '사진 변경', style: GoogleFonts.dmSans(fontSize: 13, color: kRoseDk, fontWeight: FontWeight.w500)),
              ]))),
          const SizedBox(height: 16),
          _PrimaryButton(label: '게시하기', onTap: () {
            if (controller.text.isNotEmpty || pickedBytes != null) {
              provider.addPost(text: controller.text, imageBytes: pickedBytes);
              Navigator.pop(context);
            }
          }),
        ]))));
  }

  // 웹 파일 선택 → 이미지 바이트 반환 (Firestore 저장용으로 리사이즈/압축)
  Future<Uint8List?> _pickImage() {
    final completer = Completer<Uint8List?>();
    final input = web.HTMLInputElement()
      ..type = 'file'
      ..accept = 'image/*';
    input.onChange.listen((_) {
      final files = input.files;
      if (files == null || files.length == 0) { completer.complete(null); return; }
      final file = files.item(0)!;
      final url = web.URL.createObjectURL(file);
      final img = web.HTMLImageElement();
      img.onLoad.listen((_) {
        // 최대 변 800px로 축소
        const maxSide = 800;
        var w = img.naturalWidth, h = img.naturalHeight;
        if (w > maxSide || h > maxSide) {
          if (w >= h) { h = (h * maxSide / w).round(); w = maxSide; }
          else { w = (w * maxSide / h).round(); h = maxSide; }
        }
        final canvas = web.HTMLCanvasElement()..width = w..height = h;
        final ctxObj = canvas.getContext('2d');
        if (ctxObj == null) { web.URL.revokeObjectURL(url); completer.complete(null); return; }
        final ctx = ctxObj as web.CanvasRenderingContext2D;
        ctx.drawImage(img, 0, 0, w.toDouble(), h.toDouble());
        // JPEG로 인코딩 → dataURL → 바이트 (800px 축소로 용량 충분히 작음)
        final dataUrl = canvas.toDataURL('image/jpeg');
        web.URL.revokeObjectURL(url);
        final comma = dataUrl.indexOf(',');
        if (comma < 0) { completer.complete(null); return; }
        try {
          final bytes = base64Decode(dataUrl.substring(comma + 1));
          completer.complete(bytes);
        } catch (_) { completer.complete(null); }
      });
      img.onError.listen((_) { web.URL.revokeObjectURL(url); completer.complete(null); });
      img.src = url;
    });
    input.click();
    return completer.future;
  }

  void _showRoomManage(BuildContext context, RoomProvider provider, RoomModel room) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      builder: (_) => _BottomSheet(children: [
        Text(room.name, style: GoogleFonts.playfairDisplay(fontSize: 20, color: kText)),
        const SizedBox(height: 4),
        Text('멤버 ${room.members.length}명 · 코드 ${room.inviteCode}', style: GoogleFonts.dmSans(fontSize: 12, color: kMuted)),
        const SizedBox(height: 20),
        _OutlineButton(label: '🚪 방 나가기', onTap: () async {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context);
          await provider.leaveRoom(room.id);
          messenger.showSnackBar(SnackBar(content: Text('방에서 나왔어요', style: GoogleFonts.dmSans()), backgroundColor: kMuted, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
        }),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () { Navigator.pop(context); _confirmDeleteRoom(context, provider, room); },
          child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(color: const Color(0xFFFDECEC), borderRadius: BorderRadius.circular(28), border: Border.all(color: const Color(0xFFE57373), width: 1.5)),
            child: Text('🗑️ 방 삭제하기', textAlign: TextAlign.center, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFFD32F2F)))),
        ),
        const SizedBox(height: 6),
        Text('삭제하면 이 방의 게시물도 모두 사라져요', style: GoogleFonts.dmSans(fontSize: 11, color: kMuted)),
      ]));
  }

  void _confirmDeleteRoom(BuildContext context, RoomProvider provider, RoomModel room) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('방을 삭제할까요?', style: GoogleFonts.playfairDisplay(fontSize: 18, color: kText)),
      content: Text('"${room.name}" 방과 이 방의 모든 게시물이\n영구히 삭제돼요. 되돌릴 수 없어요.',
        style: GoogleFonts.dmSans(fontSize: 13, color: kMuted, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text('취소', style: GoogleFonts.dmSans(color: kMuted))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F), foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
          onPressed: () async {
            final messenger = ScaffoldMessenger.of(context);
            Navigator.pop(ctx);
            await provider.deleteRoom(room.id);
            messenger.showSnackBar(SnackBar(content: Text('방이 삭제됐어요', style: GoogleFonts.dmSans()), backgroundColor: kMuted, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
          },
          child: Text('삭제', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600))),
      ],
    ));
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
          _PrimaryButton(label: '만들기', onTap: () async {
            if (controller.text.isNotEmpty) {
              final messenger = ScaffoldMessenger.of(context);
              await provider.createRoom(controller.text);
              if (context.mounted) Navigator.pop(context);
              messenger.showSnackBar(SnackBar(content: Text('방이 만들어졌어! 💕', style: GoogleFonts.dmSans()), backgroundColor: kRose, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
            }
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
          _PrimaryButton(label: '참가하기', onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            final ok = await provider.joinRoom(controller.text);
            if (context.mounted) Navigator.pop(context);
            if (ok) { messenger.showSnackBar(SnackBar(content: Text('방에 참가했어! 💕', style: GoogleFonts.dmSans()), backgroundColor: kRose, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))); }
            else { messenger.showSnackBar(SnackBar(content: Text('코드를 찾을 수 없어 😢', style: GoogleFonts.dmSans()), backgroundColor: kMuted, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))); }
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
            if (post.hasImage) ...[const SizedBox(height: 8),
              post.imageBytes != null
                ? ClipRRect(borderRadius: BorderRadius.circular(10),
                    child: Image.memory(post.imageBytes!, width: double.infinity, fit: BoxFit.fitWidth))
                : Container(width: double.infinity, height: 80,
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [kRoseLt, Color(0xFFE8AAB5)]), borderRadius: BorderRadius.circular(10)),
                    child: Center(child: Text(post.imageEmoji, style: const TextStyle(fontSize: 28))))],
          ])),
        const SizedBox(height: 4),
        GestureDetector(onTap: () => context.read<PostProvider>().toggleLike(post.id),
          child: Text('${post.time} · ${post.likedBy.contains(CurrentUser.idOrAnon) ? '♥' : '♡'} ${post.likes}',
            style: GoogleFonts.dmSans(fontSize: 10, color: post.likedBy.contains(CurrentUser.idOrAnon) ? kRose : kMuted, fontWeight: post.likedBy.contains(CurrentUser.idOrAnon) ? FontWeight.w700 : FontWeight.normal))),
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
              if (user.email.isNotEmpty)
                Text(user.email, style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white.withOpacity(0.8))),
              const SizedBox(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _StatItem(label: '저장한 코스', value: '${user.savedCourses.length}'),
                _StatItem(label: '친구', value: '${user.friends.length}'),
                _StatItem(label: '게시물', value: '${user.postCount}'),
              ]),
            ])),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _SectionLabel('저장한 코스'),
            GestureDetector(onTap: () {}, child: Text('전체보기', style: GoogleFonts.dmSans(fontSize: 11, color: kRose))),
          ]),
          const SizedBox(height: 10),
          ...user.savedCourses.asMap().entries.map((e) => GestureDetector(
            onTap: () => _showCourseDetail(context, e.value),
            child: _SavedCourseCard(course: e.value, onDelete: () => user.deleteCourse(e.key)))),
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
          _MenuItem(icon: '🚪', label: '로그아웃', onTap: () async {
            context.read<UserProvider>().logout();
            await FirebaseAuth.instance.signOut();
            if (!context.mounted) return;
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (r) => false);
          }, isRed: true),
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
          _PrimaryButton(label: '추가하기', onTap: () async {
            final result = await user.addFriendByCode(controller.text);
            Navigator.pop(context);
            String msg; Color bg;
            if (result == null) { msg = '코드를 찾을 수 없어 😢'; bg = kMuted; }
            else if (result == 'already') { msg = '이미 친구야! 💕'; bg = kMuted; }
            else if (result == 'self') { msg = '내 코드는 추가할 수 없어 😅'; bg = kMuted; }
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
  const _SavedCourseCard({required this.course, required this.onDelete});
  @override
  Widget build(BuildContext context) => Container(
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
      GestureDetector(onTap: onDelete, child: const Text('🗑️', style: TextStyle(fontSize: 16))),
    ]),
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
  List<Map<String, dynamic>> _reviewedPlaces = [];
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadCommentMarkers();
      // 카카오 SDK 로드 대기 후 마커 재시도 (최대 4회)
      for (int i = 0; i < 4; i++) {
        await Future.delayed(const Duration(milliseconds: 700));
        if (!mounted) return;
        _redrawCommentMarkers();
      }
    });
  }

  @override
  void dispose() {
    _regionController.dispose();
    _keywordController.dispose();
    super.dispose();
  }

  void _redrawCommentMarkers() {
    if (_reviewedPlaces.isEmpty) return;
    globalContext.callMethod('clearCommentMarkers'.toJS);
    for (final p in _reviewedPlaces) {
      final lat = p['lat'] as double?;
      final lng = p['lng'] as double?;
      if (lat == null || lng == null) continue;
      final avgRating = (p['avgRating'] as double).toStringAsFixed(1);
      final reviewCount = p['reviewCount'] as int;
      final placeName = p['placeName'] as String;
      final reviews = p['reviews'] as List<Map<String, dynamic>>;
      final commentsText = reviews.map((r) {
        final username = r['username'] ?? '익명';
        final rating = r['rating'] ?? 5;
        final comment = r['comment'] ?? '';
        return '⭐ $rating | $username: $comment';
      }).join('<br/><br/>');
      globalContext.callMethod(
        'addCommentMarker'.toJS,
        lat.toJS, lng.toJS,
        '<b>$placeName</b><br/>⭐ $avgRating · 후기 ${reviewCount}개'.toJS,
        commentsText.toJS,
      );
    }
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

      final List<Map<String, dynamic>> reviewedList = [];
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
        reviewedList.add({
          'placeName': placeName,
          'address': (first['address'] ?? '').toString(),
          'lat': first['latitude'],
          'lng': first['longitude'],
          'avgRating': avgRating,
          'reviewCount': reviews.length,
          'reviews': reviews,
        });
      });

      if (mounted) setState(() => _reviewedPlaces = reviewedList);
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
                await FirebaseFirestore.instance.collection('place_comments').add({
                  'uid': CurrentUser.idOrAnon,
                  'username': CurrentUser.idOrAnon,
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
    final uid = CurrentUser.idOrAnon;

    final snapshot = await FirebaseFirestore.instance
        .collection('place_comments').where('uid', isEqualTo: uid).get();

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

  Future<void> _showReviewedPlaceDialog(BuildContext context, Map<String, dynamic> p) async {
    final reviews = p['reviews'] as List<Map<String, dynamic>>;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p['placeName'] ?? '', style: GoogleFonts.playfairDisplay(fontSize: 16, color: kText)),
          const SizedBox(height: 2),
          Text(p['address'] ?? '', style: GoogleFonts.dmSans(fontSize: 11, color: kMuted)),
          const SizedBox(height: 4),
          Text('⭐ ${(p['avgRating'] as double).toStringAsFixed(1)}  ·  후기 ${p['reviewCount']}개',
            style: GoogleFonts.dmSans(fontSize: 12, color: kRoseDk, fontWeight: FontWeight.w500)),
        ]),
        content: SizedBox(
          width: 360, height: 300,
          child: ListView(children: reviews.map((r) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(r['username'] ?? '익명', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: kText)),
                const SizedBox(width: 8),
                Text('⭐ ${r['rating'] ?? 5}', style: GoogleFonts.dmSans(fontSize: 12, color: kRoseDk)),
              ]),
              const SizedBox(height: 4),
              Text(r['comment'] ?? '', style: GoogleFonts.dmSans(fontSize: 12, color: kMuted)),
            ]),
          )).toList()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: Text('닫기', style: GoogleFonts.dmSans(color: kMuted))),
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
                        ? _reviewedPlaces.isEmpty
                            ? Center(child: Text('아직 작성된 후기가 없어요 🌸\n장소를 검색하고 첫 후기를 남겨보세요!',
                                textAlign: TextAlign.center, style: GoogleFonts.dmSans(color: kMuted, height: 1.8)))
                            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Padding(padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                                  child: Text('후기가 있는 장소 ${_reviewedPlaces.length}곳',
                                    style: GoogleFonts.dmSans(fontSize: 11, color: kMuted, fontWeight: FontWeight.w500))),
                                Expanded(child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: _reviewedPlaces.length,
                                  itemBuilder: (ctx, i) {
                                    final p = _reviewedPlaces[i];
                                    return GestureDetector(
                                      onTap: () {
                                        final lat = p['lat'] as double?;
                                        final lng = p['lng'] as double?;
                                        if (lat != null && lng != null) {
                                          globalContext.callMethod('moveReviewMapTo'.toJS, lat.toJS, lng.toJS);
                                        }
                                        _showReviewedPlaceDialog(context, p);
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: kNude)),
                                        child: Row(children: [
                                          Container(width: 36, height: 36,
                                            decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(10)),
                                            child: const Center(child: Text('⭐', style: TextStyle(fontSize: 18)))),
                                          const SizedBox(width: 10),
                                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                            Text(p['placeName'] ?? '',
                                              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: kText)),
                                            const SizedBox(height: 2),
                                            Text(p['address'] ?? '',
                                              style: GoogleFonts.dmSans(fontSize: 11, color: kMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                                            Text('⭐ ${(p['avgRating'] as double).toStringAsFixed(1)}  ·  후기 ${p['reviewCount']}개',
                                              style: GoogleFonts.dmSans(fontSize: 11, color: kRoseDk, fontWeight: FontWeight.w500)),
                                          ])),
                                          const Icon(Icons.chevron_right, color: kRoseLt, size: 18),
                                        ]),
                                      ),
                                    );
                                  },
                                )),
                              ])
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

// ────────────────────────────────────────────────────────────
// 저장된 코스 상세 보기 (홈/마이페이지에서 코스 카드 클릭 시)
// ────────────────────────────────────────────────────────────
void _showCourseDetail(BuildContext context, Map<String, dynamic> course) {
  final steps = course['steps'] as List<CourseStep>? ?? [];
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(28),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: kNude, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 24),
        Row(children: [
          Container(width: 56, height: 56,
            decoration: BoxDecoration(gradient: LinearGradient(colors: [course['color1'], course['color2']]), borderRadius: BorderRadius.circular(16)),
            child: Center(child: Text(course['emoji'], style: const TextStyle(fontSize: 28)))),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(course['title'], style: GoogleFonts.playfairDisplay(fontSize: 20, color: kText, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(course['sub'], style: GoogleFonts.dmSans(fontSize: 13, color: kMuted)),
          ])),
        ]),
        const SizedBox(height: 24),
        Expanded(child: steps.isEmpty
            ? Center(child: Text('상세 코스 정보가 없습니다.\n(새로 저장한 코스부터 타임라인이 표시됩니다!)',
                textAlign: TextAlign.center, style: GoogleFonts.dmSans(color: kMuted, height: 1.5)))
            : ListView.builder(itemCount: steps.length, itemBuilder: (ctx, i) {
                final step = steps[i];
                final isLast = i == steps.length - 1;
                final placeName = step.place?.name ?? step.description;
                return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SizedBox(width: 40, child: Column(children: [
                    Container(width: 32, height: 32, decoration: const BoxDecoration(color: kRose, shape: BoxShape.circle),
                      child: Center(child: Text(step.emoji, style: const TextStyle(fontSize: 16)))),
                    if (!isLast) Expanded(child: Container(width: 2, color: kRoseLt, margin: const EdgeInsets.symmetric(vertical: 4))),
                  ])),
                  Expanded(child: Padding(padding: EdgeInsets.only(bottom: isLast ? 0 : 20, left: 12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(step.time, style: GoogleFonts.dmSans(fontSize: 13, color: kMuted, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Text(step.type, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold, color: kText)),
                      ]),
                      const SizedBox(height: 6),
                      Container(padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: kBlush, borderRadius: BorderRadius.circular(14), border: Border.all(color: kRoseLt)),
                        child: Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(placeName, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.bold, color: kText)),
                            if (step.place != null) ...[
                              const SizedBox(height: 2),
                              Text(step.place!.roadAddress.isNotEmpty ? step.place!.roadAddress : step.place!.address,
                                style: GoogleFonts.dmSans(fontSize: 11, color: kMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ])),
                        ])),
                    ]))),
                ]));
              })),
      ]),
    ),
  );
}
