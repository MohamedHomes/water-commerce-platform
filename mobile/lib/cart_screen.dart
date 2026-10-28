import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import 'customer_api.dart';
import 'customer_ui.dart';
import 'localization.dart';

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
    this.nameAr,
    required this.quantity,
    required this.unitPrice,
    this.discountPercent,
    this.lineTotal,
    this.imageUrl,
    this.compareAtPrice,
  });

  final String productId;
  final String name;
  final String? nameAr;
  final int quantity;
  final double unitPrice;
  final double? discountPercent;
  final double? lineTotal;
  final String? imageUrl;
  final double? compareAtPrice;
}

final cartProvider = StateNotifierProvider<CartController, CartState>((ref) {
  return CartController();
});

class CartController extends StateNotifier<CartState> {
  CartController({
    Dio? dio,
    FlutterSecureStorage? storage,
    CartState? initialState,
  })  : _dio = dio ?? CustomerApi.createDio(),
        _storage = storage ?? const FlutterSecureStorage(),
        super(initialState ?? CartState.initial());

  final Dio _dio;
  final FlutterSecureStorage _storage;

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
      final response = await _dio.get('/cart',
          options: Options(headers: {'Authorization': 'Bearer $token'}));
      final data = response.data as Map<String, dynamic>;
      final items = (data['items'] as List? ?? []).map<CartItem>((entry) {
        final item = entry as Map<String, dynamic>;
        return CartItem(
          productId: item['productId']?.toString() ?? '',
          name: item['name']?.toString() ?? 'Product',
          nameAr: item['nameAr']?.toString(),
          quantity: int.tryParse(item['quantity']?.toString() ?? '0') ?? 0,
          unitPrice: double.tryParse(item['unitPrice']?.toString() ?? '0') ?? 0,
          discountPercent: item['discountPercent'] == null
              ? null
              : (double.tryParse(item['discountPercent']?.toString() ?? '0') ??
                  0),
          lineTotal: item['lineTotal'] == null
              ? null
              : double.tryParse(item['lineTotal'].toString()),
          imageUrl: item['imageUrl']?.toString(),
          compareAtPrice: item['compareAtPrice'] == null
              ? null
              : double.tryParse(item['compareAtPrice'].toString()),
        );
      }).toList();

      final subtotal =
          double.tryParse(data['summary']?['subtotal']?.toString() ?? '0') ?? 0;
      final discount =
          double.tryParse(data['summary']?['discount']?.toString() ?? '0') ?? 0;
      final total =
          double.tryParse(data['summary']?['total']?.toString() ?? '0') ?? 0;

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
        items: state.items,
        subtotal: state.subtotal,
        discount: state.discount,
        total: state.total,
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

  Future<void> updateItemQuantity(String productId, int quantity) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      throw StateError('Sign in is required to update your cart.');
    }
    await _dio.patch(
      '/cart/items/$productId',
      data: {'quantity': quantity},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    await loadCart();
  }

  Future<void> addItem(String productId, {int quantity = 1}) async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      throw StateError('Sign in is required to update your cart.');
    }
    await _dio.post(
      '/cart/items',
      data: {'productId': productId, 'quantity': quantity},
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
    await loadCart();
  }
}

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({this.autoLoad = true, super.key});

  final bool autoLoad;

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoLoad) {
      Future.microtask(() => ref.read(cartProvider.notifier).loadCart());
    }
  }

  final Set<String> _updatingProductIds = {};

  Future<void> _updateQuantity(CartItem item, int quantity) async {
    if (_updatingProductIds.contains(item.productId)) return;
    setState(() => _updatingProductIds.add(item.productId));
    try {
      await ref
          .read(cartProvider.notifier)
          .updateItemQuantity(item.productId, quantity);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedError(context, error))),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingProductIds.remove(item.productId));
    }
  }

  Future<void> _removeItem(CartItem item) async {
    if (_updatingProductIds.contains(item.productId)) return;
    setState(() => _updatingProductIds.add(item.productId));
    try {
      await ref.read(cartProvider.notifier).removeItem(item.productId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedError(context, error))),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingProductIds.remove(item.productId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cartProvider);

    if (state.loading && state.items.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localized(context, 'Cart')),
          actions: const [LanguageSwitch(compact: true)],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 42),
              const SizedBox(height: 12),
              Text(localizedError(context, state.error!)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.read(cartProvider.notifier).loadCart(),
                child: Text(localized(context, 'Retry')),
              ),
            ],
          ),
        ),
      );
    }

    if (state.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(localized(context, 'Cart')),
          actions: const [LanguageSwitch(compact: true)],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.shopping_bag_outlined,
                size: 56,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                localized(context, 'Your cart is empty'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  localized(
                      context, 'Add bottled water and bulk packs to begin'),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => context.go('/catalog'),
                icon: const Icon(Icons.storefront_outlined),
                label: Text(localized(context, 'Browse products')),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(localized(context, 'Cart')),
        actions: const [LanguageSwitch(compact: true)],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (state.loading) const LinearProgressIndicator(minHeight: 2),
            if (state.error != null)
              MaterialBanner(
                content: Text(localizedError(context, state.error!)),
                actions: [
                  TextButton(
                    onPressed: () => ref.read(cartProvider.notifier).loadCart(),
                    child: Text(localized(context, 'Retry')),
                  ),
                ],
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  Text(
                    localized(context, '{count} items', {
                      'count': state.items.length,
                    }),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  for (final item in state.items) ...[
                    CartItemCard(
                      item: item,
                      busy: _updatingProductIds.contains(item.productId),
                      onDecrease: item.quantity > 1
                          ? () => _updateQuantity(item, item.quantity - 1)
                          : null,
                      onIncrease: () =>
                          _updateQuantity(item, item.quantity + 1),
                      onRemove: () => _removeItem(item),
                    ),
                    const SizedBox(height: 12),
                  ],
                  CartTotalsCard(state: state),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          child: FilledButton(
            onPressed: state.items.isEmpty || state.loading
                ? null
                : () => context.go('/checkout'),
            child: Text(localized(context, 'Proceed to checkout')),
          ),
        ),
      ),
    );
  }
}

