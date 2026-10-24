import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_config.dart';
import 'cart_screen.dart';
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
  });

  final String id;
  final String name;
  final String? nameAr;
  final String? description;
  final String? descriptionAr;
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
      price: (json['price'] as num?)?.toDouble() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      availability: json['availability']?.toString() ?? 'unavailable',
    );
  }

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
  const CatalogScreen({super.key});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final Dio _dio = Dio(BaseOptions(baseUrl: apiBaseUrl));
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _addingProductIds = {};
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

  Future<void> _addToCart(CatalogProduct product) async {
    setState(() => _addingProductIds.add(product.id));
    try {
      await ref.read(cartProvider.notifier).addItem(product.id);
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
      if (mounted) setState(() => _addingProductIds.remove(product.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageCode = Localizations.localeOf(context).languageCode;
    return Scaffold(
      appBar: AppBar(
        title: Text(localized(context, 'Catalog')),
        actions: const [LanguageSwitch()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _loadProducts(reset: true),
                  decoration: InputDecoration(
                    labelText: localized(context, 'Search products'),
                    suffixIcon: IconButton(
                      tooltip: localized(context, 'Search products'),
                      onPressed: () => _loadProducts(reset: true),
                      icon: const Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: _categoryId,
                  decoration: InputDecoration(
                    labelText: localized(context, 'Category'),
                  ),
                  items: [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text(localized(context, 'All categories')),
                    ),
                    ..._categories.map((category) => DropdownMenuItem<String?>(
                          value: category.id,
                          child: Text(category.displayName(languageCode)),
                        )),
                  ],
                  onChanged: (value) {
                    setState(() => _categoryId = value);
                    _loadProducts(reset: true);
                  },
                ),
              ],
            ),
          ),
          if (_loading) const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null && _products.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(localized(context, 'Could not load catalog.')),
                    const SizedBox(height: 8),
                    Text(_error!),
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
          else if (_products.isEmpty)
            Expanded(
              child: Center(child: Text(localized(context, 'No products found.'))),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _products.length + (_page < _totalPages ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _products.length) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: _loadingMore
                            ? const CircularProgressIndicator()
                            : OutlinedButton(
                                onPressed: () => _loadProducts(reset: false),
                                child: Text(localized(context, 'Load more')),
                              ),
                      ),
                    );
                  }
                  final product = _products[index];
                  final name = product.displayName(languageCode);
                  final description = product.displayDescription(languageCode);
                  final inStock = product.quantity > 0 &&
                      product.availability != 'out_of_stock' &&
                      product.availability != 'unavailable';
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.water_drop_outlined),
                      ),
                      title: Text(name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (description?.isNotEmpty == true) Text(description!),
                          Text('SAR ${product.price.toStringAsFixed(2)}'),
                          Text(localizedStatus(context, product.availability)),
                        ],
                      ),
                      trailing: IconButton.filledTonal(
                        tooltip: localized(context, 'Add to cart'),
                        onPressed: !inStock || _addingProductIds.contains(product.id)
                            ? null
                            : () => _addToCart(product),
                        icon: _addingProductIds.contains(product.id)
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.add_shopping_cart),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
