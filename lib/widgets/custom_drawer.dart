// lib/widgets/custom_drawer.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CustomDrawer extends StatelessWidget {
  final bool isAdmin;
  final Function(BuildContext) onLogout;

  const CustomDrawer({
    Key? key,
    required this.isAdmin,
    required this.onLogout,
  }) : super(key: key);

  Future<String?> _getUsername(String? userId) async {
    if (userId == null) {
      print('No user ID found, user might not be logged in');
      return null;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      if (!doc.exists) {
        print('User document does not exist for userId: $userId');
        return null;
      }
      final name = doc.data()?['name'] as String?;
      print('Fetched name: $name');
      return name;
    } catch (e) {
      print('Error fetching username: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return Drawer(
            backgroundColor: Colors.white,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(color: Colors.green[700]),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Easy Qurbani',
                        style: TextStyle(color: Colors.yellowAccent, fontSize: 24),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Loading...',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ],
                  ),
                ),
                // Placeholder items to avoid null layout
                const ListTile(),
              ],
            ),
          );
        }

        final user = authSnapshot.data;
        final userId = user?.uid;

        return Drawer(
          backgroundColor: Colors.white,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(color: Colors.green[700]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Easy Qurbani',
                      style: TextStyle(color: Colors.yellowAccent, fontSize: 24),
                    ),
                    const SizedBox(height: 8),
                    FutureBuilder<String?>(
                      future: _getUsername(userId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Text(
                            'Loading...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          );
                        }
                        if (snapshot.hasError) {
                          print('FutureBuilder error: ${snapshot.error}');
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Error fetching username')),
                            );
                          });
                        }
                        final name = snapshot.data ?? 'Guest';
                        return Text(
                          '$name',
                          style: const TextStyle(
                            color: Colors.yellowAccent,
                             fontSize: 16,
                             ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: Icon(Icons.home_sharp, color: Colors.amber[700]),
                title: const Text('Home', style: TextStyle(color: Colors.amberAccent)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/home');
                  },
                ),
              if (!isAdmin)
                ListTile(
                  leading: Icon(Icons.favorite, color: Colors.brown[700]),
                  title: const Text('Wishlist', style: TextStyle(color: Colors.brown)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/wishlist');
                  },
                ),
              if (!isAdmin)
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
              if (isAdmin)
                ListTile(
                  leading: Icon(Icons.receipt, color: Colors.orange[700]),
                  title: const Text('Orders', style: TextStyle(color: Colors.orange)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/orders');
                  },
                ),
              if (isAdmin)
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
                  onLogout(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}