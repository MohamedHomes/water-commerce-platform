import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../localization.dart';
import 'admin_api.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({
    required this.api,
    required this.onSignedIn,
    super.key,
  });

  final AdminApi api;
  final VoidCallback onSignedIn;

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.api.login(_email.text.trim(), _password.text);
      _password.clear();
      widget.onSignedIn();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = localizedAdmin(context, widget.api.errorMessage(error));
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(localizedAdmin(context, 'AquaFlow Admin')),
        actions: const [LanguageSwitch()],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Form(
            key: _formKey,
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                const Icon(Icons.admin_panel_settings_outlined, size: 56),
                const SizedBox(height: 16),
                Text(
                  localizedAdmin(context, 'Administrator sign in'),
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const Key('admin-email'),
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  decoration: InputDecoration(
                    labelText: localizedAdmin(context, 'Email'),
                  ),
                  validator: (value) => value == null || !value.contains('@')
                      ? localizedAdmin(context, 'Enter a valid email address')
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const Key('admin-password'),
                  controller: _password,
                  obscureText: true,
                  autofillHints: const [AutofillHints.password],
                  decoration: InputDecoration(
                    labelText: localizedAdmin(context, 'Password'),
                  ),
                  validator: (value) => value == null || value.isEmpty
                      ? localizedAdmin(context, 'Enter your password')
                      : null,
                  onFieldSubmitted: (_) => _loading ? null : _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    key: const Key('admin-login-error'),
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(localizedAdmin(context, 'Sign in')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminRouteGate extends StatefulWidget {
  const AdminRouteGate({
    required this.api,
    required this.child,
    super.key,
  });

  final AdminApi api;
  final Widget child;

  @override
  State<AdminRouteGate> createState() => _AdminRouteGateState();
}

class _AdminRouteGateState extends State<AdminRouteGate> {
  late Future<bool> _session;

  @override
  void initState() {
    super.initState();
    _session = widget.api.validateSession();
  }

  void _retry() => setState(() => _session = widget.api.validateSession());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _session,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: _MessageState(
              message: localizedAdmin(
                context,
                widget.api.errorMessage(snapshot.error!),
              ),
              actionLabel: localizedAdmin(context, 'Retry'),
              onAction: _retry,
            ),
          );
        }
        if (snapshot.data != true) {
          return Scaffold(
            body: _MessageState(
              message:
                  localizedAdmin(context, 'Administrator sign-in is required.'),
              actionLabel: localizedAdmin(context, 'Sign in'),
              onAction: () => context.go('/admin/login'),
            ),
          );
        }
        return widget.child;
      },
    );
  }
}

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({
    required this.api,
    super.key,
  });

  final AdminApi api;

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _selectedIndex = 0;

  Future<void> _signOut() async {
    await widget.api.logout();
    if (mounted) context.go('/admin/login');
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      AdminDashboardTab(api: widget.api),
      AdminProductsTab(api: widget.api),
      AdminCatalogTab(api: widget.api),
      AdminOperationsTab(api: widget.api),
      AdminMoreTab(api: widget.api),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(localizedAdmin(context, 'AquaFlow Admin')),
        actions: [
          const LanguageSwitch(),
          IconButton(
            key: const Key('admin-sign-out'),
            tooltip: localizedAdmin(context, 'Sign out'),
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(child: pages[_selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: localizedAdmin(context, 'Dashboard'),
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: localizedAdmin(context, 'Products'),
          ),
          NavigationDestination(
            icon: Icon(Icons.category_outlined),
            selectedIcon: Icon(Icons.category),
            label: localizedAdmin(context, 'Catalog'),
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping),
            label: localizedAdmin(context, 'Operations'),
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            label: localizedAdmin(context, 'More'),
          ),
        ],
      ),
    );
  }
}

