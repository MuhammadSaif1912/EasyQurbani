import 'animal_model.dart';

class CartItem {
  final AnimalModel animal;
  final bool isButchered;
  final String deliveryDay;
  final int quantity;

  CartItem({
    required this.animal,
    this.isButchered = false,
    required this.deliveryDay,
    this.quantity = 1,
  });

  double get totalPrice => animal.price;
}