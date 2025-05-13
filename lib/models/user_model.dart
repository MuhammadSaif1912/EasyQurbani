class UserModel {
  final String uid;
  final String name;
  final String address;
  final String email;
  final String contact;
  final String? profilePicUrl;

  UserModel({
    required this.uid,
    required this.name,
    required this.address,
    required this.email,
    required this.contact,
    this.profilePicUrl,
  });
}