import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../models/order_model.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/custom_drawer.dart';

class UsersScreen extends StatefulWidget {
  @override
  _UsersScreenState createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
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

  void _showOrderHistoryDialog(BuildContext context, List<OrderModel> orders) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            'Order History',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.green),
          ),
          content: Container(
            width: double.maxFinite,
            child: orders.isEmpty
                ? const Text('No orders found', style: TextStyle(fontSize: 16, color: Colors.grey))
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: orders.length,
                    itemBuilder: (context, index) {
                      final order = orders[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
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
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.green, fontSize: 16),
              ),
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          backgroundColor: Colors.white,
          elevation: 8,
        );
      },
    );
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
        key: _scaffoldKey,
        appBar: AppBar(
          title: const Text('Users', style: TextStyle(color: Colors.white)),
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
        title: const Text('Users', style: TextStyle(color: Colors.white)),
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
                        '${user.name}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                      ),
                      Text('Email: ${user.email}', style: TextStyle(color: Colors.blue[700], fontSize: 14)),
                      Text('Address: ${user.address}', style: TextStyle(color: Colors.blue[700], fontSize: 14)),
                      Text('Contact: ${user.contact}', style: TextStyle(color: Colors.blue[700], fontSize: 14)),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: () {
                            _showOrderHistoryDialog(context, orders);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                          child: const Text(
                            'Order History',
                            style: TextStyle(fontSize: 14),
                          ),
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