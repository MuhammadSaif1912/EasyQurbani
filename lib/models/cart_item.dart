import 'animal_model.dart';

class CartItem {
  final AnimalModel animal;
  final bool isButchered;
  final String deliveryDay;

  CartItem({
    required this.animal,
    this.isButchered = false,
    required this.deliveryDay,
  });

  double get totalPrice => animal.price;
}