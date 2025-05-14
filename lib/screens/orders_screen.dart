import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/custom_drawer.dart';

class OrdersScreen extends StatefulWidget {
  @override
  _OrdersScreenState createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isAdmin = false;
  String? _currentUserId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() async {
    await FirebaseAuth.instance.currentUser?.getIdToken(true);
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
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('Orders', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.green[700],
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.orange),
        ),
      );
    }
    if (!_isAdmin) {
      return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('Orders', style: TextStyle(color: Colors.white)),
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
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Orders', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[700],
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
                        'Username: ${order.userName}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
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