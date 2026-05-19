import 'package:flutter/material.dart';
import '../models/room_model.dart';
import 'dart:math';

class RoomProvider extends ChangeNotifier {
  final List<RoomModel> _rooms = [
    RoomModel(
      id: '1',
      name: '지민♥수아',
      inviteCode: 'LOVE01',
      members: ['이윤서', '지민', '수아'],
    ),
    RoomModel(
      id: '2',
      name: '현우그룹',
      inviteCode: 'CREW02',
      members: ['이윤서', '현우', '태연'],
    ),
  ];

  int _selectedRoomIndex = 0;

  List<RoomModel> get rooms => _rooms;
  RoomModel get currentRoom => _rooms[_selectedRoomIndex];
  int get selectedIndex => _selectedRoomIndex;

  // 방 선택
  void selectRoom(int index) {
    _selectedRoomIndex = index;
    notifyListeners();
  }

  // 초대코드로 방 찾기
  RoomModel? findRoomByCode(String code) {
    try {
      return _rooms.firstWhere(
        (room) => room.inviteCode == code.toUpperCase(),
      );
    } catch (e) {
      return null;
    }
  }

  // 방 참가
  void joinRoom(String code) {
    final room = findRoomByCode(code);
    if (room != null && !room.members.contains('이윤서')) {
      final index = _rooms.indexOf(room);
      _rooms[index] = RoomModel(
        id: room.id,
        name: room.name,
        inviteCode: room.inviteCode,
        members: [...room.members, '이윤서'],
      );
      notifyListeners();
    }
  }

  // 새 방 만들기
  void createRoom(String name) {
    final code = _generateCode();
    _rooms.add(RoomModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      inviteCode: code,
      members: ['이윤서'],
    ));
    _selectedRoomIndex = _rooms.length - 1;
    notifyListeners();
  }

  // 랜덤 초대코드 생성
  String _generateCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}