class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({required this.api, super.key});

  final AdminApi api;

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  late Future<Map<String, dynamic>> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final metrics = await widget.api.get('/admin/dashboard');
    final orders = await widget.api.get('/admin/orders', query: {'limit': 5});
    return {'metrics': metrics, 'orders': _items(orders)};
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _MessageState(
            message: localizedAdmin(
              context,
              widget.api.errorMessage(snapshot.error!),
            ),
            actionLabel: localizedAdmin(context, 'Retry'),
            onAction: () => setState(() {
              _data = _load();
            }),
          );
        }
        final data = snapshot.data!;
        final metrics = data['metrics'] as Map<String, dynamic>;
        final orders = data['orders'] as List<Map<String, dynamic>>;
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _data = _load();
            });
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text(localizedAdmin(context, 'Overview'),
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MetricCard(
                    localizedAdmin(context, 'Orders'),
                    metrics['totalOrders'],
                  ),
                  _MetricCard(
                    localizedAdmin(context, 'Open orders'),
                    metrics['openOrders'],
                  ),
                  _MetricCard(
                    localizedAdmin(context, 'Awaiting payment'),
                    metrics['awaitingPayment'],
                  ),
                  _MetricCard(
                    localizedAdmin(context, 'Paid revenue'),
                    '${metrics['currency'] ?? 'SAR'} ${metrics['paidRevenue'] ?? 0}',
                  ),
                  _MetricCard(
                    localizedAdmin(context, 'Pending dispatch'),
                    metrics['pendingDispatch'],
                  ),
                  _MetricCard(
                    localizedAdmin(context, 'Active products'),
                    metrics['activeProducts'],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(localizedAdmin(context, 'Recent orders'),
                  style: Theme.of(context).textTheme.titleLarge),
              if (orders.isEmpty)
                _EmptyState(
                  message: localizedAdmin(context, 'No orders yet.'),
                )
              else
                ...orders.map((order) => Card(
                      child: ListTile(
                        title: Text(_shortId(order['id'])),
                        subtitle: Text(
                          '${localizedStatus(context, _string(order['status']))} · '
                          '${localizedStatus(context, _string(order['paymentMethod']))}',
                        ),
                        trailing: Text(
                          '${order['currency']} ${order['total']}',
                        ),
                      ),
                    )),
            ],
          ),
        );
      },
    );
  }
}

class AdminProductsTab extends StatelessWidget {
  const AdminProductsTab({required this.api, super.key});

  final AdminApi api;

