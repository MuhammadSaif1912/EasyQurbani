import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wishlist_service.dart';
import '../services/cart_service.dart';
import '../models/animal_model.dart';

class WishlistScreen extends StatefulWidget {
  @override
  _WishlistScreenState createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  @override
  void initState() {
    super.initState();
    // Load wishlist data when the screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<WishlistService>(context, listen: false).loadWishlist();
    });
  }

  Future<void> _showCartDialog(BuildContext context, AnimalModel animal) async {
    String selectedDay = 'Day 1';
    bool isButchered = false;

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'Add to Cart',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedDay,
                    decoration: InputDecoration(
                      labelText: 'Delivery Day',
                      labelStyle: TextStyle(color: Colors.green[700]),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(color: Colors.green[700]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                        borderSide: BorderSide(color: Colors.green[700]!, width: 2),
                      ),
                    ),
                    items: ['Day 1', 'Day 2', 'Day 3']
                        .map((day) => DropdownMenuItem(
                              value: day,
                              child: Text(day),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedDay = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Checkbox(
                        value: isButchered,
                        onChanged: (value) {
                          setState(() {
                            isButchered = value!;
                          });
                        },
                        activeColor: Colors.green[700],
                      ),
                      const Text('Butcher the animal?'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Advance Payment (50%): Rs ${animal.price * 0.5}',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.green[700]),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Provider.of<CartService>(context, listen: false)
                        .addToCart(animal, isButchered, selectedDay);
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${animal.name} added to cart'),
                        duration: const Duration(seconds: 1),
                        backgroundColor: Colors.green[700],
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final wishlistService = Provider.of<WishlistService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wishlist'),
        backgroundColor: Colors.green[700],
      ),
      body: wishlistService.wishlist.isEmpty
          ? const Center(child: Text('Your wishlist is empty'))
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: wishlistService.wishlist.length,
              itemBuilder: (context, index) {
                final animal = wishlistService.wishlist[index];
                return Card(
                  elevation: 5,
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8.0),
                      child: CachedNetworkImage(
                        imageUrl: animal.imageUrl,
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(Icons.broken_image, size: 50),
                      ),
                    ),
                    title: Text(
                      animal.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.add_shopping_cart,
                            color: Colors.green[700],
                            size: 20,
                          ),
                          onPressed: () async {
                            await _showCartDialog(context, animal);
                          },
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.favorite,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () {
                            wishlistService.removeFromWishlist(animal.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${animal.name} removed from wishlist'),
                                duration: const Duration(seconds: 1),
                                backgroundColor: Colors.green[700],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}