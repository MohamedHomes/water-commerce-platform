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
      'quantity': 12,
      'availability': 'in_stock',
    });

    expect(product.displayName('ar'), 'مياه معدنية');
    expect(product.displayDescription('ar'), 'مياه معدنية نقية');
    expect(product.displayName('en'), 'Mineral Water');
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