  @override
  Widget build(BuildContext context) {
    return AdminCollection(
      title: localizedAdmin(context, 'Products'),
      load: () async => _items(await api.get('/admin/products')),
      headerBuilder: (context, reload) => Align(
        alignment: AlignmentDirectional.centerEnd,
        child: FilledButton.icon(
          onPressed: () => _createProduct(context, api, reload),
          icon: const Icon(Icons.add),
          label: Text(localizedAdmin(context, 'Add product')),
        ),
      ),
      itemBuilder: (context, product, reload) => Card(
        child: ListTile(
          title: Text(_displayName(context, product)),
          subtitle: Text(
            '${localizedStatus(context, _string(product['availability']))} · '
            '${localizedAdmin(context, '{quantity} units', {
                  'quantity': product['quantity'] ?? 0,
                })} · '
            'SAR ${product['price']}',
          ),
          trailing: PopupMenuButton<String>(
            tooltip: localizedAdmin(context, 'Product actions'),
            onSelected: (action) async {
              try {
                if (action == 'toggle') {
                  await api.patch(
                    '/admin/products/${Uri.encodeComponent(_string(product['id']))}',
                    data: {'isActive': product['is_active'] != true},
                  );
                } else if (action == 'edit') {
                  await _editProduct(context, api, product);
                } else if (action == 'price') {
                  final price = await _askText(
                    context,
                    title: localizedAdmin(context, 'Update price'),
                    label: localizedAdmin(context, 'Price'),
                    initialValue: _string(product['price']),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  );
                  if (price != null) {
                    final value = double.tryParse(price);
                    if (value == null || value <= 0) {
                      throw const AdminAuthorizationException(
                        'Enter a price greater than zero.',
                      );
                    }
                    await api.patch(
                      '/admin/products/${Uri.encodeComponent(_string(product['id']))}',
                      data: {'price': value},
                    );
                  }
                }
                reload();
              } catch (error) {
                if (context.mounted) _showError(context, api, error);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: Text(localizedAdmin(context, 'Edit details')),
              ),
              PopupMenuItem(
                value: 'toggle',
                child: Text(
                  localizedAdmin(
                    context,
                    product['is_active'] == true ? 'Deactivate' : 'Activate',
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'price',
                child: Text(localizedAdmin(context, 'Change price')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminCatalogTab extends StatelessWidget {
  const AdminCatalogTab({required this.api, super.key});

  final AdminApi api;

  @override
  Widget build(BuildContext context) {
    return AdminCollection(
      title: localizedAdmin(context, 'Categories and brands'),
      load: () async {
        final terms = await api.get('/admin/catalog-terms');
        return [
          ..._items(terms, key: 'categories')
              .map((term) => {...term, '_kind': 'category'}),
          ..._items(terms, key: 'brands')
              .map((term) => {...term, '_kind': 'brand'}),
        ];
      },
      headerBuilder: (context, reload) => Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            onPressed: () => _editTerm(context, api, 'categories', reload),
            icon: const Icon(Icons.add),
            label: Text(localizedAdmin(context, 'Add category')),
          ),
          FilledButton.icon(
            onPressed: () => _editTerm(context, api, 'brands', reload),
            icon: const Icon(Icons.add),
            label: Text(localizedAdmin(context, 'Add brand')),
          ),
        ],
      ),
      itemBuilder: (context, term, reload) {
        final kind = _string(term['_kind']);
        final endpoint = kind == 'category' ? 'categories' : 'brands';
        return Card(
          child: ListTile(
            title: Text(_displayName(context, term)),
            subtitle: Text(
              '${localizedAdmin(context, kind == 'category' ? 'Category' : 'Brand')} · ${term['slug']}',
            ),
            trailing: IconButton(
              tooltip: localizedAdmin(
                context,
                kind == 'category' ? 'Edit category' : 'Edit brand',
              ),
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _editTerm(
                context,
                api,
                endpoint,
                reload,
                existing: term,
              ),
            ),
          ),
        );
      },
    );
  }
}

class AdminOperationsTab extends StatefulWidget {
  const AdminOperationsTab({required this.api, super.key});

  final AdminApi api;

  @override
  State<AdminOperationsTab> createState() => _AdminOperationsTabState();
}

class _AdminOperationsTabState extends State<AdminOperationsTab> {
  String _section = 'Inventory';
  int _page = 1;
  String? _status;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'Inventory',
                  label: Text(localizedAdmin(context, 'Inventory')),
                ),
                ButtonSegment(
                  value: 'Orders',
                  label: Text(localizedAdmin(context, 'Orders')),
                ),
                ButtonSegment(
                  value: 'Deliveries',
                  label: Text(localizedAdmin(context, 'Deliveries')),
                ),
              ],
              selected: {_section},
              onSelectionChanged: (selection) =>
                  setState(() => _section = selection.first),
            ),
          ),
        ),
        Expanded(child: _buildSection()),
      ],
    );
  }

  Widget _buildSection() {
    if (_section == 'Inventory') {
      return AdminCollection(
        key: const ValueKey('admin-inventory'),
        title: localizedAdmin(context, 'Inventory'),
        load: () async => _items(await widget.api.get('/admin/inventory')),
        itemBuilder: (context, item, reload) => Card(
          child: ListTile(
            title: Text(_displayName(context, item)),
            subtitle: Text(
              '${localizedAdmin(context, '{quantity} units', {
                    'quantity': item['quantity'] ?? 0,
                  })} · ${localizedStatus(context, _string(item['availability']))}',
            ),
            trailing: IconButton(
              tooltip: localizedAdmin(context, 'Adjust stock'),
              icon: const Icon(Icons.tune),
              onPressed: () async {
                final delta = await _askText(
                  context,
                  title: localizedAdmin(context, 'Adjust stock'),
                  label: localizedAdmin(
                    context,
                    'Change in units (positive or negative)',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    signed: true,
                  ),
                );
                if (!context.mounted || delta == null) return;
                final value = int.tryParse(delta);
                if (value == null || value == 0) {
                  _showTextError(
                    context,
                    localizedAdmin(context, 'Enter a non-zero whole number.'),
                  );
                  return;
                }
                try {
                  await widget.api.post(
                    '/admin/inventory/${Uri.encodeComponent(_string(item['id']))}/adjustments',
                    data: {'quantityDelta': value},
                  );
                  reload();
                } catch (error) {
                  if (context.mounted) _showError(context, widget.api, error);
                }
              },
            ),
          ),
        ),
      );
    }
    if (_section == 'Orders') {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(localizedAdmin(context, 'Status')),
                const SizedBox(width: 12),
                DropdownButton<String?>(
                  value: _status,
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(localizedAdmin(context, 'All')),
                    ),
                    DropdownMenuItem(
                        value: 'payment_pending',
                        child:
                            Text(localizedStatus(context, 'payment_pending'))),
                    DropdownMenuItem(
                      value: 'placed',
                      child: Text(localizedStatus(context, 'placed')),
                    ),
                    DropdownMenuItem(
                      value: 'paid',
                      child: Text(localizedStatus(context, 'paid')),
                    ),
                    DropdownMenuItem(
                      value: 'cancelled',
                      child: Text(localizedStatus(context, 'cancelled')),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _status = value;
                    _page = 1;
                  }),
                ),
                const Spacer(),
                IconButton(
                  tooltip: localizedAdmin(context, 'Previous page'),
                  onPressed: _page > 1 ? () => setState(() => _page--) : null,
                  icon: Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_right
                        : Icons.chevron_left,
                  ),
                ),
                Text('$_page'),
                IconButton(
                  tooltip: localizedAdmin(context, 'Next page'),
                  onPressed: () => setState(() => _page++),
                  icon: Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left
                        : Icons.chevron_right,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: AdminCollection(
              key: ValueKey('orders-$_page-$_status'),
              title: localizedAdmin(context, 'Orders'),
              load: () async => _items(
                await widget.api.get(
                  '/admin/orders',
                  query: {
                    'page': _page,
                    'limit': 20,
                    if (_status != null) 'status': _status!,
                  },
                ),
              ),
              itemBuilder: (context, order, reload) => Card(
                child: ListTile(
                  title: Text(_shortId(order['id'])),
                  subtitle: Text(
                    '${localizedStatus(context, _string(order['status']))} · '
                    '${localizedStatus(context, _string(order['paymentMethod']))}',
                  ),
                  trailing: Text('${order['currency']} ${order['total']}'),
                ),
              ),
            ),
          ),
        ],
      );
    }
    return AdminCollection(
      key: const ValueKey('admin-deliveries'),
      title: localizedAdmin(context, 'Deliveries'),
      load: () async => _items(await widget.api.get('/admin/deliveries')),
      itemBuilder: (context, delivery, reload) {
        final status = _string(delivery['status']);
        final nextStatuses = switch (status) {
          'pending_dispatch' => ['assigned'],
          'assigned' => ['picked_up', 'failed'],
          'picked_up' => ['delivered', 'failed'],
          _ => <String>[],
        };
        return Card(
          child: ListTile(
            title: Text(
              localizedAdmin(
                context,
                'Order {id}',
                {'id': _shortId(delivery['order_id'])},
              ),
            ),
            subtitle: Text(
              '${localizedStatus(context, status)} · ${delivery['estimated_minutes']} ${localizedAdmin(context, 'minutes')}',
            ),
            trailing: nextStatuses.isEmpty
                ? null
                : PopupMenuButton<String>(
                    tooltip: localizedAdmin(context, 'Update delivery'),
                    onSelected: (next) async {
                      try {
                        await widget.api.patch(
                          '/admin/deliveries/${delivery['id']}/status',
                          data: {
                            'status': next,
                            'note': 'Updated from AquaFlow Admin mobile',
                          },
                        );
                        reload();
                      } catch (error) {
                        if (context.mounted) {
                          _showError(context, widget.api, error);
                        }
                      }
                    },
                    itemBuilder: (_) => nextStatuses
                        .map((value) => PopupMenuItem(
                              value: value,
                              child: Text(
                                localizedAdmin(
                                  context,
                                  'Mark {status}',
                                  {
                                    'status': localizedStatus(context, value),
                                  },
                                ),
                              ),
                            ))
                        .toList(),
                  ),
          ),
        );
      },
    );
  }
}

