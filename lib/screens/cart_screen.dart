import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cart_service.dart';
import '../services/auth_service.dart';

class CartScreen extends StatefulWidget {
  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    // Load cart data when the screen is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CartService>(context, listen: false).loadCart();
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
    final cartService = Provider.of<CartService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart', style: TextStyle(color: Colors.white),),
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
              ListTile(
                leading: Icon(Icons.favorite, color: Colors.brown[700]),
                title: const Text('Wishlist', style: TextStyle(color: Colors.brown)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/wishlist');
                },
              ),
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
      body: cartService.cartItems.isEmpty
          ? const Center(child: Text('Your cart is empty'))
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: cartService.cartItems.length,
              itemBuilder: (context, index) {
                final item = cartService.cartItems[index];
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
                        imageUrl: item.animal.imageUrl,
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
                      item.animal.name,
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
                          item.animal.category,
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          'Price: Rs ${item.totalPrice}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          'Advance (50%): Rs ${item.totalPrice * 0.5}',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete,
                        color: Colors.green[700],
                        size: 20,
                      ),
                      onPressed: () {
                        cartService.removeFromCart(item.animal.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${item.animal.name} removed from cart'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
      bottomNavigationBar: cartService.cartItems.isNotEmpty
          ? Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, '/checkout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.tealAccent.withOpacity(0.7),
                ),
                child: Text(
                  'Proceed to Checkout (Rs ${cartService.totalPrice * 0.5})',
                  style: const TextStyle(fontSize: 16, color: Colors.black),
                ),
              ),
            )
          : null,
    );
  }
}