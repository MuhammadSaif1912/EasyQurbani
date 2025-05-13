// lib/screens/offers_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/offer_model.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  _OffersScreenState createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  Stream<List<OfferModel>>? _offersStream;
  bool _isAdmin = false;


  @override
  void initState() {
    super.initState();
    _initializeOffersStream();
  }

  Future<void> _initializeOffersStream() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.getCurrentUserId();

    if (userId == null) {
      setState(() {
        _offersStream = Stream.value([]);
      });
      return;
    }

    final isAdmin = await authService.isAdmin();
    setState(() {
      _isAdmin = isAdmin;
    });
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('offers')
        .orderBy('timestamp', descending: true); // Sort by timestamp, latest first

    if (!isAdmin) {
      query = query.where('userId', isEqualTo: userId);
    }

    setState(() {
      _offersStream = query.snapshots().asyncMap((snapshot) async {
        final offers = <OfferModel>[];
        for (var doc in snapshot.docs) {
          final offer = await OfferModel.fromFirestore(doc.data(), doc.id);
          offers.add(offer);
        }
        return offers;
      });
    });
  }

  Future<void> _updateOfferStatus(String offerId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection('offers')
          .doc(offerId)
          .update({'status': status});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Offer $status successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating offer: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.grey;
    }
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
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        title: const Text(
          'Offers',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
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
                leading: Icon(Icons.favorite, color: Colors.brown[700]),
                title: const Text('Wishlist', style: TextStyle(color: Colors.brown)),
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
      body: FutureBuilder<bool>(
        future: authService.isAdmin(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                color: Colors.green,
              ),
            );
          }

          final isAdmin = snapshot.data!;

          return StreamBuilder<List<OfferModel>>(
            stream: _offersStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: Colors.green,
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red, fontSize: 16),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Center(
                  child: Text(
                    'No offers available',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              }

              final offers = snapshot.data!;

              return ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: offers.length,
                itemBuilder: (context, index) {
                  final offer = offers[index];
                  final isFinalStatus = offer.status != 'pending'; // Check if status is accepted or rejected

                  return Card(
                    elevation: 3,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.local_offer_sharp,
                            color: Colors.purple,
                            size: 30,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  offer.animalName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Offered by - ${offer.userName}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Price: \$${offer.offerPrice.toStringAsFixed(2)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.black),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      'Status: ',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: Colors.black),
                                    ),
                                    Text(
                                      offer.status,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: _getStatusColor(offer.status),
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                                if (offer.timestamp != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Submitted: ${offer.timestamp!.toString().substring(0, 16)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.black),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isAdmin)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                  tooltip: 'Accept Offer',
                                  onPressed: isFinalStatus
                                      ? null
                                      : () => _updateOfferStatus(offer.id, 'accepted'),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.cancel,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Reject Offer',
                                  onPressed: isFinalStatus
                                      ? null
                                      : () => _updateOfferStatus(offer.id, 'rejected'),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}