class PostModel {
  final String id;
  final String initial;
  final String name;
  final String text;
  final bool hasImage;
  final String imageEmoji;
  final String time;
  int likes;

  PostModel({
    required this.id,
    required this.initial,
    required this.name,
    required this.text,
    this.hasImage = false,
    this.imageEmoji = '',
    required this.time,
    this.likes = 0,
  });
}