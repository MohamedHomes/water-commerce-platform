import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import 'api_config.dart';

class CartState {
  const CartState({
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.loading,
    required this.error,
  });

  final List<CartItem> items;
  final double subtotal;
  final double discount;
  final double total;
  final bool loading;
  final String? error;

  factory CartState.initial() => const CartState(
        items: [],
        subtotal: 0,
        discount: 0,
        total: 0,
        loading: false,
        error: null,
      );
}

class CartItem {
  const CartItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.discountPercent,
  });

  final String productId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double? discountPercent;
}

final cartProvider = StateNotifierProvider<CartController, CartState>((ref) {
  return CartController();
});

class CartController extends StateNotifier<CartState> {
  CartController() : super(CartState.initial());

  final Dio _dio = Dio(BaseOptions(baseUrl: apiBaseUrl));
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> loadCart() async {
    state = CartState(
      items: state.items,
      subtotal: state.subtotal,
      discount: state.discount,
      total: state.total,
      loading: true,
      error: null,
    );

    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null || token.isEmpty) {
        throw StateError('Sign in is required to view your cart.');
      }
      final response = await _dio.get('/cart', options: Options(headers: {'Authorization': 'Bearer $token'}));
      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List? ?? []).map<CartItem>((entry) {
        final item = entry as Map<String, dynamic>;
        return CartItem(
          productId: item['productId']?.toString() ?? '',
          name: item['name']?.toString() ?? 'Product',
          quantity: int.tryParse(item['quantity']?.toString() ?? '0') ?? 0,
          unitPrice: double.tryParse(item['unitPrice']?.toString() ?? '0') ?? 0,
          discountPercent: item['discountPercent'] == null ? null : (double.tryParse(item['discountPercent']?.toString() ?? '0') ?? 0),
        );
      }).toList();

      final subtotal = double.tryParse(data['summary']?['subtotal']?.toString() ?? '0') ?? 0;
      final discount = double.tryParse(data['summary']?['discount']?.toString() ?? '0') ?? 0;
      final total = double.tryParse(data['summary']?['total']?.toString() ?? '0') ?? 0;

      state = CartState(
        items: items,
        subtotal: subtotal,
        discount: discount,
        total: total,
        loading: false,
        error: null,
      );
    } on DioException catch (error) {
      state = CartState(
        items: const [],
        subtotal: 0,
        discount: 0,
        total: 0,
        loading: false,
        error: error.message ?? 'Unable to load cart',
      );
    } catch (error) {
      state = CartState(
        items: const [],
        subtotal: 0,
        discount: 0,
        total: 0,
        loading: false,
        error: error.toString(),
      );
    }
  }

  Future<void> removeItem(String productId) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      throw StateError('Sign in is required to update your cart.');
    }
    await _dio.delete(
      '/cart/items/$productId',
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    await loadCart();
  }
}

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(cartProvider.notifier).loadCart());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cartProvider);

    if (state.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cart')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: 12),
              Text(state.error!),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.read(cartProvider.notifier).loadCart(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cart')),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.shopping_cart_outlined, size: 52),
              SizedBox(height: 12),
              Text('Your cart is empty'),
              SizedBox(height: 6),
              Text('Add bottled water and bulk packs to begin'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: state.items.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (_, index) {
                  final item = state.items[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.local_drink_rounded),
                    ),
                    title: Text(item.name),
                    subtitle: Text('Qty ${item.quantity} • SAR ${item.unitPrice.toStringAsFixed(2)}'),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('SAR ${(item.unitPrice * item.quantity).toStringAsFixed(2)}'),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Remove item',
                          onPressed: () async {
                            try {
                              await ref.read(cartProvider.notifier).removeItem(item.productId);
                            } catch (error) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(error.toString())),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal'),
                        Text('SAR ${state.subtotal.toStringAsFixed(2)}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Discount'),
                        Text('-SAR ${state.discount.toStringAsFixed(2)}'),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('SAR ${state.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => context.go('/checkout'),
                        child: const Text('Proceed to checkout'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
