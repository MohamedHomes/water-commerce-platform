import 'package:aquaflow_mobile/catalog_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('catalog products prefer Arabic fields and fall back to English', () {
    final product = CatalogProduct.fromJson({
      'id': 'prod-1',
      'name': 'Mineral Water',
      'nameAr': 'مياه معدنية',
      'description': 'Still mineral water',
      'descriptionAr': 'مياه معدنية نقية',
      'price': 4.5,
      'compareAtPrice': 5.5,
      'discountPercent': 18,
      'imageUrl': 'https://cdn.aquaflow.local/products/water.png',
      'packageSize': '12 pack',
      'volume': '330 ml',
      'quantity': 12,
      'availability': 'in_stock',
    });

    expect(product.displayName('ar'), 'مياه معدنية');
    expect(product.displayDescription('ar'), 'مياه معدنية نقية');
    expect(product.displayName('en'), 'Mineral Water');
    expect(product.imageUrl, 'https://cdn.aquaflow.local/products/water.png');
    expect(product.compareAtPrice, 5.5);
    expect(product.discountPercent, 18);
    expect(product.quantity, 12);
  });

  test('catalog model tolerates legacy API records without Arabic fields', () {
    final product = CatalogProduct.fromJson({
      'id': 'legacy-product',
      'name': 'Legacy Water',
      'price': 3,
      'quantity': 0,
      'availability': 'out_of_stock',
    });

    expect(product.displayName('ar'), 'Legacy Water');
    expect(product.displayDescription('ar'), isNull);
  });
}