class AdminMoreTab extends StatefulWidget {
  const AdminMoreTab({required this.api, super.key});

  final AdminApi api;

  @override
  State<AdminMoreTab> createState() => _AdminMoreTabState();
}

class _AdminMoreTabState extends State<AdminMoreTab> {
  String _section = 'Promotions';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'Promotions',
                  label: Text(localizedAdmin(context, 'Promotions')),
                ),
                ButtonSegment(
                  value: 'Reviews',
                  label: Text(localizedAdmin(context, 'Reviews')),
                ),
                ButtonSegment(
                  value: 'Locations',
                  label: Text(localizedAdmin(context, 'Cities & zones')),
                ),
              ],
              selected: {_section},
              onSelectionChanged: (selection) =>
                  setState(() => _section = selection.first),
            ),
          ),
        ),
        Expanded(child: _buildSection()),
      ],
    );
  }

  Widget _buildSection() {
    if (_section == 'Promotions') {
      return AdminCollection(
        key: const ValueKey('admin-promotions'),
        title: localizedAdmin(context, 'Promotions'),
        load: () async => _items(await widget.api.get('/admin/promotions')),
        headerBuilder: (context, reload) => Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton.icon(
            onPressed: () => _createPromotion(context, widget.api, reload),
            icon: const Icon(Icons.add),
            label: Text(localizedAdmin(context, 'Create promotion')),
          ),
        ),
        itemBuilder: (context, promotion, reload) => Card(
          child: ListTile(
            title: Text(_string(promotion['code'])),
            subtitle: Text(
              '${localizedAdmin(context, promotion['discount_type'] == 'percentage' ? 'Percentage' : 'Fixed amount')} · '
              '${promotion['discount_value']} · ${promotion['redemption_count']} '
              '${localizedAdmin(context, 'redemptions')}',
            ),
            trailing: Switch(
              value: promotion['is_active'] == true,
              onChanged: (active) async {
                try {
                  await widget.api.patch(
                    '/admin/promotions/${promotion['id']}/active',
                    data: {'isActive': active},
                  );
                  reload();
                } catch (error) {
                  if (context.mounted) _showError(context, widget.api, error);
                }
              },
            ),
          ),
        ),
      );
    }
    if (_section == 'Reviews') {
      return AdminCollection(
        key: const ValueKey('admin-reviews'),
        title: localizedAdmin(context, 'Reviews awaiting moderation'),
        load: () async => _items(await widget.api.get('/admin/reviews')),
        itemBuilder: (context, review, reload) => Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_displayName(context, {
                        'name': review['product_name'],
                        'name_ar': review['product_name_ar'],
                      })} · ${review['rating']}/5',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(_string(review['comment'])),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => _moderate(
                        context,
                        widget.api,
                        review,
                        'approved',
                        reload,
                      ),
                      child: Text(localizedAdmin(context, 'Approve')),
                    ),
                    TextButton(
                      onPressed: () => _moderate(
                        context,
                        widget.api,
                        review,
                        'rejected',
                        reload,
                      ),
                      child: Text(localizedAdmin(context, 'Reject')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    return AdminLocationsTab(api: widget.api);
  }
}

