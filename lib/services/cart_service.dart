import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cart_item.dart';
import '../models/animal_model.dart';
import 'auth_service.dart';

class CartService with ChangeNotifier {
  AuthService? _authService;

  CartService(this._authService);

  List<CartItem> _cartItems = [];

  List<CartItem> get cartItems => _cartItems;

  double get totalPrice => _cartItems.fold(0, (sum, item) => sum + item.totalPrice);

  void setAuthService(AuthService authService) {
    _authService = authService;
  }

  Future<void> loadCart() async {
    final userId = _authService?.getCurrentUserId();
    if (userId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cart')
        .get();

    _cartItems = snapshot.docs.map((doc) {
      final data = doc.data();
      return CartItem(
        animal: AnimalModel(
          id: doc.id,
          name: data['name'],
          category: data['category'],
          price: data['price'].toDouble(),
          imageUrl: data['imageUrl'],
        ),
        isButchered: data['isButchered'] ?? false,
        deliveryDay: data['deliveryDay'] ?? 'Day 1',
      );
    }).toList();
    notifyListeners();
  }

  Future<void> addToCart(AnimalModel animal, bool isButchered, String deliveryDay) async {
    final userId = _authService?.getCurrentUserId();
    if (userId == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cart')
        .doc(animal.id)
        .set({
      'name': animal.name,
      'category': animal.category,
      'price': animal.price,
      'imageUrl': animal.imageUrl,
      'isButchered': isButchered,
      'deliveryDay': deliveryDay,
    });

    _cartItems.add(CartItem(
      animal: animal,
      isButchered: isButchered,
      deliveryDay: deliveryDay,
    ));
    notifyListeners();
  }

  Future<void> removeFromCart(String animalId) async {
    final userId = _authService?.getCurrentUserId();
    if (userId == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cart')
        .doc(animalId)
        .delete();

    _cartItems.removeWhere((item) => item.animal.id == animalId);
    notifyListeners();
  }

  Future<void> updateCartItem(String animalId, bool isButchered, String deliveryDay) async {
    final userId = _authService?.getCurrentUserId();
    if (userId == null) return;

    final index = _cartItems.indexWhere((item) => item.animal.id == animalId);
    if (index != -1) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('cart')
          .doc(animalId)
          .update({
        'isButchered': isButchered,
        'deliveryDay': deliveryDay,
      });

      _cartItems[index] = CartItem(
        animal: _cartItems[index].animal,
        isButchered: isButchered,
        deliveryDay: deliveryDay,
      );
      notifyListeners();
    }
  }

  Future<void> clearCart() async {
    final userId = _authService?.getCurrentUserId();
    if (userId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('cart')
        .get();

    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }

    _cartItems.clear();
    notifyListeners();
  }
}