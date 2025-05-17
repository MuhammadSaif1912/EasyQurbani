import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/animal_model.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/wishlist_service.dart';
import '../widgets/custom_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'All';
  String _sortOption = 'Price: Low to High';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    // Set the status bar color to match the app theme globally for consistency
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.green, // Matches the app theme
      statusBarIconBrightness: Brightness.light, // White icons for contrast
    ));
    final authService = Provider.of<AuthService>(context, listen: false);
    authService.isAdmin().then((isAdmin) {
      setState(() {
        _isAdmin = isAdmin;
      });
    });
  }

  Stream<List<AnimalModel>> _getAnimals() {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection('animals');
    
    if (_selectedCategory != 'All' && _selectedCategory != 'Rare') {
      query = query.where('category', isEqualTo: _selectedCategory);
    }
    
    if (_sortOption == 'Price: Low to High') {
      query = query.orderBy('price', descending: false);
    } else {
      query = query.orderBy('price', descending: true);
    }

    return query.snapshots().map(
      (snapshot) {
        print('Retrieved ${snapshot.docs.length} documents for category: $_selectedCategory');
        return snapshot.docs.map((doc) {
          print('Document ID: ${doc.id}, Category: ${doc['category']}, Name: ${doc['name']}');
          final animal = AnimalModel(
            id: doc.id,
            name: doc['name'],
            category: doc['category'],
            price: doc['price'].toDouble(),
            imageUrl: doc['imageUrl'],
          );
          if (_selectedCategory == 'Rare' && !animal.name.toLowerCase().contains('rare')) {
            return null;
          }
          return animal;
        }).whereType<AnimalModel>().toList();
      },
    );
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

  Future<void> _showCartDialog(BuildContext context, AnimalModel animal) async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Add to Cart',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Text(
                '50% Advance Payment Will Be Charged!',
                style: TextStyle(
                  color: Colors.black,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Provider.of<CartService>(context, listen: false)
                    .addToCart(animal, false, '');
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Added to Cart'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent.withOpacity(0.7),
              ),
              child: const Text('Confirm', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showOfferDialog(BuildContext context, AnimalModel animal) async {
    final TextEditingController offerController = TextEditingController();
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.getCurrentUserId();

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to make an offer'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Name Your Price - ${animal.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Current Price: Rs ${animal.price}',
                style: TextStyle(
                  color: Colors.green[700],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: offerController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Your Offer (Rs)',
                  border: const OutlineInputBorder(),
                  hintText: 'Enter your offer price',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final offerPrice = double.tryParse(offerController.text);
                if (offerPrice == null || offerPrice <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid offer price'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }

                try {
                  await FirebaseFirestore.instance.collection('offers').add({
                    'animalId': animal.id,
                    'animalName': animal.name,
                    'userId': userId,
                    'offerPrice': offerPrice,
                    'timestamp': FieldValue.serverTimestamp(),
                    'status': 'pending',
                  });

                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Offer of Rs $offerPrice submitted for ${animal.name}'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to submit offer: $e'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.tealAccent.withOpacity(0.7),
              ),
              child: const Text('Submit Offer', style: TextStyle(color: Colors.black)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _navigateToLatestOffer(BuildContext context, AnimalModel animal) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('offers')
          .where('animalId', isEqualTo: animal.id)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No offers yet for ${animal.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
        return;
      }

      final latestOffer = querySnapshot.docs.first;
      Navigator.pushNamed(
        context,
        '/offers',
        arguments: {
          'animalId': animal.id,
          'offerId': latestOffer.id,
        },
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error fetching offers: $e'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Home', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green[700], // Matches LoginScreen AppBar color
        leading: IconButton(
          icon: const Icon(Icons.menu_sharp, color: Colors.white),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
        actions: [
          Row(
            children: [
              Container(
                width: isMobile ? screenWidth * 0.2 : 180,
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.green[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide.none,
                    ),
                    labelStyle: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 10 : 12,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 6.0,
                      vertical: isMobile ? 8.0 : 12.0,
                    ),
                  ),
                  items: ['All', 'Lamb', 'Goat', 'Cow', 'Camel', 'Rare']
                      .map((category) => DropdownMenuItem(
                            value: category,
                            child: Text(
                              category,
                              style: TextStyle(fontSize: isMobile ? 10 : 12),
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      print('Selected category changed to: $value');
                      _selectedCategory = value!;
                    });
                  },
                ),
              ),
              Container(
                width: isMobile ? screenWidth * 0.35 : 180,
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: DropdownButtonFormField<String>(
                  value: _sortOption,
                  isExpanded: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.green[50],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                      borderSide: BorderSide.none,
                    ),
                    labelStyle: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 10 : 12,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 6.0,
                      vertical: isMobile ? 8.0 : 12.0,
                    ),
                  ),
                  items: ['Price: Low to High', 'Price: High to Low']
                      .map((option) => DropdownMenuItem(
                            value: option,
                            child: Text(
                              option,
                              style: TextStyle(fontSize: isMobile ? 10 : 12),
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      print('Sort option changed to: $value');
                      _sortOption = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      drawer: CustomDrawer(
        isAdmin: _isAdmin,
        onLogout: _logout,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green, Colors.greenAccent],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<AnimalModel>>(
                key: ValueKey(_selectedCategory),
                stream: _getAnimals(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    print('Error loading animals: ${snapshot.error}');
                    return Center(
                      child: Text(
                        'Error loading animals: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final animals = snapshot.data!;
                  if (animals.isEmpty) {
                    return const Center(child: Text('No animals available in this category'));
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.all(16.0),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isMobile ? 1 : 2,
                      crossAxisSpacing: 6.0,
                      mainAxisSpacing: 6.0,
                      childAspectRatio: isMobile ? 2 : 2.1,
                    ),
                    itemCount: animals.length,
                    itemBuilder: (context, index) {
                      final animal = animals[index];
                      return GestureDetector(
                        onTap: () => _isAdmin
                            ? _navigateToLatestOffer(context, animal)
                            : _showOfferDialog(context, animal),
                        child: Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        animal.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: isMobile ? 14 : 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        animal.category,
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontSize: isMobile ? 10 : 12,
                                        ),
                                      ),
                                      Text(
                                        'Rs ${animal.price}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: isMobile ? 12 : 14,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      if (!_isAdmin) // Show icons only for non-admins
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Consumer<WishlistService>(
                                              builder: (context, wishlistService, child) {
                                                final isWishlisted = wishlistService.wishlist
                                                    .any((item) => item.id == animal.id);
                                                return IconButton(
                                                  icon: Icon(
                                                    isWishlisted ? Icons.favorite : Icons.favorite_border,
                                                    color: isWishlisted ? Colors.red : Colors.green[700],
                                                    size: isMobile ? 20 : 25,
                                                  ),
                                                  constraints: const BoxConstraints(),
                                                  padding: EdgeInsets.zero,
                                                  onPressed: () {
                                                    if (isWishlisted) {
                                                      wishlistService.removeFromWishlist(animal.id);
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(
                                                          content: Text('Removed from Wishlist'),
                                                          duration: Duration(seconds: 1),
                                                        ),
                                                      );
                                                    } else {
                                                      wishlistService.addToWishlist(animal);
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(
                                                          content: Text('Added to Wishlist'),
                                                          duration: Duration(seconds: 1),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                );
                                              },
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.add_shopping_cart,
                                                color: Colors.green[700],
                                                size: isMobile ? 24 : 30,
                                              ),
                                              constraints: const BoxConstraints(),
                                              padding: EdgeInsets.zero,
                                              onPressed: () {
                                                _showCartDialog(context, animal);
                                              },
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.horizontal(
                                      right: Radius.circular(12.0)),
                                  child: CachedNetworkImage(
                                    imageUrl: animal.imageUrl,
                                    width: isMobile ? screenWidth * 0.3 : 200,
                                    height: isMobile ? screenWidth * 0.45 : 150,
                                    fit: BoxFit.cover,
                                    alignment: Alignment.center,
                                    placeholder: (context, url) => Center(
                                      child: CircularProgressIndicator(
                                        color: Colors.green[700],
                                      ),
                                    ),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.broken_image, size: 50),
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
            ),
          ],
        ),
      ),
    );
  }
}