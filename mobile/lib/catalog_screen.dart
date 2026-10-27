import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'api_config.dart';
import 'cart_screen.dart';
import 'customer_ui.dart';
import 'localization.dart';

class CatalogProduct {
  const CatalogProduct({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    required this.availability,
    this.nameAr,
    this.description,
    this.descriptionAr,
    this.imageUrl,
    this.compareAtPrice,
    this.discountPercent,
    this.packageSize,
    this.volume,
  });

  final String id;
  final String name;
  final String? nameAr;
  final String? description;
  final String? descriptionAr;
  final String? imageUrl;
  final double? compareAtPrice;
  final double? discountPercent;
  final String? packageSize;
  final String? volume;
  final double price;
  final int quantity;
  final String availability;

  factory CatalogProduct.fromJson(Map<String, dynamic> json) {
    return CatalogProduct(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nameAr: json['nameAr']?.toString(),
      description: json['description']?.toString(),
      descriptionAr: json['descriptionAr']?.toString(),
      price: _number(json['price']),
      quantity: _number(json['quantity']).toInt(),
      availability: json['availability']?.toString() ?? 'unavailable',
      imageUrl: json['imageUrl']?.toString(),
      compareAtPrice: json['compareAtPrice'] == null
          ? null
          : _number(json['compareAtPrice']),
      discountPercent: json['discountPercent'] == null
          ? null
          : _number(json['discountPercent']),
      packageSize: json['packageSize']?.toString(),
      volume: json['volume']?.toString(),
    );
  }

  static double _number(Object? value) => value is num
      ? value.toDouble()
      : double.tryParse(value?.toString() ?? '') ?? 0;

  String displayName(String languageCode) =>
      languageCode == 'ar' && nameAr?.isNotEmpty == true ? nameAr! : name;

  String? displayDescription(String languageCode) =>
      languageCode == 'ar' && descriptionAr?.isNotEmpty == true
          ? descriptionAr
          : description;
}

class CatalogCategory {
  const CatalogCategory({
    required this.id,
    required this.name,
    this.nameAr,
  });

  final String id;
  final String name;
  final String? nameAr;

  factory CatalogCategory.fromJson(Map<String, dynamic> json) {
    return CatalogCategory(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nameAr: json['nameAr']?.toString(),
    );
  }

