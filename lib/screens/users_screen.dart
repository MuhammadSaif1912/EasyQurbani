// lib/screens/users_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart'; 

class UsersScreen extends StatefulWidget {
  @override
  _UsersScreenState createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
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

  Stream<List<Map<String, dynamic>>> _getUsersWithOrders() {
    if (!_isAdmin) return Stream.value([]);
    return FirebaseFirestore.instance
        .collection('users')
        .snapshots()
        .asyncMap((userSnapshot) async {
      final usersWithOrders = <Map<String, dynamic>>[];
      for (var userDoc in userSnapshot.docs) {
        final userData = userDoc.data();

        if ((userData['name'] ?? '').toString().toLowerCase() == 'admin') {
        continue;
      }

        final user = UserModel(
          uid: userDoc.id,
          name: userData['name'] ?? '',
          address: userData['address'] ?? '',
          email: userData['email'] ?? '',
          contact: userData['contact'] ?? '',
        );

        final purchaseSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('purchases')
            .orderBy('timestamp', descending: true)
            .get();

        final orders = <OrderModel>[];
        for (var doc in purchaseSnapshot.docs) {
          final order = await OrderModel.fromFirestore(doc.data(), doc.id);
          orders.add(order);
        }

        usersWithOrders.add({
          'user': user,
          'orders': orders,
        });
      }
      return usersWithOrders;
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
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(color: Colors.blue),
      ),
    );
  }

  if (!_isAdmin) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Users', style: TextStyle(color: Colors.white),),
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
        title: const Text('Users', style: TextStyle(color: Colors.white),),
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
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _getUsersWithOrders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.blue));
          }
          if (snapshot.hasError) {
            print('Users error: ${snapshot.error}');
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No users available'));
          }
          final usersWithOrders = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: usersWithOrders.length,
            itemBuilder: (context, index) {
              final userData = usersWithOrders[index];
              final user = userData['user'] as UserModel;
              final orders = userData['orders'] as List<OrderModel>;
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
                        'Name: ${user.name}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      Text('Email: ${user.email}', style: TextStyle(color: Colors.blue[700], fontSize: 14)),
                      Text('Address: ${user.address}', style: TextStyle(color: Colors.blue[700], fontSize: 14)),
                      Text('Contact: ${user.contact}', style: TextStyle(color: Colors.blue[700], fontSize: 14)),
                      if (orders.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Order History:',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                      for (var order in orders)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Order Date: ${order.timestamp?.toString().substring(0, 16) ?? 'N/A'}',
                                style: TextStyle(color: Colors.blue[700], fontSize: 14),
                              ),
                              Text(
                                'Total Price: Rs ${order.totalPrice.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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
                                        placeholder: (context, url) => const Center(child: CircularProgressIndicator(color: Colors.blue)),
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
                                            style: TextStyle(color: Colors.blue[700], fontSize: 14),
                                          ),
                                          Text(
                                            'Price: Rs ${item.animal.price.toStringAsFixed(2)}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          ),
                                          Text(
                                            'Butchered: ${item.isButchered ? 'Yes' : 'No'}',
                                            style: TextStyle(color: Colors.blue[700], fontSize: 14),
                                          ),
                                          Text(
                                            'Delivery Day: ${item.deliveryDay}',
                                            style: TextStyle(color: Colors.blue[700], fontSize: 14),
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