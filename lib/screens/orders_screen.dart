// lib/screens/orders_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OrdersScreen extends StatefulWidget {
  @override
  _OrdersScreenState createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  bool _isAdmin = false;
  String? _currentUserId;
  bool _loading = true;

@override
void initState() {
  super.initState();
  _initialize();
}

void _initialize() async {
  await FirebaseAuth.instance.currentUser?.getIdToken(true); // Force token refresh
  final authService = Provider.of<AuthService>(context, listen: false);
  _currentUserId = authService.getCurrentUserId();
  final isAdmin = await authService.isAdmin();
  print('Admin status: $isAdmin, User ID: $_currentUserId');
  setState(() {
    _isAdmin = isAdmin;
    _loading = false;
  });
}

  Stream<List<OrderModel>> _getOrders() {
    if (!_isAdmin) return Stream.value([]);
    return FirebaseFirestore.instance
        .collection('orders')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final orders = <OrderModel>[];
      for (var doc in snapshot.docs) {
        final order = await OrderModel.fromFirestore(doc.data(), doc.id);
        orders.add(order);
      }
      return orders;
    });
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
    if (_loading) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders', style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.green[700],
      ),
      body: const Center(
        child: CircularProgressIndicator(color: Colors.orange),
      ),
    );
  }
  if (!_isAdmin) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders', style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.green[700],
      ),
      body: const Center(
        child: Text(
          'Access Denied: Admin Only',
          style: TextStyle(fontSize: 18, color: Colors.red),
        ),
      ),
    );
  }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders', style: TextStyle(color: Colors.white),),
        backgroundColor: Colors.green[700],
      ),
            drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.green[700],
              ),
              child: const Text(
                'Easy Qurbani',
                style: TextStyle(
                  color: Colors.yellowAccent,
                  fontSize: 24,
                ),
              ),
            ),
            ListTile(
              leading: Icon(Icons.home_sharp, color: Colors.amber),
              title: const Text('Home', style: TextStyle(color: Colors.amberAccent)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/home');
                },
              ),
            if (!_isAdmin)
              ListTile(
                leading: Icon(Icons.favorite, color: Colors.red[700]),
                title: const Text('Wishlist', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/wishlist');
                },
              ),
            if (!_isAdmin)
              ListTile(
                leading: Icon(Icons.shopping_cart, color: Colors.green[700]),
                title: const Text('Cart', style: TextStyle(color: Colors.green)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/cart');
                },
              ),
            ListTile(
              leading: Icon(Icons.local_offer, color: Colors.purple[700]),
              title: const Text('Offers', style: TextStyle(color: Colors.purple)),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/offers');
              },
            ),
            if (_isAdmin)
              ListTile(
                leading: Icon(Icons.receipt, color: Colors.orange[700]),
                title: const Text('Orders', style: TextStyle(color: Colors.orange)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/orders');
                },
              ),
            if (_isAdmin)
              ListTile(
                leading: Icon(Icons.people, color: Colors.blue[700]),
                title: const Text('Users', style: TextStyle(color: Colors.blue)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/users');
                },
              ),
            ListTile(
              leading: Icon(Icons.logout, color: Colors.red[700]),
              title: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                _logout(context);
              },
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: _getOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }
          if (snapshot.hasError) {
            print('Orders error: ${snapshot.error}');
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No orders available'));
          }
          final orders = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'User: ${order.userName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Email: ${order.userEmail}',
                        style: TextStyle(color: Colors.orange[700], fontSize: 14),
                      ),
                      Text(
                        'Total Price: Rs ${order.totalPrice.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        'Order Date: ${order.timestamp?.toString().substring(0, 16) ?? 'N/A'}',
                        style: TextStyle(color: Colors.orange[700], fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Items:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      ...order.items.map((item) => Padding(
                        padding: const EdgeInsets.only(top: 8.0),
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
                                placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.orange)),
                                errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 80),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.animal.name,
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Category: ${item.animal.category}',
                                    style: TextStyle(color: Colors.orange[700], fontSize: 14),
                                  ),
                                  Text(
                                    'Price: Rs ${item.animal.price.toStringAsFixed(2)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                  Text(
                                    'Butchered: ${item.isButchered ? 'Yes' : 'No'}',
                                    style: TextStyle(color: Colors.orange[700], fontSize: 14),
                                  ),
                                  Text(
                                    'Delivery Day: ${item.deliveryDay}',
                                    style: TextStyle(color: Colors.orange[700], fontSize: 14),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}