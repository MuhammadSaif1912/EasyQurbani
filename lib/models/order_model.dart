// lib/models/order_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_item.dart';
import 'animal_model.dart';

class OrderModel {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final List<CartItem> items;
  final double totalPrice;
  final DateTime? timestamp;

  OrderModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.items,
    required this.totalPrice,
    this.timestamp,
  });

  // Convert OrderModel to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userName': userName,
      'userEmail': userEmail,
      'items': items.map((item) => {
        'animal': {
          'id': item.animal.id,
          'name': item.animal.name,
          'category': item.animal.category,
          'price': item.animal.price,
          'imageUrl': item.animal.imageUrl,
        },
        'isButchered': item.isButchered,
        'deliveryDay': item.deliveryDay,
      }).toList(),
      'totalPrice': totalPrice,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : FieldValue.serverTimestamp(),
    };
  }

  // Create OrderModel from Firestore document
  static Future<OrderModel> fromFirestore(Map<String, dynamic> data, String id) async {
    final itemsData = (data['items'] as List<dynamic>?) ?? [];
    final List<CartItem> items = itemsData.map((itemData) {
      final animalData = itemData['animal'] as Map<String, dynamic>;
      return CartItem(
        animal: AnimalModel(
          id: animalData['id'],
          name: animalData['name'],
          category: animalData['category'],
          price: animalData['price'].toDouble(),
          imageUrl: animalData['imageUrl'],
        ),
        isButchered: itemData['isButchered'] ?? false,
        deliveryDay: itemData['deliveryDay'] ?? 'Day 1',
      );
    }).toList();

    return OrderModel(
      id: id,
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? '',
      userEmail: data['userEmail'] ?? '',
      items: items,
      totalPrice: (data['totalPrice'] as num?)?.toDouble() ?? 0.0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }
}