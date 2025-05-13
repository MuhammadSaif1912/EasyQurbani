import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/animal_model.dart';
import 'auth_service.dart';

class WishlistService with ChangeNotifier {
  AuthService? _authService;

  WishlistService(this._authService);

  List<AnimalModel> _wishlist = [];

  List<AnimalModel> get wishlist => _wishlist;

  void setAuthService(AuthService authService) {
    _authService = authService;
  }

  Future<void> loadWishlist() async {
    final userId = _authService?.getCurrentUserId();
    if (userId == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('wishlist')
        .get();

    _wishlist = snapshot.docs.map((doc) {
      final data = doc.data();
      return AnimalModel(
        id: doc.id,
        name: data['name'],
        category: data['category'],
        price: data['price'].toDouble(),
        imageUrl: data['imageUrl'],
      );
    }).toList();
    notifyListeners();
  }

  Future<void> addToWishlist(AnimalModel animal) async {
    final userId = _authService?.getCurrentUserId();
    if (userId == null) return;

    if (!_wishlist.any((item) => item.id == animal.id)) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('wishlist')
          .doc(animal.id)
          .set({
        'name': animal.name,
        'category': animal.category,
        'price': animal.price,
        'imageUrl': animal.imageUrl,
      });

      _wishlist.add(animal);
      notifyListeners();
    }
  }

  Future<void> removeFromWishlist(String animalId) async {
    final userId = _authService?.getCurrentUserId();
    if (userId == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('wishlist')
        .doc(animalId)
        .delete();

    _wishlist.removeWhere((item) => item.id == animalId);
    notifyListeners();
  }
}