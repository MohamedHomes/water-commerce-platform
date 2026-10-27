import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import 'api_config.dart';
import 'customer_ui.dart';
import 'localization.dart';

class FavoriteProduct {
  const FavoriteProduct({
    required this.id,
    required this.name,
    required this.price,
    this.nameAr,
    this.imageUrl,
    this.quantity = 0,
    this.availability = 'unavailable',
  });

  final String id;
  final String name;
  final String? nameAr;
  final String? imageUrl;
  final double price;
  final int quantity;
  final String availability;

  factory FavoriteProduct.fromJson(Map<String, dynamic> json) =>
      FavoriteProduct(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        nameAr: json['nameAr']?.toString(),
        imageUrl: json['imageUrl']?.toString(),
        price: (json['price'] as num?)?.toDouble() ?? 0,
        quantity: (json['quantity'] as num?)?.toInt() ?? 0,
        availability: json['availability']?.toString() ?? 'unavailable',
      );

  String displayName(String languageCode) =>
      languageCode == 'ar' && nameAr?.isNotEmpty == true ? nameAr! : name;
}

class FavoritesState {
  const FavoritesState({
    this.items = const [],
    this.loading = false,
    this.error,
  });

  final List<FavoriteProduct> items;
  final bool loading;
  final Object? error;

  bool contains(String productId) =>
      items.any((product) => product.id == productId);
}

final favoritesProvider =
    StateNotifierProvider<FavoritesController, FavoritesState>(
  (ref) => FavoritesController(),
);

class FavoritesController extends StateNotifier<FavoritesState> {
  FavoritesController({
    Dio? dio,
    FlutterSecureStorage? storage,
  })  : _dio = dio ?? Dio(BaseOptions(baseUrl: apiBaseUrl)),
        _storage = storage ?? const FlutterSecureStorage(),
        super(const FavoritesState());

  final Dio _dio;
  final FlutterSecureStorage _storage;

  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }

  Future<Options> _authorizedOptions() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      throw StateError('Sign in is required to manage favorites.');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<void> load() async {
    state = FavoritesState(items: state.items, loading: true);
    try {
      final response = await _dio.get(
        '/catalog/favorites',
        options: await _authorizedOptions(),
      );
      final items = (response.data['items'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(FavoriteProduct.fromJson)
          .toList();
      state = FavoritesState(items: items);
    } catch (error) {
      state = FavoritesState(items: state.items, error: error);
    }
  }

  Future<void> toggle(String productId) async {
    final options = await _authorizedOptions();
    if (state.contains(productId)) {
      await _dio.delete('/catalog/favorites/$productId', options: options);
    } else {
      await _dio.put('/catalog/favorites/$productId', options: options);
    }
    await load();
    if (state.error != null) {
      throw state.error!;
    }
  }
}

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class FavoriteToggleButton extends ConsumerStatefulWidget {
  const FavoriteToggleButton({
    required this.productId,
    required this.onError,
    super.key,
  });

  final String productId;
  final void Function(Object error) onError;

  @override
  ConsumerState<FavoriteToggleButton> createState() =>
      _FavoriteToggleButtonState();
}

class _FavoriteToggleButtonState extends ConsumerState<FavoriteToggleButton> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final isFavorite = ref.watch(favoritesProvider).contains(widget.productId);
    return IconButton.filledTonal(
      tooltip: localized(
        context,
        isFavorite ? 'Remove favorite' : 'Add to favorites',
      ),
      onPressed: _busy
          ? null
          : () async {
              setState(() => _busy = true);
              try {
                await ref
                    .read(favoritesProvider.notifier)
                    .toggle(widget.productId);
              } catch (error) {
                widget.onError(error);
              } finally {
                if (mounted) setState(() => _busy = false);
              }
            },
      icon: _busy
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
            ),
    );
  }
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(favoritesProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(favoritesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(localized(context, 'Favorites')),
        actions: const [LanguageSwitch(compact: true)],
      ),
      body: state.loading && state.items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && state.items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(localizedError(context, state.error!)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () =>
                            ref.read(favoritesProvider.notifier).load(),
                        child: Text(localized(context, 'Retry')),
                      ),
                    ],
                  ),
                )
              : state.items.isEmpty
                  ? Center(child: Text(localized(context, 'No favorites yet.')))
                  : RefreshIndicator(
                      onRefresh: () =>
                          ref.read(favoritesProvider.notifier).load(),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: state.items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final product = state.items[index];
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: SizedBox(
                                width: 64,
                                height: 64,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: ProductArtwork(
                                      imageUrl: product.imageUrl),
                                ),
                              ),
                              title: Text(product.displayName(
                                Localizations.localeOf(context).languageCode,
                              )),
                              subtitle: Text(
                                  'SAR ${product.price.toStringAsFixed(2)}'),
                              onTap: () => context.push(
                                '/product/${product.id}',
                              ),
                              trailing: IconButton(
                                tooltip: localized(context, 'Remove favorite'),
                                onPressed: () async {
                                  try {
                                    await ref
                                        .read(favoritesProvider.notifier)
                                        .toggle(product.id);
                                  } catch (error) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              localizedError(context, error)),
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.favorite,
                                    color: Colors.redAccent),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
