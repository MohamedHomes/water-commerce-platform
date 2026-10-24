import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _translations = <String, String>{
  'Sign out': 'تسجيل الخروج',
  'Home': 'المنزل',
  'Customer': 'العميل',
  'Product': 'المنتج',
  'Catalog': 'الكتالوج',
  'Browse and add products to your cart': 'تصفح المنتجات وأضفها إلى سلتك',
  'Search products': 'ابحث عن المنتجات',
  'No products found.': 'لم يتم العثور على منتجات.',
  'Add to cart': 'أضف إلى السلة',
  'Added to cart.': 'تمت إضافة المنتج إلى السلة.',
  'Loading catalog...': 'جارٍ تحميل الكتالوج…',
  'All categories': 'جميع الفئات',
  'Load more': 'تحميل المزيد',
  'Could not load catalog.': 'تعذر تحميل الكتالوج.',
  'Fresh water, delivered with care': 'مياه نقية تصلك بعناية',
  'Bottled Water': 'مياه معبأة',
  'Bulk Packs': 'عبوات كبيرة',
  'Customer Care': 'خدمة العملاء',
  'Addresses': 'العناوين',
  'Manage delivery addresses and defaults': 'إدارة عناوين التوصيل والعنوان الافتراضي',
  'Checkout': 'إتمام الطلب',
  'Review delivery and payment details': 'مراجعة تفاصيل التوصيل والدفع',
  'Cart': 'السلة',
  'Review order total before checkout': 'مراجعة إجمالي الطلب قبل إتمامه',
  'Orders': 'الطلبات',
  'View, cancel, or reorder your purchases': 'عرض مشترياتك أو إلغاؤها أو إعادة طلبها',
  'Notifications': 'الإشعارات',
  'Order and payment updates': 'تحديثات الطلبات والمدفوعات',
  'Sign in': 'تسجيل الدخول',
  'Create account': 'إنشاء حساب',
  'I already have an account': 'لدي حساب بالفعل',
  'Create an account': 'إنشاء حساب',
  'First name': 'الاسم الأول',
  'Last name': 'اسم العائلة',
  'Email': 'البريد الإلكتروني',
  'Password': 'كلمة المرور',
  'Enter your first name': 'أدخل اسمك الأول',
  'Enter your last name': 'أدخل اسم العائلة',
  'Enter a valid email': 'أدخل بريداً إلكترونياً صحيحاً',
  'Password must be at least 8 characters': 'يجب ألا تقل كلمة المرور عن 8 أحرف',
  'Retry': 'إعادة المحاولة',
  'Too many requests': 'طلبات كثيرة جداً. يرجى المحاولة لاحقاً.',
  'No addresses yet. Add your first delivery address.': 'لا توجد عناوين بعد. أضف عنوان التوصيل الأول.',
  'Edit': 'تعديل',
  'Set default': 'تعيين كافتراضي',
  'Delete': 'حذف',
  'Could not update the default address.': 'تعذر تحديث العنوان الافتراضي.',
  'Could not delete the address.': 'تعذر حذف العنوان.',
  'Add address': 'إضافة عنوان',
  'Edit address': 'تعديل العنوان',
  'Label': 'التسمية',
  'Enter a label': 'أدخل تسمية للعنوان',
  'Recipient name': 'اسم المستلم',
  'Enter a recipient name': 'أدخل اسم المستلم',
  'Phone': 'رقم الهاتف',
  'Enter a valid phone number': 'أدخل رقم هاتف صحيحاً',
  'City': 'المدينة',
  'Select a configured city': 'اختر مدينة متاحة',
  'District': 'الحي',
  'Enter a district': 'أدخل الحي',
  'Street': 'الشارع',
  'Enter a street': 'أدخل الشارع',
  'Building': 'المبنى',
  'Enter a building': 'أدخل رقم المبنى',
  'Apartment': 'الشقة',
  'Floor': 'الطابق',
  'Notes': 'ملاحظات',
  'Set as default address': 'تعيين كعنوان افتراضي',
  'Save address': 'حفظ العنوان',
  'No saved addresses.': 'لا توجد عناوين محفوظة.',
  'Delivery address': 'عنوان التوصيل',
  'Choose an address': 'اختر عنواناً',
  'Delivery zone': 'منطقة التوصيل',
  'Choose a delivery zone': 'اختر منطقة التوصيل',
  'Delivery option': 'خيار التوصيل',
  'Payment method': 'طريقة الدفع',
  'Promotion code (optional)': 'رمز العرض (اختياري)',
  'Card payment processing is not available yet. The order will remain payment pending.': 'معالجة الدفع بالبطاقة غير متاحة حالياً. سيبقى الطلب بانتظار الدفع.',
  'Review your checkout before placing the order.': 'راجع تفاصيل طلبك قبل تأكيده.',
  'Standard': 'عادي',
  'Express': 'سريع',
  'Card': 'بطاقة',
  'Cash': 'نقداً',
  'Subtotal': 'المجموع الفرعي',
  'Promotion': 'العرض الترويجي',
  'Delivery fee': 'رسوم التوصيل',
  'Delivery': 'التوصيل',
  'Service fee': 'رسوم الخدمة',
  'Review order': 'مراجعة الطلب',
  'Place order': 'تأكيد الطلب',
  '{minutes} minutes': '{minutes} دقيقة',
  'Apt {apartment}': 'شقة {apartment}',
  'Payment could not be started: {error}': 'تعذر بدء الدفع: {error}',
  'Tracking code: {code}': 'رمز التتبع: {code}',
  'Estimated time: {minutes} minutes': 'الوقت المتوقع: {minutes} دقيقة',
  'Live driver tracking is not available yet.': 'تتبع السائق المباشر غير متاح حالياً.',
  'Delivery information is unavailable: {error}': 'معلومات التوصيل غير متاحة: {error}',
  'Review a delivered product': 'تقييم منتج تم توصيله',
  'Rating: {rating} / 5': 'التقييم: {rating} / 5',
  'Comment (optional)': 'تعليق (اختياري)',
  'Cancel': 'إلغاء',
  'Submit': 'إرسال',
  'Review submitted for moderation.': 'تم إرسال التقييم للمراجعة.',
  'Review could not be submitted: {error}': 'تعذر إرسال التقييم: {error}',
  'Order {id}': 'الطلب {id}',
  'Payment has not been processed.': 'لم تتم معالجة الدفع.',
  'Reorder': 'إعادة الطلب',
  'Review product': 'تقييم المنتج',
  'Payment in progress': 'الدفع قيد التنفيذ',
  'Starting...': 'جارٍ البدء…',
  'Start payment': 'بدء الدفع',
  'Payment intent created by {provider}; no payment was taken and no provider checkout is configured.': 'تم إنشاء طلب دفع عبر {provider}؛ لم يتم تحصيل أي مبلغ ولم يتم إعداد بوابة دفع.',
  'Payment intent created. Continue through the provider checkout.': 'تم إنشاء طلب الدفع. أكمل عبر صفحة مزود الدفع.',
  'Delivery {status}': 'حالة التوصيل: {status}',
  'You have no orders yet.': 'ليس لديك طلبات بعد.',
  'Could not update notification: {error}': 'تعذر تحديث الإشعار: {error}',
  'No notifications yet.': 'لا توجد إشعارات بعد.',
  'Mark as read': 'تحديد كمقروء',
  'Order placed': 'تم استلام الطلب',
  'Your order is awaiting payment.': 'طلبك بانتظار الدفع.',
  'Your cash-on-delivery order has been placed.': 'تم استلام طلبك للدفع عند الاستلام.',
  'Order cancelled': 'تم إلغاء الطلب',
  'Your order has been cancelled.': 'تم إلغاء طلبك.',
  'Payment received': 'تم استلام الدفع',
  'Payment failed': 'فشل الدفع',
  'Payment for your order was confirmed.': 'تم تأكيد الدفع لطلبك.',
  'Payment was not completed. You can try another payment attempt.': 'لم تكتمل عملية الدفع. يمكنك المحاولة مجدداً.',
  'Order is ready for delivery dispatch': 'الطلب جاهز للإرسال للتوصيل',
  'Order was cancelled before dispatch': 'تم إلغاء الطلب قبل إرساله للتوصيل',
  'Your cart is empty': 'سلتك فارغة',
  'Add bottled water and bulk packs to begin': 'أضف المياه المعبأة والعبوات الكبيرة للبدء',
  'Qty {quantity} • SAR {price}': 'الكمية {quantity} • {price} ريال',
  'Remove item': 'إزالة المنتج',
  'Discount': 'الخصم',
  'Total': 'الإجمالي',
  'Proceed to checkout': 'المتابعة لإتمام الطلب',
  'Language: English': 'اللغة: العربية',
  'Language: Arabic': 'Language: English',
  'Language preference could not be saved: {error}': 'تعذر حفظ إعداد اللغة: {error}',
  'Sign in is required to view your cart.': 'سجل الدخول لعرض سلتك.',
  'Sign in is required to update your cart.': 'سجل الدخول لتحديث سلتك.',
  'Sign in is required to manage addresses or checkout.': 'سجل الدخول لإدارة العناوين أو إتمام الطلب.',
  'Invalid email or password': 'البريد الإلكتروني أو كلمة المرور غير صحيحة',
  'Customer with this email already exists': 'يوجد حساب مسجل بهذا البريد الإلكتروني',
  'Email, password, first name, and last name are required': 'البريد الإلكتروني وكلمة المرور والاسم الأول واسم العائلة مطلوبة',
  'Checkout session not found': 'جلسة إتمام الطلب غير موجودة',
  'Delivery is not available for this order': 'معلومات التوصيل غير متاحة لهذا الطلب',
  'Notification not found': 'الإشعار غير موجود',
  'Unable to load cart': 'تعذر تحميل السلة',
  'Something went wrong. Please try again.': 'حدث خطأ ما. يرجى المحاولة مرة أخرى.',
  'Unable to load this information. Please try again.': 'تعذر تحميل هذه المعلومات. يرجى المحاولة مرة أخرى.',
  'A product could not be found.': 'تعذر العثور على المنتج.',
  'The requested item is no longer available.': 'العنصر المطلوب لم يعد متاحاً.',
  'This action is not available right now.': 'هذا الإجراء غير متاح حالياً.',
  'Your session has expired. Please sign in again.': 'انتهت جلستك. يرجى تسجيل الدخول مجدداً.',
  'Please check the information and try again.': 'يرجى مراجعة المعلومات والمحاولة مرة أخرى.',
};