class AdminLocationsTab extends StatefulWidget {
  const AdminLocationsTab({required this.api, super.key});

  final AdminApi api;

  @override
  State<AdminLocationsTab> createState() => _AdminLocationsTabState();
}

class _AdminLocationsTabState extends State<AdminLocationsTab> {
  late Future<Map<String, List<Map<String, dynamic>>>> _locations;

  @override
  void initState() {
    super.initState();
    _locations = _load();
  }

  Future<Map<String, List<Map<String, dynamic>>>> _load() async {
    final results = await Future.wait([
      widget.api.get('/addresses/cities'),
      widget.api.get('/addresses/delivery-zones'),
    ]);
    return {
      'cities': _items(results[0]),
      'zones': _items(results[1]),
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
      future: _locations,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _MessageState(
            message: localizedAdmin(
              context,
              widget.api.errorMessage(snapshot.error!),
            ),
            actionLabel: localizedAdmin(context, 'Retry'),
            onAction: () => setState(() {
              _locations = _load();
            }),
          );
        }
        final data = snapshot.data!;
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _locations = _load();
            });
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                localizedAdmin(context, 'Cities'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (data['cities']!.isEmpty)
                _EmptyState(
                  message: localizedAdmin(context, 'No active cities.'),
                )
              else
                ...data['cities']!.map((city) => Card(
                      child: ListTile(
                        title: Text(_displayName(context, city)),
                        subtitle: Text(
                          '${city['region'] ?? ''} · ${city['countryCode'] ?? ''}',
                        ),
                      ),
                    )),
              const SizedBox(height: 12),
              Text(localizedAdmin(context, 'Delivery zones (read-only)'),
                  style: Theme.of(context).textTheme.titleLarge),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(localizedAdmin(
                  context,
                  'Zone configuration is not editable through the current API.',
                )),
              ),
              if (data['zones']!.isEmpty)
                _EmptyState(
                  message: localizedAdmin(context, 'No active delivery zones.'),
                )
              else
                ...data['zones']!.map((zone) => Card(
                      child: ListTile(
                        title: Text(
                          '${_displayName(context, {
                                'name': zone['city'],
                                'name_ar': zone['city_ar']
                              })} · '
                          '${_displayName(context, zone)}',
                        ),
                        subtitle: Text(
                          '${localizedAdmin(context, 'Standard')} SAR ${zone['baseFee']} · '
                          '${localizedAdmin(context, 'Express')} SAR ${zone['expressFee']} · '
                          '${zone['estimatedMinutes']} ${localizedAdmin(context, 'minutes')}',
                        ),
                      ),
                    )),
            ],
          ),
        );
      },
    );
  }
}

