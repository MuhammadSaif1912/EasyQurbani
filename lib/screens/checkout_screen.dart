import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../models/order_model.dart';
import '../models/cart_item.dart';
import '../widgets/custom_drawer.dart';

class CheckoutScreen extends StatefulWidget {
  @override
  _CheckoutScreenState createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<String, bool> _butcherOptions = {};
  Map<String, String> _deliveryDays = {};
  final double butcherServiceFee = 7000.0;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    final cartService = Provider.of<CartService>(context, listen: false);
    for (var item in cartService.cartItems) {
      _butcherOptions[item.animal.id] = false;
      _deliveryDays[item.animal.id] = 'Day 1';
    }
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isAdmin = await authService.isAdmin();
    setState(() {
      _isAdmin = isAdmin;
    });
  }

  double _calculateAdvancePayment(CartService cartService) {
    double animalPriceTotal = cartService.totalPrice;
    double advance = animalPriceTotal * 0.5;
    _butcherOptions.forEach((key, value) {
      if (value) {
        advance += butcherServiceFee;
      }
    });
    return advance.roundToDouble();
  }

  double _calculateTotalPrice(CartService cartService) {
    double total = cartService.totalPrice;
    _butcherOptions.forEach((key, value) {
      if (value) {
        total += butcherServiceFee;
      }
    });
    return total.roundToDouble();
  }

  Future<void> _saveOrder(CartService cartService, AuthService authService) async {
    final userId = authService.getCurrentUserId();
    if (userId == null) {
      throw Exception('User not logged in');
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    final userData = userDoc.data();
    if (userData == null) {
      throw Exception('User data not found');
    }

    final order = OrderModel(
      id: '', // Will be set by Firestore
      userId: userId,
      userName: userData['name'] ?? 'Unknown',
      userEmail: userData['email'] ?? 'Unknown',
      items: cartService.cartItems.map((item) {
        return CartItem(
          animal: item.animal,
          isButchered: _butcherOptions[item.animal.id] ?? false,
          deliveryDay: _deliveryDays[item.animal.id] ?? 'Day 1',
        );
      }).toList(),
      totalPrice: _calculateTotalPrice(cartService),
      timestamp: DateTime.now(),
    );

    final orderRef = await FirebaseFirestore.instance
        .collection('orders')
        .add(order.toFirestore());

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('purchases')
        .doc(orderRef.id)
        .set(order.toFirestore());
  }

  Future<void> _logout(BuildContext context) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signOut();
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartService = Provider.of<CartService>(context);
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: Colors.green[700],
        elevation: 4,
        shadowColor: Colors.green[900],
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
      ),
      drawer: CustomDrawer(
        isAdmin: _isAdmin,
        onLogout: _logout,
      ),
      body: cartService.cartItems.isEmpty
          ? const Center(
              child: Text(
                'Your cart is empty',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: cartService.cartItems.length,
              itemBuilder: (context, index) {
                final item = cartService.cartItems[index];
                return Card(
                  elevation: 8,
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12.0),
                          child: CachedNetworkImage(
                            imageUrl: item.animal.imageUrl,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                color: Colors.green,
                              ),
                            ),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.broken_image, size: 80, color: Colors.grey),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.animal.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.animal.category,
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Price: Rs ${item.animal.price}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text(
                                    'Butcher Services (Rs 7000):',
                                    style: TextStyle(fontSize: 14, color: Colors.black54),
                                  ),
                                  const SizedBox(width: 8),
                                  Checkbox(
                                    value: _butcherOptions[item.animal.id] ?? false,
                                    activeColor: Colors.green[700],
                                    onChanged: (value) {
                                      setState(() {
                                        _butcherOptions[item.animal.id] = value ?? false;
                                      });
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              DropdownButton<String>(
                                value: _deliveryDays[item.animal.id] ?? 'Day 1',
                                items: ['Day 1', 'Day 2', 'Day 3']
                                    .map((day) => DropdownMenuItem(
                                          value: day,
                                          child: Text(
                                            day,
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _deliveryDays[item.animal.id] = value ?? 'Day 1';
                                  });
                                },
                                isExpanded: true,
                                style: const TextStyle(color: Colors.black, fontSize: 14),
                                dropdownColor: Colors.white,
                                underline: Container(
                                  height: 2,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: cartService.cartItems.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    for (var item in cartService.cartItems) {
                      cartService.updateCartItem(
                        item.animal.id,
                        _butcherOptions[item.animal.id] ?? false,
                        _deliveryDays[item.animal.id] ?? 'Day 1',
                      );
                    }
                    await _saveOrder(cartService, authService);
                    await cartService.clearCart();
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Payment Confirmation'),
                          content: const Text(
                            'Payment processed! \nRemaining due on delivery',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.pop(context);
                                Navigator.pushReplacementNamed(context, '/home');
                              },
                              child: const Text(
                                'OK',
                                style: TextStyle(color: Colors.green),
                              ),
                            ),
                          ],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          backgroundColor: Colors.white,
                          elevation: 8,
                        );
                      },
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error saving order: $e')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent.withOpacity(0.7),
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  elevation: 5,
                ),
                child: Text(
                  'Confirm Payment (Rs ${_calculateAdvancePayment(cartService)})',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}