const _arabicStatuses = <String, String>{
  'placed': 'تم إنشاء الطلب',
  'payment_pending': 'بانتظار الدفع',
  'payment_failed': 'فشل الدفع',
  'confirmed': 'مؤكد',
  'processing': 'قيد التجهيز',
  'cancelled': 'ملغي',
  'pending_dispatch': 'بانتظار الإرسال',
  'assigned': 'تم التعيين',
  'picked_up': 'تم الاستلام',
  'delivered': 'تم التوصيل',
  'failed': 'تعذر التوصيل',
  'pending': 'قيد الانتظار',
  'paid': 'مدفوع',
  'cash': 'نقداً',
  'card': 'بطاقة',
};

const _englishStatuses = <String, String>{
  'placed': 'Placed',
  'payment_pending': 'Payment pending',
  'payment_failed': 'Payment failed',
  'confirmed': 'Confirmed',
  'processing': 'Processing',
  'cancelled': 'Cancelled',
  'pending_dispatch': 'Pending dispatch',
  'assigned': 'Assigned',
  'picked_up': 'Picked up',
  'delivered': 'Delivered',
  'failed': 'Failed',
  'pending': 'Pending',
  'paid': 'Paid',
  'cash': 'Cash',
  'card': 'Card',
};

String localized(BuildContext context, String message, [Map<String, Object> values = const {}]) {
  var result = Localizations.localeOf(context).languageCode == 'ar'
      ? (_translations[message] ?? message)
      : message;
  for (final entry in values.entries) {
    result = result.replaceAll('{${entry.key}}', entry.value.toString());
  }
  return result;
}

