import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const _adminTranslations = <String, String>{
  'AquaFlow Admin': 'إدارة أكوافلو',
  'Administrator sign in': 'تسجيل دخول المسؤول',
  'Enter a valid email address': 'أدخل بريداً إلكترونياً صحيحاً',
  'This account does not have administrator access.':
      'هذا الحساب لا يملك صلاحية المسؤول.',
  'The server returned an incomplete administrator session.':
      'أعاد الخادم بيانات جلسة مسؤول غير مكتملة.',
  'Unable to reach the AquaFlow server. Check the API URL and network.':
      'تعذر الاتصال بخادم أكوافلو. تحقق من رابط واجهة البرمجة والشبكة.',
  'Administrator sign-in is required.': 'يلزم تسجيل الدخول بحساب مسؤول.',
  'The request could not be completed.': 'تعذر إكمال الطلب.',
  'Dashboard': 'لوحة المعلومات',
  'Products': 'المنتجات',
  'Operations': 'العمليات',
  'More': 'المزيد',
  'Overview': 'نظرة عامة',
  'Orders': 'الطلبات',
  'Open orders': 'الطلبات المفتوحة',
  'Awaiting payment': 'بانتظار الدفع',
  'Paid order total': 'إجمالي الطلبات المدفوعة',
  'Pending dispatch': 'بانتظار الإرسال',
  'Active products': 'المنتجات النشطة',
  'Recent orders': 'أحدث الطلبات',
  'No orders yet.': 'لا توجد طلبات بعد.',
  'Add product': 'إضافة منتج',
  'Product actions': 'إجراءات المنتج',
  'Edit details': 'تعديل التفاصيل',
  'Update price': 'تحديث السعر',
  'Price': 'السعر',
  'Change price': 'تغيير السعر',
  'Enter a price greater than zero.': 'أدخل سعراً أكبر من صفر.',
  'Categories and brands': 'الفئات والعلامات التجارية',
  'Add category': 'إضافة فئة',
  'Add brand': 'إضافة علامة تجارية',
  'Edit category': 'تعديل الفئة',
  'Edit brand': 'تعديل العلامة التجارية',
  'Inventory': 'المخزون',
  'Deliveries': 'التوصيل',
  'Status': 'الحالة',
  'All': 'الكل',
  'Cancel': 'إلغاء',
  'Confirm': 'تأكيد',
  'Search current page': 'بحث في الصفحة الحالية',
  '{count} results': '{count} نتيجة',
  'Page {page} of {total}': 'الصفحة {page} من {total}',
  'Previous page': 'الصفحة السابقة',
  'Next page': 'الصفحة التالية',
  'Order details': 'تفاصيل الطلب',
  'Order information': 'معلومات الطلب',
  'Order number': 'رقم الطلب',
  'Customer': 'العميل',
  'Customer ID': 'معرّف العميل',
  'Customer {id}': 'العميل {id}',
  'Customer name unavailable': 'اسم العميل غير متاح',
  'Order status': 'حالة الطلب',
  'Delivery status': 'حالة التوصيل',
  'No delivery record': 'لا يوجد سجل توصيل',
  'Payment': 'الدفع',
  'Payment method': 'طريقة الدفع',
  'Delivery option': 'خيار التوصيل',
  'Created': 'تاريخ الإنشاء',
  'Last updated': 'آخر تحديث',
  'Cancelled': 'تاريخ الإلغاء',
  'Email': 'البريد الإلكتروني',
  'Phone': 'الهاتف',
  'Order items': 'عناصر الطلب',
  'No order items found.': 'لا توجد عناصر في الطلب.',
  'Quantity': 'الكمية',
  'Totals': 'الإجماليات',
  'Subtotal': 'المجموع الفرعي',
  'Discount': 'الخصم',
  'Promotion': 'العرض الترويجي',
  'Delivery fee': 'رسوم التوصيل',
  'Service fee': 'رسوم الخدمة',
  'Total': 'الإجمالي',
  'Delivery address': 'عنوان التوصيل',
  'Recipient': 'المستلم',
  'City': 'المدينة',
  'District': 'الحي',
  'Street': 'الشارع',
  'Building': 'المبنى',
  'Apartment': 'الشقة',
  'Floor': 'الطابق',
  'Notes': 'ملاحظات',
  'Address label': 'وصف العنوان',
  'Delivery zone': 'منطقة التوصيل',
  'Base fee': 'الرسوم الأساسية',
  'Express fee': 'رسوم التوصيل السريع',
  'Estimated delivery': 'وقت التوصيل التقديري',
  'Payment information': 'معلومات الدفع',
  'Provider': 'مزود الدفع',
  'Amount': 'المبلغ',
  'Failure code': 'رمز الإخفاق',
  'No payment record.': 'لا توجد معلومات دفع.',
  'Delivery details': 'تفاصيل التوصيل',
  'Tracking code': 'رمز التتبع',
  'Delivered at': 'تاريخ التوصيل',
  'Delivery history': 'سجل التوصيل',
  'Order status history is not available in the current API.':
      'سجل حالات الطلب غير متاح في واجهة البرمجة الحالية.',
  'Confirm delivery status change to {status}?':
      'هل تريد تأكيد تغيير حالة التوصيل إلى {status}؟',
  'Updated from AquaFlow Admin mobile': 'تم التحديث من تطبيق إدارة أكوافلو',
  'No orders found.': 'لم يتم العثور على طلبات.',
  'No deliveries found.': 'لم يتم العثور على توصيلات.',
  'No matching results.': 'لا توجد نتائج مطابقة.',
  'succeeded': 'ناجح',
  'Adjust stock': 'تعديل المخزون',
  'Available stock': 'الكمية المتاحة للبيع',
  'Available stock is reduced when orders are placed. Dispatch quantities and physical stocktakes are not recorded.':
      'تنخفض الكمية المتاحة عند إنشاء الطلب. لا تُسجل كميات الإرسال أو الجرد الفعلي.',
  'Stock movement history': 'سجل حركات المخزون',
  'View stock movements': 'عرض حركات المخزون',
  'Hide': 'إخفاء',
  'Close': 'إغلاق',
  'Stock adjustment saved.': 'تم حفظ تعديل المخزون.',
  'Delivery status updated.': 'تم تحديث حالة التوصيل.',
  'Refresh failed; saved changes remain applied.':
      'تعذر التحديث؛ ما زالت التغييرات المحفوظة مطبقة.',
  'No stock movements recorded.': 'لا توجد حركات مخزون مسجلة.',
  'Loading stock movements…': 'جارٍ تحميل حركات المخزون…',
  'Reserved for an order': 'حجز لطلب',
  'Released after order cancellation': 'إلغاء حجز بعد إلغاء الطلب',
  'Administrator adjustment': 'تعديل إداري',
  'Administrator ID': 'معرّف المسؤول',
  'Stock update saved, but the latest data could not be refreshed.':
      'تم حفظ تعديل المخزون، لكن تعذر تحديث البيانات.',
  'Delivery status saved, but the latest data could not be refreshed.':
      'تم حفظ حالة التوصيل، لكن تعذر تحديث البيانات.',
  'Change in units (positive or negative)':
      'مقدار التغيير بالوحدات (موجب أو سالب)',
  'Enter a non-zero whole number.': 'أدخل عدداً صحيحاً غير صفر.',
  'Update delivery': 'تحديث حالة التوصيل',
  'Promotions': 'العروض الترويجية',
  'Reviews': 'التقييمات',
  'Cities & zones': 'المدن ومناطق التوصيل',
  'Create promotion': 'إنشاء عرض ترويجي',
  'Reviews awaiting moderation': 'تقييمات بانتظار المراجعة',
  'Approve': 'قبول',
  'Reject': 'رفض',
  'Cities': 'المدن',
  'No active cities.': 'لا توجد مدن نشطة.',
  'Delivery zones (read-only)': 'مناطق التوصيل (للعرض فقط)',
  'Zone configuration is not editable through the current API.':
      'لا يمكن تعديل إعدادات المناطق عبر واجهة البرمجة الحالية.',
  'No active delivery zones.': 'لا توجد مناطق توصيل نشطة.',
  'Unable to load {section}.': 'تعذر تحميل {section}.',
  'No {section} found.': 'لم يتم العثور على {section}.',
  'Create a category and brand before adding a product.':
      'أنشئ فئة وعلامة تجارية قبل إضافة منتج.',
  'Name': 'الاسم',
  'Slug (lowercase-hyphenated)': 'المعرّف (أحرف صغيرة وواصلات)',
  'Price (SAR)': 'السعر (ريال سعودي)',
  'Category': 'الفئة',
  'Brand': 'العلامة التجارية',
  'Create': 'إنشاء',
  'Arabic name (optional)': 'الاسم بالعربية (اختياري)',
  'Slug': 'المعرّف',
  'Save': 'حفظ',
  'Code': 'الرمز',
  'Discount type': 'نوع الخصم',
  'Percentage': 'نسبة مئوية',
  'Fixed amount': 'مبلغ ثابت',
  'Discount value': 'قيمة الخصم',
  'Enter a valid promotion code and discount.': 'أدخل رمز عرض وقيمة خصم صحيحة.',
  'Enter a valid product name, slug, and price.':
      'أدخل اسماً ومعرّفاً وسعراً صحيحاً للمنتج.',
  'Low stock': 'مخزون منخفض',
  'Out of stock': 'نفد المخزون',
  'Unable to load inventory.': 'تعذر تحميل المخزون.',
  'Unable to load orders.': 'تعذر تحميل الطلبات.',
  'Unable to load deliveries.': 'تعذر تحميل التوصيلات.',
  'Unable to load products.': 'تعذر تحميل المنتجات.',
  'Unable to load categories and brands.':
      'تعذر تحميل الفئات والعلامات التجارية.',
  'Unable to load promotions.': 'تعذر تحميل العروض الترويجية.',
  'Unable to load reviews awaiting moderation.':
      'تعذر تحميل التقييمات التي تنتظر المراجعة.',
  'Enter a valid price.': 'أدخل سعراً صحيحاً.',
  'Enter a valid stock adjustment.': 'أدخل تعديلاً صحيحاً للمخزون.',
  'Enter a valid name and slug.': 'أدخل اسماً ومعرّفاً صحيحين.',
  'Enter a valid promotion value.': 'أدخل قيمة عرض صحيحة.',
  'The request failed ({status}).': 'فشل الطلب ({status}).',
  'Mark {status}': 'تعيين الحالة: {status}',
  'Order {id}': 'الطلب {id}',
  '{quantity} units': '{quantity} وحدة',
  'minutes': 'دقيقة',
  'redemptions': 'عملية استخدام',
  'Standard': 'عادي',
  'Express': 'سريع',
  'Activate': 'تفعيل',
  'Deactivate': 'إيقاف التفعيل',
  'Enter your password': 'أدخل كلمة المرور',
  'Required': 'مطلوب',
  'in_stock': 'متوفر',
  'out_of_stock': 'نفد المخزون',
};

