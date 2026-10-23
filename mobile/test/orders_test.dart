import 'package:aquaflow_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses immutable order summary and address snapshots', () {
    final order = OrderRecord.fromJson({
      'id': 'order-id',
      'status': 'payment_pending',
      'paymentMethod': 'card',
      'deliveryOption': 'standard',
      'address': {
        'id': 'address-id',
        'label': 'Home',
        'recipientName': 'Customer',
        'phone': '+966500000000',
        'city': 'Riyadh',
        'district': 'Central',
        'street': 'Main',
        'building': '12',
      },
      'items': [
        {
          'productId': 'prod-1',
          'name': 'Mineral water',
          'quantity': 2,
          'unitPrice': 5.25,
          'lineTotal': 10.5,
        },
      ],
      'summary': {'total': 15.5, 'currency': 'SAR'},
      'createdAt': '2026-10-23T14:00:00.000Z',
    });

    expect(order.status, 'payment_pending');
    expect(order.address.city, 'Riyadh');
    expect(order.items.single.quantity, 2);
    expect(order.total, 15.5);
    expect(order.currency, 'SAR');
  });

  test('parses payment intent without exposing card data', () {
    final intent = PaymentIntent.fromJson({
      'id': 'payment-id',
      'provider': 'test',
      'status': 'pending',
      'amount': 12.5,
      'currency': 'SAR',
      'checkoutUrl': null,
    });

    expect(intent.provider, 'test');
    expect(intent.status, 'pending');
    expect(intent.checkoutUrl, isNull);
  });
}