String localizedStatus(BuildContext context, String status) {
  final labels = Localizations.localeOf(context).languageCode == 'ar'
      ? _arabicStatuses
      : _englishStatuses;
  return labels[status] ?? status.replaceAll('_', ' ');
}

String localizedError(BuildContext context, Object error) {
  Object? payload;
  if (error is DioException) {
    payload = error.response?.data;
  } else {
    final message = error.toString().replaceFirst(
          RegExp(r'^(Exception|StateError):\s*'),
          '',
        );
    return _knownError(context, message);
  }
  if (payload is Map<String, dynamic>) {
    final message = payload['message'];
    if (message is String) return _knownError(context, message);
    if (message is List) {
      final known = message.whereType<String>().map((item) => _knownError(context, item)).toList();
      if (known.isNotEmpty) return known.join('\n');
    }
  }
  return localized(context, 'Something went wrong. Please try again.');
}

String _knownError(BuildContext context, String message) {
  const known = {
    'Invalid email or password',
    'Customer with this email already exists',
    'Email, password, first name, and last name are required',
    'Checkout session not found',
    'Delivery is not available for this order',
    'Notification not found',
    'Sign in is required to view your cart.',
    'Sign in is required to update your cart.',
    'Sign in is required to manage addresses or checkout.',
    'Could not update the default address.',
    'Could not delete the address.',
    'Unable to load cart',
    'Too many requests',
  };
  if (known.contains(message)) return localized(context, message);
  if (message.contains('Product not found')) {
    return localized(context, 'A product could not be found.');
  }
  if (message.contains('not found') || message.contains('no longer available')) {
    return localized(context, 'The requested item is no longer available.');
  }
  return localized(context, 'Please check the information and try again.');
}