class AdminCollection extends StatefulWidget {
  const AdminCollection({
    required this.title,
    required this.load,
    required this.itemBuilder,
    this.headerBuilder,
    super.key,
  });

  final String title;
  final Future<List<Map<String, dynamic>>> Function() load;
  final Widget Function(
    BuildContext context,
    Map<String, dynamic> item,
    VoidCallback reload,
  ) itemBuilder;
  final Widget Function(BuildContext context, VoidCallback reload)?
      headerBuilder;

  @override
  State<AdminCollection> createState() => _AdminCollectionState();
}

class _AdminCollectionState extends State<AdminCollection> {
  late Future<List<Map<String, dynamic>>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = widget.load();
  }

  void _reload() {
    setState(() {
      _itemsFuture = widget.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _itemsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _MessageState(
            message: localizedAdmin(
              context,
              'Unable to load {section}.',
              {'section': widget.title.toLowerCase()},
            ),
            actionLabel: localizedAdmin(context, 'Retry'),
            onAction: _reload,
          );
        }
        final items = snapshot.data ?? const <Map<String, dynamic>>[];
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            children: [
              if (widget.headerBuilder != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: widget.headerBuilder!(context, _reload),
                ),
              if (items.isEmpty)
                _EmptyState(
                  message: localizedAdmin(
                    context,
                    'No {section} found.',
                    {'section': widget.title.toLowerCase()},
                  ),
                )
              else
                ...items.map(
                  (item) => widget.itemBuilder(context, item, _reload),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.label, this.value);

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 155,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label),
              const SizedBox(height: 8),
              Text(
                _string(value),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(message)),
      );
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ),
        ),
      );
}

Future<void> _createProduct(
  BuildContext context,
  AdminApi api,
  VoidCallback reload,
) async {
  final terms = await api.get('/admin/catalog-terms');
  if (!context.mounted) return;
  final categories = _items(terms, key: 'categories');
  final brands = _items(terms, key: 'brands');
  if (categories.isEmpty || brands.isEmpty) {
    _showTextError(
      context,
      localizedAdmin(
          context, 'Create a category and brand before adding a product.'),
    );
    return;
  }
  final formKey = GlobalKey<FormState>();
  var name = '';
  var nameAr = '';
  var slug = '';
  var price = '';
  String? categoryId;
  String? brandId;
  final created = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(localizedAdmin(context, 'Add product')),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  decoration: InputDecoration(
                    labelText: localizedAdmin(context, 'Name'),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? localizedAdmin(context, 'Required')
                      : null,
                  onSaved: (value) => name = value ?? '',
                ),
                TextFormField(
                  decoration: InputDecoration(
                    labelText:
                        localizedAdmin(context, 'Arabic name (optional)'),
                  ),
                  onSaved: (value) => nameAr = value ?? '',
                ),
                TextFormField(
                  decoration: InputDecoration(
                    labelText: localizedAdmin(
                      context,
                      'Slug (lowercase-hyphenated)',
                    ),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? localizedAdmin(context, 'Required')
                      : null,
                  onSaved: (value) => slug = value ?? '',
                ),
                TextFormField(
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: localizedAdmin(context, 'Price (SAR)'),
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    return parsed == null || parsed <= 0
                        ? localizedAdmin(
                            context,
                            'Enter a price greater than zero.',
                          )
                        : null;
                  },
                  onSaved: (value) => price = value ?? '',
                ),
                DropdownButtonFormField<String>(
                  initialValue: categoryId,
                  decoration: InputDecoration(
                    labelText: localizedAdmin(context, 'Category'),
                  ),
                  items: categories
                      .map((term) => DropdownMenuItem(
                            value: _string(term['id']),
                            child: Text(_displayName(context, term)),
                          ))
                      .toList(),
                  validator: (value) => value == null
                      ? localizedAdmin(context, 'Required')
                      : null,
                  onChanged: (value) =>
                      setDialogState(() => categoryId = value),
                ),
                DropdownButtonFormField<String>(
                  initialValue: brandId,
                  decoration: InputDecoration(
                    labelText: localizedAdmin(context, 'Brand'),
                  ),
                  items: brands
                      .map((term) => DropdownMenuItem(
                            value: _string(term['id']),
                            child: Text(_displayName(context, term)),
                          ))
                      .toList(),
                  validator: (value) => value == null
                      ? localizedAdmin(context, 'Required')
                      : null,
                  onChanged: (value) => setDialogState(() => brandId = value),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(localizedAdmin(context, 'Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              formKey.currentState!.save();
              final parsedPrice = double.parse(price);
              try {
                await api.post(
                  '/admin/products',
                  data: {
                    'name': name.trim(),
                    if (nameAr.trim().isNotEmpty) 'nameAr': nameAr.trim(),
                    'slug': slug.trim(),
                    'categoryId': categoryId,
                    'brandId': brandId,
                    'price': parsedPrice,
                  },
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } catch (error) {
                if (dialogContext.mounted) {
                  _showError(dialogContext, api, error);
                }
              }
            },
            child: Text(localizedAdmin(context, 'Create')),
          ),
        ],
      ),
    ),
  );
  if (created == true) reload();
}

