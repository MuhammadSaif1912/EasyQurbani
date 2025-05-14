import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/offer_model.dart';
import '../widgets/custom_drawer.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  _OffersScreenState createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Stream<List<OfferModel>>? _offersStream;
  bool _isAdmin = false;
  final ScrollController _scrollController = ScrollController();
  String? _highlightOfferId;

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
        .orderBy('timestamp', descending: true);

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      final String? offerId = args['offerId'];
      if (offerId != null) {
        setState(() {
          _highlightOfferId = offerId;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToOffer(offerId);
        });
      }
    }
  }

  void _scrollToOffer(String offerId) {
    const double itemHeight = 120.0;
    _offersStream?.first.then((offers) {
      final index = offers.indexWhere((offer) => offer.id == offerId);
      if (index != -1) {
        _scrollController.animateTo(
          index * itemHeight,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  Future<double?> _getOriginalPrice(String animalId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('animals')
          .doc(animalId)
          .get();
      return doc.data()?['price']?.toDouble();
    } catch (e) {
      print('Error fetching original price: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        backgroundColor: Colors.green[700],
        title: const Text(
          'Offers',
          style: TextStyle(color: Colors.white),
        ),
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
      body: FutureBuilder<bool>(
        future: authService.isAdmin(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.green),
            );
          }

          final isAdmin = snapshot.data!;

          return StreamBuilder<List<OfferModel>>(
            stream: _offersStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.green),
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
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                itemCount: offers.length,
                itemBuilder: (context, index) {
                  final offer = offers[index];
                  final isFinalStatus = offer.status != 'pending';
                  final isHighlighted = _highlightOfferId == offer.id;

                  return FutureBuilder<double?>(
                    future: _getOriginalPrice(offer.animalId),
                    builder: (context, priceSnapshot) {
                      final originalPrice = priceSnapshot.data;
                      final difference = originalPrice != null && offer.offerPrice != null
                          ? originalPrice - offer.offerPrice
                          : null;
                      final differenceText = difference != null
                          ? (difference > 0
                              ? '(-Rs ${difference.toStringAsFixed(2)})'
                              : '(+Rs ${(-difference).toStringAsFixed(2)})')
                          : '';

                      return Card(
                        color: isHighlighted ? Colors.green[200] : null,
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
                                    if(_isAdmin) ...[
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
                                  ],
                                  const SizedBox(height: 4),
                                    if (originalPrice != null) ...[
                                      Text(
                                        'Original Price: Rs ${originalPrice.toStringAsFixed(2)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(color: Colors.black),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Text(
                                      'Offered Price: Rs ${offer.offerPrice.toStringAsFixed(2)}',
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
                              if (isAdmin && !isFinalStatus)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        backgroundColor: Colors.green[600],
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        minimumSize: const Size(90, 40),
                                      ),
                                      onPressed: () => _updateOfferStatus(offer.id, 'accepted'),
                                      child: const Text('Accept'),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        backgroundColor: Colors.red[600],
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        minimumSize: const Size(90, 40),
                                      ),
                                      onPressed: () => _updateOfferStatus(offer.id, 'rejected'),
                                      child: const Text('Decline'),
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
          );
        },
      ),
    );
  }
}