import 'package:cloud_firestore/cloud_firestore.dart';

class OfferModel {
  final String id;
  final String animalId;
  final String animalName;
  final String userId;
  final String userName;
  final double offerPrice;
  final DateTime? timestamp;
  final String status;

  OfferModel({
    required this.id,
    required this.animalId,
    required this.animalName,
    required this.userId,
    required this.userName,
    required this.offerPrice,
    this.timestamp,
    required this.status,
  });

  static Future<OfferModel> fromFirestore(
      Map<String, dynamic> data, String id) async {
    // Fetch the user's name from the users collection
    String userName = 'Unknown';
    if (data['userId'] != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(data['userId'])
          .get();
      if (userDoc.exists) {
        userName = userDoc['name'] as String? ?? 'Unknown';
      }
    }

    return OfferModel(
      id: id,
      animalId: data['animalId'] ?? '',
      animalName: data['animalName'] ?? '',
      userId: data['userId'] ?? '',
      userName: userName,
      offerPrice: (data['offerPrice'] as num).toDouble(),
      timestamp: data['timestamp'] != null ? (data['timestamp'] as Timestamp).toDate() : null,
      status: data['status'] ?? 'pending',
    );
  }
}