class CartItemCard extends StatelessWidget {
  const CartItemCard({
    required this.item,
    required this.busy,
    required this.onDecrease,
    required this.onIncrease,
    required this.onRemove,
    super.key,
  });

  final CartItem item;
  final bool busy;
  final VoidCallback? onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final name =
        isArabic && item.nameAr?.isNotEmpty == true ? item.nameAr! : item.name;
    final lineTotal = item.lineTotal ?? item.unitPrice * item.quantity;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: ProductArtwork(
                      imageUrl: item.imageUrl,
                      iconSize: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        localized(context, 'SAR {price} each', {
                          'price': item.unitPrice.toStringAsFixed(2),
                        }),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      if (item.compareAtPrice != null &&
                          item.compareAtPrice! > item.unitPrice)
                        Text(
                          'SAR ${item.compareAtPrice!.toStringAsFixed(2)}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    decoration: TextDecoration.lineThrough,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: busy ? null : onRemove,
                  tooltip: localized(context, 'Remove item'),
                  icon: const Icon(Icons.delete_outline_rounded),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              children: [
                _CartQuantityControl(
                  itemId: item.productId,
                  quantity: item.quantity,
                  busy: busy,
                  onDecrease: onDecrease,
                  onIncrease: onIncrease,
                ),
                Text(
                  'SAR ${lineTotal.toStringAsFixed(2)}',
                  key: Key('cart-line-total-${item.productId}'),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CartQuantityControl extends StatelessWidget {
  const _CartQuantityControl({
    required this.itemId,
    required this.quantity,
    required this.busy,
    required this.onDecrease,
    required this.onIncrease,
  });

  final String itemId;
  final int quantity;
  final bool busy;
  final VoidCallback? onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              key: Key('cart-decrease-$itemId'),
              onPressed: busy ? null : onDecrease,
              tooltip: localized(context, 'Decrease quantity'),
              icon: const Icon(Icons.remove_rounded),
              visualDensity: VisualDensity.compact,
            ),
            SizedBox(
              width: 28,
              child: Center(
                child: Text(
                  '$quantity',
                  key: Key('cart-quantity-$itemId'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            IconButton(
              key: Key('cart-increase-$itemId'),
              onPressed: busy ? null : onIncrease,
              tooltip: localized(context, 'Increase quantity'),
              icon: const Icon(Icons.add_rounded),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      );
}

class CartTotalsCard extends StatelessWidget {
  const CartTotalsCard({required this.state, super.key});

  final CartState state;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _CartTotalRow(
                label: localized(context, 'Subtotal'),
                amount: state.subtotal,
              ),
              const SizedBox(height: 10),
              _CartTotalRow(
                label: localized(context, 'Discount'),
                amount: state.discount,
                negative: true,
              ),
              const Divider(height: 24),
              _CartTotalRow(
                label: localized(context, 'Total'),
                amount: state.total,
                emphasize: true,
              ),
            ],
          ),
        ),
      );
}

class _CartTotalRow extends StatelessWidget {
  const _CartTotalRow({
    required this.label,
    required this.amount,
    this.negative = false,
    this.emphasize = false,
  });

  final String label;
  final double amount;
  final bool negative;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            )
        : Theme.of(context).textTheme.bodyMedium;
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        const SizedBox(width: 12),
        Text(
          '${negative ? '-' : ''}SAR ${amount.toStringAsFixed(2)}',
          textAlign: TextAlign.end,
          style: style,
        ),
      ],
    );
  }
}
