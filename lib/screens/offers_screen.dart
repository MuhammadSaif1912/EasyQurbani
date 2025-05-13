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

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'My Offers',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.green,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.home, color: Colors.white),
            tooltip: 'Go to Home',
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/home');
            },
          ),
        ],
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
                          // Leading icon
                          const Icon(
                            Icons.local_offer,
                            color: Colors.green,
                            size: 40,
                          ),
                          const SizedBox(width: 16),
                          // Offer details
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
                                        color: Colors.black87,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Offered by: ${offer.userName}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.black54,
                                        fontStyle: FontStyle.italic,
                                      ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Price: \$${offer.offerPrice.toStringAsFixed(2)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Colors.black54),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      'Status: ',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: Colors.black54),
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
                                        ?.copyWith(color: Colors.black54),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Admin actions
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
                                      ? null // Disable if status is not pending
                                      : () => _updateOfferStatus(offer.id, 'accepted'),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.cancel,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Reject Offer',
                                  onPressed: isFinalStatus
                                      ? null // Disable if status is not pending
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