import 'package:flutter/material.dart';

class UserProvider extends ChangeNotifier {
  String _name = '이윤서';
  String _email = 'yunseo@email.com';
  String _avatarEmoji = '👤';

  // 알림 설정
  bool _pushNotification = true;
  bool _friendActivity = true;
  bool _courseRecommend = false;

  // 내 코드
  final String myCode = 'USER07';

  // 친구 코드 DB
  final Map<String, Map<String, String>> _friendCodeDB = {
    'USER01': {'initial': '지', 'name': '지민'},
    'USER02': {'initial': '수', 'name': '수아'},
    'USER03': {'initial': '현', 'name': '현우'},
    'USER04': {'initial': '태', 'name': '태연'},
    'USER05': {'initial': '하', 'name': '하늘'},
    'USER06': {'initial': '민', 'name': '민준'},
  };

  // 저장한 코스
  final List<Map<String, dynamic>> _savedCourses = [
    {
      'emoji': '🌸',
      'color1': const Color(0xFFF7C5CD),
      'color2': const Color(0xFFC5D5F7),
      'title': '봄날 홍대 산책 코스',
      'sub': '3곳 · 4시간',
    },
    {
      'emoji': '🍃',
      'color1': const Color(0xFFC5F7D5),
      'color2': const Color(0xFFF7F0C5),
      'title': '연남동 브런치 데이트',
      'sub': '3곳 · 3시간',
    },
  ];

  // 친구 목록
  final List<Map<String, dynamic>> _friends = [
    {'initial': '지', 'name': '지민'},
    {'initial': '수', 'name': '수아'},
    {'initial': '현', 'name': '현우'},
    {'initial': '태', 'name': '태연'},
  ];

  String get name => _name;
  String get email => _email;
  String get avatarEmoji => _avatarEmoji;
  bool get pushNotification => _pushNotification;
  bool get friendActivity => _friendActivity;
  bool get courseRecommend => _courseRecommend;
  String get myFriendCode => myCode;
  List<Map<String, dynamic>> get savedCourses => _savedCourses;
  List<Map<String, dynamic>> get friends => _friends;

  void updateName(String name) {
    _name = name;
    notifyListeners();
  }

  void updateEmail(String email) {
    _email = email;
    notifyListeners();
  }

  void updateAvatar(String emoji) {
    _avatarEmoji = emoji;
    notifyListeners();
  }

  void togglePushNotification(bool val) {
    _pushNotification = val;
    notifyListeners();
  }

  void toggleFriendActivity(bool val) {
    _friendActivity = val;
    notifyListeners();
  }

  void toggleCourseRecommend(bool val) {
    _courseRecommend = val;
    notifyListeners();
  }

  void deleteCourse(int index) {
    _savedCourses.removeAt(index);
    notifyListeners();
  }

  void removeFriend(int index) {
    _friends.removeAt(index);
    notifyListeners();
  }

  // 코드로 친구 추가
  String? addFriendByCode(String code) {
    final upperCode = code.toUpperCase();
    if (!_friendCodeDB.containsKey(upperCode)) {
      return null; // 코드 없음
    }
    final friend = _friendCodeDB[upperCode]!;
    final alreadyExists = _friends.any((f) => f['name'] == friend['name']);
    if (alreadyExists) {
      return 'already'; // 이미 친구
    }
    _friends.add(friend);
    notifyListeners();
    return friend['name']; // 성공
  }
}