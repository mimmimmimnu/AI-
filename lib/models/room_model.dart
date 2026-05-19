class RoomModel {
  final String id;
  final String name;
  final String inviteCode;
  final List<String> members;

  RoomModel({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.members,
  });
}