import 'package:flutter/material.dart';
import '../models/post_model.dart';

class PostProvider extends ChangeNotifier {
  final List<PostModel> _posts = [
    
  ];

  List<PostModel> get posts => _posts;

  // 게시물 추가
  void addPost({
    required String text,
    String? place,
    bool hasImage = false,
    String imageEmoji = '',
  }) {
    final now = TimeOfDay.now();
    final hour = now.hour > 12 ? now.hour - 12 : now.hour;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    final time = '$hour:$minute $period';

    _posts.add(
      
      PostModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        initial: '나',
        name: '이윤서',
        text: place != null ? '$text\n📍 $place' : text,
        hasImage: hasImage,
        imageEmoji: hasImage ? '🌸' : '',
        time: time,
        likes: 0,
      ),
    );
    notifyListeners();
  }

  // 좋아요
  void toggleLike(String id) {
    final post = _posts.firstWhere((p) => p.id == id);
    post.likes++;
    notifyListeners();
  }
}