final appLocaleProvider = StateNotifierProvider<AppLocaleController, Locale>(
  (ref) => AppLocaleController(),
);

abstract interface class LocalePreferenceStore {
  Future<String?> read();
  Future<void> write(String languageCode);
}

class SecureLocalePreferenceStore implements LocalePreferenceStore {
  const SecureLocalePreferenceStore();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: 'app_language');

  @override
  Future<void> write(String languageCode) =>
      _storage.write(key: 'app_language', value: languageCode);
}

class AppLocaleController extends StateNotifier<Locale> {
  AppLocaleController({
    LocalePreferenceStore store = const SecureLocalePreferenceStore(),
  })  : _store = store,
        super(const Locale('en')) {
    _restore();
  }

  final LocalePreferenceStore _store;
  bool _changedByUser = false;

  Future<void> _restore() async {
    try {
      final saved = await _store.read();
      if (!_changedByUser && saved != null && (saved == 'en' || saved == 'ar')) {
        state = Locale(saved);
      }
    } catch (error) {
      debugPrint('Unable to restore saved language preference: $error');
    }
  }

  Future<void> toggle() async {
    final locale = Locale(state.languageCode == 'en' ? 'ar' : 'en');
    _changedByUser = true;
    state = locale;
    await _store.write(locale.languageCode);
  }
}

class LanguageSwitch extends ConsumerWidget {
  const LanguageSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = Localizations.localeOf(context).languageCode;
    return TextButton(
      onPressed: () async {
        try {
          await ref.read(appLocaleProvider.notifier).toggle();
        } catch (error) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(localized(
                context,
                'Language preference could not be saved: {error}',
                {'error': error},
              ))),
            );
          }
        }
      },
      child: Text(localized(context, language == 'en' ? 'Language: English' : 'Language: Arabic')),
    );
  }
}
