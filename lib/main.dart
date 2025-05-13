// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/cart_service.dart';
import 'services/wishlist_service.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/wishlist_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/offers_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/users_screen.dart';
import 'dart:async';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      print('Firebase initialized successfully');
    } catch (e) {
      print('Error initializing Firebase: $e');
      // Optionally, handle error (e.g., show splash or retry screen)
    }

    runApp(const MyApp());
  }, (error, stack) {
    print('Uncaught error: $error');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProxyProvider<AuthService, WishlistService>(
          create: (context) => WishlistService(Provider.of<AuthService>(context, listen: false)),
          update: (_, authService, wishlistService) {
            wishlistService?.setAuthService(authService);
            wishlistService?.loadWishlist();
            return wishlistService ?? WishlistService(authService);
          },
        ),
        ChangeNotifierProxyProvider<AuthService, CartService>(
          create: (context) => CartService(Provider.of<AuthService>(context, listen: false)),
          update: (_, authService, cartService) {
            cartService?.setAuthService(authService);
            cartService?.loadCart();
            return cartService ?? CartService(authService);
          },
        ),
      ],
      child: MaterialApp(
        title: 'Easy Qurbani',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.green,
        ),
        initialRoute: '/login',
        routes: {
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/home': (context) => const HomeScreen(),
          '/cart': (context) => CartScreen(),
          '/wishlist': (context) => WishlistScreen(),
          '/checkout': (context) => CheckoutScreen(),
          '/offers': (context) => const OffersScreen(),
          '/orders': (context) => OrdersScreen(),
          '/users': (context) => UsersScreen(),
        },
      ),
    );
  }
}