Future<void> _editProduct(
  BuildContext context,
  AdminApi api,
  Map<String, dynamic> product,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _EditProductDialog(api: api, product: product),
  );
}

class _EditProductDialog extends StatefulWidget {
  const _EditProductDialog({
    required this.api,
    required this.product,
  });

  final AdminApi api;
  final Map<String, dynamic> product;

  @override
  State<_EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<_EditProductDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _name = _string(widget.product['name']);
  late String _nameAr =
      _string(widget.product['name_ar'] ?? widget.product['nameAr']);
  late String _slug = _string(widget.product['slug']);
  late String _price = _string(widget.product['price']);
  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    setState(() => _saving = true);
    try {
      await widget.api.patch(
        '/admin/products/${Uri.encodeComponent(_string(widget.product['id']))}',
        data: {
          'name': _name.trim(),
          'nameAr': _nameAr.trim(),
          'slug': _slug.trim(),
          'price': double.parse(_price),
        },
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showError(context, widget.api, error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(localizedAdmin(context, 'Edit details')),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  initialValue: _name,
                  decoration: InputDecoration(
                    labelText: localizedAdmin(context, 'Name'),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? localizedAdmin(context, 'Required')
                      : null,
                  onSaved: (value) => _name = value ?? '',
                ),
                TextFormField(
                  initialValue: _nameAr,
                  decoration: InputDecoration(
                    labelText:
                        localizedAdmin(context, 'Arabic name (optional)'),
                  ),
                  onSaved: (value) => _nameAr = value ?? '',
                ),
                TextFormField(
                  initialValue: _slug,
                  decoration: InputDecoration(
                    labelText: localizedAdmin(context, 'Slug'),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? localizedAdmin(context, 'Required')
                      : null,
                  onSaved: (value) => _slug = value ?? '',
                ),
                TextFormField(
                  initialValue: _price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: localizedAdmin(context, 'Price (SAR)'),
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value ?? '');
                    return parsed == null || parsed <= 0
                        ? localizedAdmin(
                            context, 'Enter a price greater than zero.')
                        : null;
                  },
                  onSaved: (value) => _price = value ?? '',
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(localizedAdmin(context, 'Cancel')),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(localizedAdmin(context, 'Save')),
          ),
        ],
      );
}

Future<void> _editTerm(
  BuildContext context,
  AdminApi api,
  String endpoint,
  VoidCallback reload, {
  Map<String, dynamic>? existing,
}) async {
  final name = TextEditingController(text: _string(existing?['name']));
  final nameAr = TextEditingController(text: _string(existing?['name_ar']));
  final slug = TextEditingController(text: _string(existing?['slug']));
  final created = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        localizedAdmin(
          context,
          existing == null
              ? endpoint == 'categories'
                  ? 'Add category'
                  : 'Add brand'
              : endpoint == 'categories'
                  ? 'Edit category'
                  : 'Edit brand',
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: name,
              decoration: InputDecoration(
                labelText: localizedAdmin(context, 'Name'),
              )),
          TextField(
              controller: nameAr,
              decoration: InputDecoration(
                labelText: localizedAdmin(context, 'Arabic name (optional)'),
              )),
          TextField(
              controller: slug,
              decoration: InputDecoration(
                labelText: localizedAdmin(context, 'Slug'),
              )),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(localizedAdmin(context, 'Cancel')),
        ),
        FilledButton(
          onPressed: () async {
            if (name.text.trim().isEmpty || slug.text.trim().isEmpty) return;
            final data = {
              'name': name.text.trim(),
              'nameAr': nameAr.text.trim().isEmpty ? null : nameAr.text.trim(),
              'slug': slug.text.trim(),
            };
            try {
              if (existing == null) {
                await api.post('/admin/$endpoint', data: data);
              } else {
                await api.patch(
                  '/admin/$endpoint/${Uri.encodeComponent(_string(existing['id']))}',
                  data: data,
                );
              }
              if (dialogContext.mounted) Navigator.pop(dialogContext, true);
            } catch (error) {
              if (dialogContext.mounted) _showError(dialogContext, api, error);
            }
          },
          child: Text(
            localizedAdmin(context, existing == null ? 'Create' : 'Save'),
          ),
        ),
      ],
    ),
  );
  name.dispose();
  nameAr.dispose();
  slug.dispose();
  if (created == true) reload();
}