const _translations = <String, String>{
  'Sign out': 'تسجيل الخروج',
  'Home': 'الرئيسية',
  'Categories': 'الفئات',
  'Favorites': 'المفضلة',
  'Profile': 'حسابي',
  'Forgot password?': 'هل نسيت كلمة المرور؟',
  'Show password': 'إظهار كلمة المرور',
  'Hide password': 'إخفاء كلمة المرور',
  'Remove favorite': 'إزالة من المفضلة',
  'Add to favorites': 'أضف إلى المفضلة',
  'No favorites yet.': 'لا توجد منتجات في المفضلة بعد.',
  'Change password': 'تغيير كلمة المرور',
  'Current password': 'كلمة المرور الحالية',
  'New password': 'كلمة المرور الجديدة',
  'Current password is incorrect': 'كلمة المرور الحالية غير صحيحة.',
  'New password must differ from the current password':
      'يجب أن تختلف كلمة المرور الجديدة عن الحالية.',
  'Recovery code is invalid or expired':
      'رمز الاستعادة غير صحيح أو انتهت صلاحيته.',
  'Password recovery email is not configured':
      'خدمة استعادة كلمة المرور عبر البريد غير مهيأة.',
  'Password changed.': 'تم تغيير كلمة المرور.',
  'Enter your name.': 'أدخل الاسم.',
  'Profile saved.': 'تم حفظ الملف الشخصي.',
  'Save profile': 'حفظ الملف الشخصي',
  'Notifications are in-app only; preferences are unavailable.':
      'الإشعارات متاحة داخل التطبيق فقط، ولا تتوفر إعدادات للتفضيلات حالياً.',
  'Send recovery code': 'إرسال رمز الاستعادة',
  'If an account matches this email, recovery instructions will be sent if delivery is available.':
      'إذا كان البريد مرتبطاً بحساب، فستُرسل تعليمات الاستعادة عند توفر خدمة البريد.',
  'Recovery code': 'رمز الاستعادة',
  'Reset password': 'إعادة تعيين كلمة المرور',
  'Password reset complete.': 'تمت إعادة تعيين كلمة المرور.',
  'More': 'المزيد',
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
  'Manage delivery addresses and defaults':
      'إدارة عناوين التوصيل والعنوان الافتراضي',
  'Checkout': 'إتمام الطلب',
  'Review delivery and payment details': 'مراجعة تفاصيل التوصيل والدفع',
  'Cart': 'السلة',
  'Review order total before checkout': 'مراجعة إجمالي الطلب قبل إتمامه',
  'Orders': 'الطلبات',
  'View, cancel, or reorder your purchases':
      'عرض مشترياتك أو إلغاؤها أو إعادة طلبها',
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
  'Enter your password': 'أدخل كلمة المرور',
  'Enter a valid email': 'أدخل بريداً إلكترونياً صحيحاً',
  'Password must be at least 8 characters': 'يجب ألا تقل كلمة المرور عن 8 أحرف',
  'Password must include a letter, number, and symbol':
      'يجب أن تحتوي كلمة المرور على حرف ورقم ورمز',
  'Unable to reach the AquaFlow server. Check the API URL and network.':
      'تعذر الاتصال بخادم أكوافلو. تحقق من رابط الخادم والاتصال بالشبكة.',
  'The server is temporarily unavailable. Please try again later.':
      'الخادم غير متاح مؤقتاً. يرجى المحاولة لاحقاً.',
  'Retry': 'إعادة المحاولة',
  'Too many requests': 'طلبات كثيرة جداً. يرجى المحاولة لاحقاً.',
  'No addresses yet. Add your first delivery address.':
      'لا توجد عناوين بعد. أضف عنوان التوصيل الأول.',
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
  'Card payment processing is not available yet. The order will remain payment pending.':
      'معالجة الدفع بالبطاقة غير متاحة حالياً. سيبقى الطلب بانتظار الدفع.',
  'Review your checkout before placing the order.':
      'راجع تفاصيل طلبك قبل تأكيده.',
  'Order received': 'تم استلام الطلب',
  'Your order was received.': 'تم استلام طلبك بنجاح.',
  'Order number': 'رقم الطلب',
  'Order status': 'حالة الطلب',
  'Delivery status': 'حالة التوصيل',
  'Order total': 'إجمالي الطلب',
  'View my orders': 'عرض طلباتي',
  'Go to home': 'العودة إلى الرئيسية',
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
  'Live driver tracking is not available yet.':
      'تتبع السائق المباشر غير متاح حالياً.',
  'Delivery information is unavailable: {error}':
      'معلومات التوصيل غير متاحة: {error}',
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
  'Payment intent created by {provider}; no payment was taken and no provider checkout is configured.':
      'تم إنشاء طلب دفع عبر {provider}؛ لم يتم تحصيل أي مبلغ ولم يتم إعداد بوابة دفع.',
  'Payment intent created. Continue through the provider checkout.':
      'تم إنشاء طلب الدفع. أكمل عبر صفحة مزود الدفع.',
  'Delivery {status}': 'حالة التوصيل: {status}',
  'You have no orders yet.': 'ليس لديك طلبات بعد.',
  'Could not update notification: {error}': 'تعذر تحديث الإشعار: {error}',
  'No notifications yet.': 'لا توجد إشعارات بعد.',
  'Mark as read': 'تحديد كمقروء',
  'Order placed': 'تم استلام الطلب',
  'Your order is awaiting payment.': 'طلبك بانتظار الدفع.',
  'Your cash-on-delivery order has been placed.':
      'تم استلام طلبك للدفع عند الاستلام.',
  'Order cancelled': 'تم إلغاء الطلب',
  'Order can no longer be cancelled after delivery dispatch has started':
      'لا يمكن إلغاء الطلب بعد بدء إرساله للتوصيل.',
  'Your order has been cancelled.': 'تم إلغاء طلبك.',
  'Payment received': 'تم استلام الدفع',
  'Payment failed': 'فشل الدفع',
  'Payment for your order was confirmed.': 'تم تأكيد الدفع لطلبك.',
  'Payment was not completed. You can try another payment attempt.':
      'لم تكتمل عملية الدفع. يمكنك المحاولة مجدداً.',
  'Order is ready for delivery dispatch': 'الطلب جاهز للإرسال للتوصيل',
  'Order was cancelled before dispatch': 'تم إلغاء الطلب قبل إرساله للتوصيل',
  'Your cart is empty': 'سلتك فارغة',
  'Add bottled water and bulk packs to begin':
      'أضف المياه المعبأة والعبوات الكبيرة للبدء',
  'Browse products': 'تصفح المنتجات',
  '{count} items': '{count} منتجات',
  'SAR {price} each': '{price} ريال للقطعة',
  'Decrease quantity': 'تقليل الكمية',
  'Increase quantity': 'زيادة الكمية',
  'Product details': 'تفاصيل المنتج',
  'In stock': 'متوفر',
  'Out of stock': 'نفد المخزون',
  'Administrator sign in': 'تسجيل دخول المسؤول',
  'Delivery could not be completed': 'تعذر إكمال التوصيل',
  'Select a delivery address and zone before continuing.':
      'اختر عنوان التوصيل ومنطقة التوصيل للمتابعة.',
  'No delivery zones are configured for {city}.':
      'لا توجد مناطق توصيل مهيأة لمدينة {city}.',
  'The order could not be completed.': 'تعذر إكمال الطلب.',
  'Available quantity': 'الكمية المتاحة',
  'Add {quantity} to cart': 'أضف {quantity} إلى السلة',
  'Offers': 'عروض',
  'Shop now': 'تسوق الآن',
  'Featured products': 'منتجات مختارة',
  'Explore categories': 'تصفح الفئات',
  'No products available right now.': 'لا توجد منتجات متاحة حالياً.',
  'A discount is available': 'خصم متاح',
  'Search AquaFlow products': 'ابحث عن منتجات أكوافلو',
  'Brand': 'العلامة التجارية',
  'Compare at SAR {price}': 'السعر السابق {price} ريال',
  'Qty {quantity} • SAR {price}': 'الكمية {quantity} • {price} ريال',
  'Remove item': 'إزالة المنتج',
  'Discount': 'الخصم',
  'Total': 'الإجمالي',
  'Proceed to checkout': 'المتابعة لإتمام الطلب',
  'Switch to English': 'التبديل إلى الإنجليزية',
  'Switch to Arabic': 'التبديل إلى العربية',
  'Language: English': 'اللغة: العربية',
  'Language: Arabic': 'Language: English',
  'Language preference could not be saved: {error}':
      'تعذر حفظ إعداد اللغة: {error}',
  'Sign in is required to view your cart.': 'سجل الدخول لعرض سلتك.',
  'Sign in is required to update your cart.': 'سجل الدخول لتحديث سلتك.',
  'Sign in is required to manage addresses or checkout.':
      'سجل الدخول لإدارة العناوين أو إتمام الطلب.',
  'Invalid email or password': 'البريد الإلكتروني أو كلمة المرور غير صحيحة',
  'Customer with this email already exists':
      'يوجد حساب مسجل بهذا البريد الإلكتروني',
  'Email, password, first name, and last name are required':
      'البريد الإلكتروني وكلمة المرور والاسم الأول واسم العائلة مطلوبة',
  'Checkout session not found': 'جلسة إتمام الطلب غير موجودة',
  'Delivery is not available for this order':
      'معلومات التوصيل غير متاحة لهذا الطلب',
  'Notification not found': 'الإشعار غير موجود',
  'Unable to load cart': 'تعذر تحميل السلة',
  'Something went wrong. Please try again.':
      'حدث خطأ ما. يرجى المحاولة مرة أخرى.',
  'Unable to load this information. Please try again.':
      'تعذر تحميل هذه المعلومات. يرجى المحاولة مرة أخرى.',
  'A product could not be found.': 'تعذر العثور على المنتج.',
  'The requested item is no longer available.': 'العنصر المطلوب لم يعد متاحاً.',
  'This action is not available right now.': 'هذا الإجراء غير متاح حالياً.',
  'Your session has expired. Please sign in again.':
      'انتهت جلستك. يرجى تسجيل الدخول مجدداً.',
  'Please check the information and try again.':
      'يرجى مراجعة المعلومات والمحاولة مرة أخرى.',
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

String localized(BuildContext context, String message,
    [Map<String, Object> values = const {}]) {
  var result = Localizations.localeOf(context).languageCode == 'ar'
      ? (_translations[message] ?? message)
      : message;
  for (final entry in values.entries) {
    result = result.replaceAll('{${entry.key}}', entry.value.toString());
  }
  return result;
}

String localizedAdmin(
  BuildContext context,
  String message, [
  Map<String, Object> values = const {},
]) {
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  var result = isArabic
      ? (_adminTranslations[message] ?? _translations[message] ?? message)
      : message;
  for (final entry in values.entries) {
    result = result.replaceAll('{${entry.key}}', entry.value.toString());
  }
  return result;
}

String localizedStatus(BuildContext context, String status) {
  final isArabic = Localizations.localeOf(context).languageCode == 'ar';
  final labels = isArabic ? _arabicStatuses : _englishStatuses;
  if (isArabic && _adminTranslations.containsKey(status)) {
    return _adminTranslations[status]!;
  }
  return labels[status] ?? status.replaceAll('_', ' ');
}

String localizedError(BuildContext context, Object error) {
  if (error is DioException) {
    final response = error.response;
    if (response == null) {
      return localized(
        context,
        'Unable to reach the AquaFlow server. Check the API URL and network.',
      );
    }
    if (response.statusCode == 503 &&
        response.data is Map<String, dynamic> &&
        response.data['message'] ==
            'Password recovery email is not configured') {
      return localized(context, 'Password recovery email is not configured');
    }
    if (response.statusCode != null && response.statusCode! >= 500) {
      return localized(
        context,
        'The server is temporarily unavailable. Please try again later.',
      );
    }
    return _localizedResponseError(context, response.data);
  }
  final message = error.toString().replaceFirst(
        RegExp(r'^(Exception|StateError):\s*'),
        '',
      );
  return _knownError(context, message);
}

String _localizedResponseError(BuildContext context, Object? payload) {
  if (payload is Map<String, dynamic>) {
    final message = payload['message'];
    if (message is String) return _knownError(context, message);
    if (message is List) {
      final known = message
          .whereType<String>()
          .map((item) => _knownValidationError(context, item))
          .whereType<String>()
          .toSet()
          .toList();
      if (known.contains(
          localized(context, 'Password must be at least 8 characters'))) {
        return localized(context, 'Password must be at least 8 characters');
      }
      if (known.isNotEmpty) return known.join('\n');
    }
  }
  return localized(context, 'Please check the information and try again.');
}

String? _knownValidationError(BuildContext context, String message) {
  final normalized = message.trim().toLowerCase();
  if (normalized == 'email must be an email' ||
      normalized == 'email should not be empty' ||
      normalized == 'email must be a string') {
    return localized(context, 'Enter a valid email');
  }
  if (normalized == 'password must be longer than or equal to 8 characters') {
    return localized(context, 'Password must be at least 8 characters');
  }
  if (normalized == 'password must include a letter, number, and symbol') {
    return localized(
      context,
      'Password must include a letter, number, and symbol',
    );
  }
  if (normalized == 'password should not be empty' ||
      normalized == 'password must be a string') {
    return localized(context, 'Enter your password');
  }
  if (normalized == 'firstname should not be empty' ||
      normalized == 'firstname must be a string') {
    return localized(context, 'Enter your first name');
  }
  if (normalized == 'lastname should not be empty' ||
      normalized == 'lastname must be a string') {
    return localized(context, 'Enter your last name');
  }
  return null;
}

String _knownError(BuildContext context, String message) {
  const known = {
    'Invalid email or password',
    'Current password is incorrect',
    'New password must differ from the current password',
    'Recovery code is invalid or expired',
    'Customer with this email already exists',
    'Email, password, first name, and last name are required',
    'Checkout session not found',
    'Order can no longer be cancelled after delivery dispatch has started',
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
  if (message.contains('not found') ||
      message.contains('no longer available')) {
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
        super(const Locale('ar')) {
    _restore();
  }

  final LocalePreferenceStore _store;
  bool _changedByUser = false;

  Future<void> _restore() async {
    try {
      final saved = await _store.read();
      if (!_changedByUser &&
          saved != null &&
          (saved == 'en' || saved == 'ar')) {
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
  const LanguageSwitch({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = Localizations.localeOf(context).languageCode;
    Future<void> toggle() async {
      try {
        await ref.read(appLocaleProvider.notifier).toggle();
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(localized(
              context,
              'Language preference could not be saved: {error}',
              {'error': error},
            ))),
          );
        }
      }
    }

    final label = localized(
      context,
      language == 'en' ? 'Switch to Arabic' : 'Switch to English',
    );
    if (compact) {
      return IconButton(
        tooltip: label,
        onPressed: toggle,
        icon: const Icon(Icons.translate_rounded),
      );
    }
    return TextButton(onPressed: toggle, child: Text(label));
  }
}