  String displayName(String languageCode) =>
      languageCode == 'ar' && nameAr?.isNotEmpty == true ? nameAr! : name;
}

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({this.initialCategoryId, super.key});

  final String? initialCategoryId;

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final Dio _dio = Dio(BaseOptions(baseUrl: apiBaseUrl));
  final TextEditingController _searchController = TextEditingController();
  List<CatalogProduct> _products = [];
  List<CatalogCategory> _categories = [];
  String? _categoryId;
  String? _error;
  int _page = 1;
  int _totalPages = 1;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategoryId;
    Future.microtask(() {
      _loadCategories();
      _loadProducts(reset: true);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _dio.close();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final response = await _dio.get('/catalog/categories');
      final data = response.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _categories = (data['items'] as List? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(CatalogCategory.fromJson)
            .toList();
      });
    } catch (error) {
      if (mounted) setState(() => _error = localizedError(context, error));
    }
  }

  Future<void> _loadProducts({required bool reset}) async {
    if (_loadingMore) return;
    final requestedPage = reset ? 1 : _page + 1;
    setState(() {
      if (reset) {
        _loading = true;
      } else {
        _loadingMore = true;
      }
      _error = null;
    });
    try {
      final response = await _dio.get(
        '/catalog/products',
        queryParameters: {
          'page': requestedPage,
          'limit': 20,
          'sort': 'newest',
          if (_searchController.text.trim().isNotEmpty)
            'q': _searchController.text.trim(),
          if (_categoryId != null) 'categoryId': _categoryId,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final fetched = (data['items'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(CatalogProduct.fromJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _products = reset ? fetched : [..._products, ...fetched];
        _page = requestedPage;
        _totalPages = (data['totalPages'] as num?)?.toInt() ?? 1;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = localizedError(context, error);
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final availableWidth = MediaQuery.sizeOf(context).width - 44;
    final cardWidth = (availableWidth / 2).clamp(132.0, 280.0);
    return Scaffold(
      appBar: AppBar(
        title: Text(localized(context, 'Catalog')),
        actions: const [LanguageSwitch(compact: true)],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _loadProducts(reset: true),
                decoration: InputDecoration(
                  hintText: localized(context, 'Search products'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    tooltip: localized(context, 'Search products'),
                    onPressed: () => _loadProducts(reset: true),
                    icon: const Icon(Icons.arrow_forward_rounded),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: FilterChip(
                      selected: _categoryId == null,
                      label: Text(localized(context, 'All categories')),
                      onSelected: (_) {
                        setState(() => _categoryId = null);
                        _loadProducts(reset: true);
                      },
                    ),
                  ),
                  ..._categories.map(
                    (category) => Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: FilterChip(
                        selected: _categoryId == category.id,
                        label: Text(category.displayName(languageCode)),
                        onSelected: (_) {
                          setState(() => _categoryId = category.id);
                          _loadProducts(reset: true);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && _products.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.wifi_off_rounded, size: 40),
                                const SizedBox(height: 12),
                                Text(localized(
                                    context, 'Could not load catalog.')),
                                const SizedBox(height: 12),
                                FilledButton(
                                  onPressed: () {
                                    _loadCategories();
                                    _loadProducts(reset: true);
                                  },
                                  child: Text(localized(context, 'Retry')),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _products.isEmpty
                          ? Center(
                              child: Text(
                                  localized(context, 'No products found.')),
                            )
                          : RefreshIndicator(
                              onRefresh: () => _loadProducts(reset: true),
                              child: ListView(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 8, 16, 24),
                                children: [
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: _products
                                        .map(
                                          (product) => SizedBox(
                                            width: cardWidth,
                                            child: CatalogProductCard(
                                              product: product,
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                  if (_page < _totalPages)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 18),
                                      child: Center(
                                        child: _loadingMore
                                            ? const CircularProgressIndicator()
                                            : OutlinedButton(
                                                onPressed: () =>
                                                    _loadProducts(reset: false),
                                                child: Text(
                                                  localized(
                                                      context, 'Load more'),
                                                ),
                                              ),
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

class CatalogProductCard extends ConsumerStatefulWidget {
  const CatalogProductCard({required this.product, super.key});

  final CatalogProduct product;

  @override
  ConsumerState<CatalogProductCard> createState() => _CatalogProductCardState();
}

class _CatalogProductCardState extends ConsumerState<CatalogProductCard> {
  bool _adding = false;

  Future<void> _addToCart() async {
    setState(() => _adding = true);
    try {
      await ref.read(cartProvider.notifier).addItem(widget.product.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localized(context, 'Added to cart.'))),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedError(context, error))),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    final product = widget.product;
    final name = product.displayName(languageCode);
    final inStock = product.quantity > 0 &&
        product.availability != 'out_of_stock' &&
        product.availability != 'unavailable';
    final hasDiscount = product.compareAtPrice != null &&
        product.compareAtPrice! > product.price;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 1.45,
                child: InkWell(
                  onTap: () => context.push(
                    '/product/${product.id}',
                    extra: product,
                  ),
                  child: ProductArtwork(imageUrl: product.imageUrl),
                ),
              ),
              if (hasDiscount)
                PositionedDirectional(
                  top: 8,
                  start: 8,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      child: Text(
                        localized(context, 'A discount is available'),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onErrorContainer,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 11, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: () => context.push(
                    '/product/${product.id}',
                    extra: product,
                  ),
                  child: Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  localizedStatus(context, product.availability),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: inStock
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).colorScheme.error,
                      ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'SAR ${product.price.toStringAsFixed(2)}',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (hasDiscount)
                      Text(
                        'SAR ${product.compareAtPrice!.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              decoration: TextDecoration.lineThrough,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: !inStock || _adding ? null : _addToCart,
                  child: _adding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(localized(context, 'Add to cart')),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({
    required this.productId,
    this.initialProduct,
    super.key,
  });

  final String productId;
  final CatalogProduct? initialProduct;

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  late final Dio _dio = Dio(BaseOptions(baseUrl: apiBaseUrl));
  CatalogProduct? _product;
  bool _loading = true;
  bool _adding = false;
  int _quantity = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _product = widget.initialProduct;
    if (_product == null) {
      _loadProduct();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    setState(() => _loading = true);
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/catalog/products/${widget.productId}',
      );
      if (!mounted) return;
      setState(() {
        _product = CatalogProduct.fromJson(response.data ?? {});
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = localizedError(context, error);
      });
    }
  }

  Future<void> _addToCart() async {
    final product = _product;
    if (product == null || _adding) return;
    setState(() => _adding = true);
    try {
      await ref
          .read(cartProvider.notifier)
          .addItem(product.id, quantity: _quantity);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localized(context, 'Added to cart.'))),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedError(context, error))),
        );
      }
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    final languageCode = Localizations.localeOf(context).languageCode;
    final inStock = product != null &&
        product.quantity > 0 &&
        product.availability != 'out_of_stock' &&
        product.availability != 'unavailable';
    return Scaffold(
      appBar: AppBar(
        title: Text(localized(context, 'Product details')),
        actions: const [LanguageSwitch(compact: true)],
      ),
      body: _loading && product == null
          ? const Center(child: CircularProgressIndicator())
          : product == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error ??
                          localized(context, 'Could not load catalog.')),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _loadProduct,
                        child: Text(localized(context, 'Retry')),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: AspectRatio(
                        aspectRatio: 1.15,
                        child: ProductArtwork(
                          imageUrl: product.imageUrl,
                          iconSize: 64,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      product.displayName(languageCode),
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                    if (product.packageSize?.isNotEmpty == true ||
                        product.volume?.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(
                        [product.packageSize, product.volume]
                            .whereType<String>()
                            .where((value) => value.isNotEmpty)
                            .toSet()
                            .join(' · '),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'SAR ${product.price.toStringAsFixed(2)}',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (product.compareAtPrice != null &&
                            product.compareAtPrice! > product.price)
                          Text(
                            'SAR ${product.compareAtPrice!.toStringAsFixed(2)}',
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      decoration: TextDecoration.lineThrough,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Chip(
                      avatar: Icon(
                        inStock
                            ? Icons.check_circle_outline_rounded
                            : Icons.remove_circle_outline_rounded,
                        size: 18,
                      ),
                      label: Text(
                        inStock
                            ? localized(context, 'In stock')
                            : localizedStatus(context, product.availability),
                      ),
                    ),
                    if (product.displayDescription(languageCode)?.isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 12),
                      Text(
                        product.displayDescription(languageCode)!,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      localized(context, 'Available quantity'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton.outlined(
                          onPressed: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                          icon: const Icon(Icons.remove_rounded),
                        ),
                        SizedBox(
                          width: 52,
                          child: Center(
                            child: Text(
                              '$_quantity',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                        ),
                        IconButton.outlined(
                          onPressed: inStock && _quantity < product.quantity
                              ? () => setState(() => _quantity++)
                              : null,
                          icon: const Icon(Icons.add_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
      bottomNavigationBar: product == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: FilledButton.icon(
                  onPressed: inStock && !_adding ? _addToCart : null,
                  icon: _adding
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_shopping_cart_rounded),
                  label: Text(
                    localized(context, 'Add {quantity} to cart', {
                      'quantity': _quantity,
                    }),
                  ),
                ),
              ),
            ),
    );
  }
}
