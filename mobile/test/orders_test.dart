import 'package:aquaflow_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses immutable order summary and address snapshots', () {
    final order = OrderRecord.fromJson({
      'id': 'order-id',
      'status': 'placed',
      'deliveryStatus': 'delivered',
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

    expect(order.status, 'placed');
    expect(order.deliveryStatus, 'delivered');
    expect(order.address.city, 'Riyadh');
    expect(order.items.single.quantity, 2);
    expect(order.total, 15.5);
    expect(order.currency, 'SAR');
    expect(customerOrderDisplayStatus(order), 'delivered');
  });

  test('uses the persisted delivery lifecycle status for customer display', () {
    final order = OrderRecord.fromJson({
      'id': 'order-id',
      'status': 'placed',
      'deliveryStatus': 'picked_up',
      'paymentMethod': 'cash',
      'deliveryOption': 'standard',
      'address': <String, dynamic>{},
      'items': [],
      'summary': {'total': 4.5, 'currency': 'SAR'},
      'createdAt': '2026-10-23T14:00:00.000Z',
    });

    expect(customerOrderDisplayStatus(order), 'picked_up');
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

  test('parses server-calculated promotion discounts in checkout summary', () {
    final summary = CheckoutSummary.fromJson({
      'checkoutId': 'checkout-id',
      'summary': {
        'subtotal': 20,
        'discount': 2,
        'promotionCode': 'SAVE10',
        'deliveryFee': 3,
        'serviceFee': 0,
        'total': 21,
        'currency': 'SAR',
      },
    });

    expect(summary.discount, 2);
    expect(summary.promotionCode, 'SAVE10');
    expect(summary.total, 21);
  });

  test('parses an in-app notification with read state', () {
    final notification = CustomerNotification.fromJson({
      'id': 'notification-id',
      'type': 'order_placed',
      'title': 'Order placed',
      'body': 'Your order has been placed.',
      'data': {'orderId': 'order-id'},
      'readAt': null,
      'createdAt': '2026-10-23T15:00:00.000Z',
    });

    expect(notification.type, 'order_placed');
    expect(notification.title, 'Order placed');
    expect(notification.isRead, isFalse);
  });
}
