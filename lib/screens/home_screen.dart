// lib/screens/home_screen.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/animal_model.dart';
import '../services/auth_service.dart';
import '../services/cart_service.dart';
import '../services/wishlist_service.dart';

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
          title: const Text('Add to Cart'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Text(
                'Advance Payment (50%): Rs ${animal.price * 0.5}',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
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
          title: Text('Make an Offer for ${animal.name}'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        backgroundColor: Colors.white,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.menu_sharp,
                      color: Colors.black,
                      size: 30,
                    ),
                    onPressed: () {
                      _scaffoldKey.currentState?.openDrawer();
                    },
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: Row(
                      children: [
                        const Text(
                          'Homepage',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.white,
                          ),
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 180,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedCategory,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.green[50],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      borderSide: BorderSide.none,
                                    ),
                                    labelStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  items: ['All', 'Lamb', 'Goat', 'Cow', 'Camel', 'Rare']
                                      .map((category) => DropdownMenuItem(
                                            value: category,
                                            child: Text(category, style: TextStyle(fontSize: 12)),
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
                              const SizedBox(width: 16.0),
                              Container(
                                width: 180,
                                child: DropdownButtonFormField<String>(
                                  value: _sortOption,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.green[50],
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                      borderSide: BorderSide.none,
                                    ),
                                    labelStyle: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  items: ['Price: Low to High', 'Price: High to Low']
                                      .map((option) => DropdownMenuItem(
                                            value: option,
                                            child: Text(option, style: TextStyle(fontSize: 12)),
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
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 6.0,
                      mainAxisSpacing: 6.0,
                      childAspectRatio: 3.0,
                    ),
                    itemCount: animals.length,
                    itemBuilder: (context, index) {
                      final animal = animals[index];
                      return GestureDetector(
                        onTap: () => _showOfferDialog(context, animal),
                        child: Container(
                          width: 100,
                          height: 100,
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          animal.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          animal.category,
                                          style: TextStyle(
                                            color: Colors.green[700],
                                            fontSize: 12,
                                          ),
                                        ),
                                        Text(
                                          'Rs ${animal.price}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
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
                                                    size: 25,
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
                                                size: 30,
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
                                ClipRRect(
                                  borderRadius: const BorderRadius.horizontal(
                                      right: Radius.circular(12.0)),
                                  child: CachedNetworkImage(
                                    imageUrl: animal.imageUrl,
                                    width: 200,
                                    height: 150,
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
                              ],
                            ),
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