Future<void> _createPromotion(
  BuildContext context,
  AdminApi api,
  VoidCallback reload,
) async {
  final code = TextEditingController();
  final discount = TextEditingController();
  var type = 'percentage';
  final created = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(localizedAdmin(context, 'Create promotion')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: code,
                decoration: InputDecoration(
                  labelText: localizedAdmin(context, 'Code'),
                )),
            DropdownButtonFormField<String>(
              initialValue: type,
              decoration: InputDecoration(
                labelText: localizedAdmin(context, 'Discount type'),
              ),
              items: [
                DropdownMenuItem(
                  value: 'percentage',
                  child: Text(localizedAdmin(context, 'Percentage')),
                ),
                DropdownMenuItem(
                  value: 'fixed',
                  child: Text(localizedAdmin(context, 'Fixed amount')),
                ),
              ],
              onChanged: (value) => setDialogState(() => type = value ?? type),
            ),
            TextField(
              controller: discount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: localizedAdmin(context, 'Discount value'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(localizedAdmin(context, 'Cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final value = double.tryParse(discount.text);
              if (code.text.trim().isEmpty ||
                  value == null ||
                  value <= 0 ||
                  (type == 'percentage' && value > 100)) {
                return;
              }
              try {
                await api.post(
                  '/admin/promotions',
                  data: {
                    'code': code.text.trim(),
                    'discountType': type,
                    'discountValue': value,
                  },
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              } catch (error) {
                if (dialogContext.mounted) {
                  _showError(dialogContext, api, error);
                }
              }
            },
            child: Text(localizedAdmin(context, 'Create')),
          ),
        ],
      ),
    ),
  );
  code.dispose();
  discount.dispose();
  if (created == true) reload();
}

Future<void> _moderate(
  BuildContext context,
  AdminApi api,
  Map<String, dynamic> review,
  String status,
  VoidCallback reload,
) async {
  try {
    await api.patch(
      '/admin/reviews/${review['id']}/status',
      data: {'status': status},
    );
    reload();
  } catch (error) {
    if (context.mounted) _showError(context, api, error);
  }
}

Future<String?> _askText(
  BuildContext context, {
  required String title,
  required String label,
  String? initialValue,
  TextInputType? keyboardType,
}) async {
  final controller = TextEditingController(text: initialValue);
  final value = await showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(localizedAdmin(context, 'Cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
          child: Text(localizedAdmin(context, 'Save')),
        ),
      ],
    ),
  );
  controller.dispose();
  return value;
}

List<Map<String, dynamic>> _items(
  Map<String, dynamic> response, {
  String key = 'items',
}) {
  final values = response[key];
  if (values is! List) return const [];
  return values.whereType<Map<String, dynamic>>().toList();
}

String _displayName(BuildContext context, Map<String, dynamic> item) {
  final language = Localizations.localeOf(context).languageCode;
  final arabicName = item['name_ar'] ?? item['nameAr'];
  if (language == 'ar' &&
      arabicName is String &&
      arabicName.trim().isNotEmpty) {
    return arabicName;
  }
  return _string(item['name']);
}

String _string(Object? value) => value?.toString() ?? '';

String _shortId(Object? value) {
  final id = _string(value);
  return id.length > 8 ? id.substring(0, 8) : id;
}

void _showError(BuildContext context, AdminApi api, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(localizedAdmin(context, api.errorMessage(error))),
    ),
  );
}

void _showTextError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
