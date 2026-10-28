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
                    localizedAdmin(context, 'Paid order total'),
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
  final Set<String> _adjustingInventory = {};

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
        title: localizedAdmin(context, 'Available stock'),
        load: () async => _items(await widget.api.get('/admin/inventory')),
        headerBuilder: (context, _) => Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            localizedAdmin(
              context,
              'Available stock is reduced when orders are placed. Dispatch quantities and physical stocktakes are not recorded.',
            ),
          ),
        ),
        itemBuilder: (context, item, reload) {
          final productId = _string(item['id']);
          final adjusting = _adjustingInventory.contains(productId);
          return Card(
            child: ListTile(
              title: Text(_displayName(context, item)),
              subtitle: Text(
                '${localizedAdmin(context, '{quantity} units', {
                      'quantity': item['quantity'] ?? 0,
                    })} · ${localizedStatus(context, _string(item['availability']))}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: localizedAdmin(context, 'View stock movements'),
                    icon: const Icon(Icons.history),
                    onPressed: () => _showInventoryMovements(
                      context,
                      widget.api,
                      productId,
                    ),
                  ),
                  IconButton(
                    tooltip: localizedAdmin(context, 'Adjust stock'),
                    icon: adjusting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.tune),
                    onPressed:
                        adjusting ? null : () => _adjustInventory(item, reload),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
    if (_section == 'Orders') {
      return _AdminOrdersView(api: widget.api);
    }
    return _AdminDeliveriesView(api: widget.api);
  }

  Future<void> _adjustInventory(
    Map<String, dynamic> item,
    VoidCallback reload,
  ) async {
    final productId = _string(item['id']);
    if (_adjustingInventory.contains(productId)) return;
    setState(() => _adjustingInventory.add(productId));
    try {
      final delta = await _askText(
        context,
        title: localizedAdmin(context, 'Adjust stock'),
        label: localizedAdmin(
          context,
          'Change in units (positive or negative)',
        ),
        keyboardType: const TextInputType.numberWithOptions(signed: true),
      );
      if (!mounted || delta == null) return;
      final value = int.tryParse(delta);
      if (value == null || value == 0) {
        _showTextError(
          context,
          localizedAdmin(context, 'Enter a non-zero whole number.'),
        );
        return;
      }

      await widget.api.post(
        '/admin/inventory/${Uri.encodeComponent(productId)}/adjustments',
        data: {'quantityDelta': value},
      );
      if (mounted) reload();
      if (mounted) {
        _showNotice(
            context, localizedAdmin(context, 'Stock adjustment saved.'));
      }
    } catch (error) {
      if (mounted) _showError(context, widget.api, error);
    } finally {
      if (mounted) setState(() => _adjustingInventory.remove(productId));
    }
  }
}

class _AdminOrdersView extends StatefulWidget {
  const _AdminOrdersView({required this.api});

  final AdminApi api;

  @override
  State<_AdminOrdersView> createState() => _AdminOrdersViewState();
}

class _AdminOrdersViewState extends State<_AdminOrdersView> {
  static const _pageSize = 20;

  int _page = 1;
  String? _status;
  String _search = '';
  late Future<Map<String, dynamic>> _orders;

  @override
  void initState() {
    super.initState();
    _orders = _load();
  }

  Future<Map<String, dynamic>> _load() => widget.api.get(
        '/admin/orders',
        query: {
          'page': _page,
          'limit': _pageSize,
          if (_status != null) 'status': _status!,
        },
      );

  Future<void> _refresh() async {
    final request = _load();
    setState(() => _orders = request);
    await request;
  }

  void _changeStatus(String? value) {
    setState(() {
      _status = value;
      _page = 1;
      _orders = _load();
    });
  }

  void _changePage(int value) {
    setState(() {
      _page = value;
      _orders = _load();
    });
  }

  Future<void> _openOrder(
    BuildContext context,
    String orderId,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminOrderDetailsScreen(
          api: widget.api,
          orderId: orderId,
          onUpdated: _refresh,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _orders,
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
            onAction: () => setState(() => _orders = _load()),
          );
        }

        final response = snapshot.data!;
        final orders = _items(response);
        final total = _integer(response['total']);
        final pageCount = total == 0 ? 1 : (total / _pageSize).ceil();
        final searchTerm = _search.trim().toLowerCase();
        final filtered = orders.where((order) {
          final values = [
            order['id'],
            order['customerId'],
            order['customerName'],
            order['status'],
            order['deliveryStatus'],
            order['paymentMethod'],
          ];
          return values.any(
            (value) => _string(value).toLowerCase().contains(searchTerm),
          );
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    localizedAdmin(context, '{count} results', {
                      'count': total,
                    }),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DropdownButton<String?>(
                        value: _status,
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(localizedAdmin(context, 'All')),
                          ),
                          for (final status in [
                            'payment_pending',
                            'placed',
                            'paid',
                            'cancelled',
                          ])
                            DropdownMenuItem(
                              value: status,
                              child: Text(localizedStatus(context, status)),
                            ),
                        ],
                        onChanged: _changeStatus,
                      ),
                      SizedBox(
                        width: 220,
                        child: TextField(
                          decoration: InputDecoration(
                            labelText:
                                localizedAdmin(context, 'Search current page'),
                            prefixIcon: const Icon(Icons.search),
                            isDense: true,
                          ),
                          onChanged: (value) => setState(() => _search = value),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (filtered.isEmpty)
                      _EmptyState(
                        message: localizedAdmin(
                          context,
                          orders.isEmpty
                              ? 'No orders found.'
                              : 'No matching results.',
                        ),
                      )
                    else
                      ...filtered.map((order) {
                        final id = _string(order['id']);
                        final createdAt =
                            DateTime.tryParse(_string(order['createdAt']));
                        return Card(
                          child: ListTile(
                            onTap: id.isEmpty
                                ? null
                                : () => _openOrder(context, id),
                            title: Text(
                              localizedAdmin(context, 'Order {id}', {
                                'id': _shortId(id),
                              }),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${localizedAdmin(context, 'Order status')}: '
                                    '${localizedStatus(context, _string(order['status']))}',
                                  ),
                                  Text(
                                    '${localizedAdmin(context, 'Delivery status')}: '
                                    '${order['deliveryStatus'] == null ? localizedAdmin(context, 'No delivery record') : localizedStatus(context, _string(order['deliveryStatus']))}',
                                  ),
                                  Text(
                                    '${localizedAdmin(context, 'Customer')}: '
                                    '${_string(order['customerName']).trim().isEmpty ? localizedAdmin(context, 'Customer name unavailable') : _string(order['customerName'])}',
                                  ),
                                  Text(
                                    '${localizedAdmin(context, 'Customer ID')}: '
                                    '${_shortId(order['customerId'])}',
                                  ),
                                  Text(
                                    '${localizedAdmin(context, 'Payment method')}: '
                                    '${localizedStatus(context, _string(order['paymentMethod']))}',
                                  ),
                                  if (createdAt != null)
                                    Text(
                                      MaterialLocalizations.of(context)
                                          .formatMediumDate(
                                              createdAt.toLocal()),
                                    ),
                                ],
                              ),
                            ),
                            isThreeLine: true,
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${_string(order['currency'])} ${order['total']}',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const Icon(Icons.chevron_right, size: 18),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: localizedAdmin(context, 'Previous page'),
                    onPressed: _page > 1 ? () => _changePage(_page - 1) : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(localizedAdmin(context, 'Page {page} of {total}', {
                    'page': _page,
                    'total': pageCount,
                  })),
                  IconButton(
                    tooltip: localizedAdmin(context, 'Next page'),
                    onPressed:
                        _page < pageCount ? () => _changePage(_page + 1) : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AdminDeliveriesView extends StatefulWidget {
  const _AdminDeliveriesView({required this.api});

  final AdminApi api;

  @override
  State<_AdminDeliveriesView> createState() => _AdminDeliveriesViewState();
}

class _AdminDeliveriesViewState extends State<_AdminDeliveriesView> {
  String? _status;
  String _search = '';
  late Future<List<Map<String, dynamic>>> _deliveries;

  @override
  void initState() {
    super.initState();
    _deliveries = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async =>
      _items(await widget.api.get('/admin/deliveries'));

  Future<void> _refresh() async {
    final request = _load();
    setState(() => _deliveries = request);
    await request;
  }

  Future<void> _openOrder(String orderId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminOrderDetailsScreen(
          api: widget.api,
          orderId: orderId,
          onUpdated: _refresh,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _deliveries,
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
            onAction: () => setState(() => _deliveries = _load()),
          );
        }

        final deliveries = snapshot.data ?? const <Map<String, dynamic>>[];
        final searchTerm = _search.trim().toLowerCase();
        final filtered = deliveries.where((delivery) {
          final matchesStatus =
              _status == null || delivery['status'] == _status;
          final matchesSearch = [
            delivery['order_id'],
            delivery['status'],
          ].any(
            (value) => _string(value).toLowerCase().contains(searchTerm),
          );
          return matchesStatus && matchesSearch;
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    localizedAdmin(context, '{count} results', {
                      'count': filtered.length,
                    }),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DropdownButton<String?>(
                        value: _status,
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(localizedAdmin(context, 'All')),
                          ),
                          for (final status in [
                            'pending_dispatch',
                            'assigned',
                            'picked_up',
                            'delivered',
                            'failed',
                            'cancelled',
                          ])
                            DropdownMenuItem(
                              value: status,
                              child: Text(localizedStatus(context, status)),
                            ),
                        ],
                        onChanged: (value) => setState(() => _status = value),
                      ),
                      SizedBox(
                        width: 220,
                        child: TextField(
                          decoration: InputDecoration(
                            labelText:
                                localizedAdmin(context, 'Search current page'),
                            prefixIcon: const Icon(Icons.search),
                            isDense: true,
                          ),
                          onChanged: (value) => setState(() => _search = value),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  children: [
                    if (filtered.isEmpty)
                      _EmptyState(
                        message: localizedAdmin(
                          context,
                          deliveries.isEmpty
                              ? 'No deliveries found.'
                              : 'No matching results.',
                        ),
                      )
                    else
                      ...filtered.map((delivery) {
                        final orderId = _string(delivery['order_id']);
                        return Card(
                          child: ListTile(
                            onTap: orderId.isEmpty
                                ? null
                                : () => _openOrder(orderId),
                            title: Text(
                              localizedAdmin(context, 'Order {id}', {
                                'id': _shortId(orderId),
                              }),
                            ),
                            subtitle: Text(
                              '${localizedStatus(context, _string(delivery['status']))} · '
                              '${delivery['estimated_minutes']} ${localizedAdmin(context, 'minutes')}',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class AdminOrderDetailsScreen extends StatefulWidget {
  const AdminOrderDetailsScreen({
    required this.api,
    required this.orderId,
    this.onUpdated,
    super.key,
  });

  final AdminApi api;
  final String orderId;
  final Future<void> Function()? onUpdated;

  @override
  State<AdminOrderDetailsScreen> createState() =>
      _AdminOrderDetailsScreenState();
}

class _AdminOrderDetailsScreenState extends State<AdminOrderDetailsScreen> {
  late Future<Map<String, dynamic>> _details;
  Map<String, dynamic>? _loadedOrder;
  String? _refreshError;
  bool _updatingDelivery = false;

  @override
  void initState() {
    super.initState();
    _details = _load().then((order) {
      _loadedOrder = order;
      return order;
    });
  }

  Future<Map<String, dynamic>> _load() => widget.api.get(
        '/admin/orders/${Uri.encodeComponent(widget.orderId)}',
      );

  Future<void> _refresh() async {
    final request = _load();
    setState(() {
      _details = request;
      _refreshError = null;
    });
    try {
      final order = await request;
      if (mounted) setState(() => _loadedOrder = order);
    } catch (error) {
      if (mounted) {
        setState(() => _refreshError = widget.api.errorMessage(error));
      }
    }
  }

  Future<void> _updateDelivery(
    Map<String, dynamic> delivery,
    String nextStatus,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(localizedAdmin(context, 'Update delivery')),
        content: Text(
          localizedAdmin(
              context, 'Confirm delivery status change to {status}?', {
            'status': localizedStatus(context, nextStatus),
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(localizedAdmin(context, 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(localizedAdmin(context, 'Confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _updatingDelivery = true);
    try {
      final updated = await widget.api.patch(
        '/admin/deliveries/${Uri.encodeComponent(_string(delivery['id']))}/status',
        data: {
          'status': nextStatus,
          'note': localizedAdmin(context, 'Updated from AquaFlow Admin mobile'),
        },
      );
      final persistedStatus = _string(updated['status']);
      if (persistedStatus.isEmpty) {
        throw StateError(
            'The server did not return the updated delivery status.');
      }
      final order = _loadedOrder;
      if (order != null) {
        final currentDelivery =
            Map<String, dynamic>.from(_map(order['delivery']));
        currentDelivery['status'] = persistedStatus;
        setState(() {
          _loadedOrder = {...order, 'delivery': currentDelivery};
          _refreshError = null;
        });
      }
      _showNotice(context, localizedAdmin(context, 'Delivery status updated.'));
    } catch (error) {
      if (mounted) _showError(context, widget.api, error);
      if (mounted) setState(() => _updatingDelivery = false);
      return;
    }

    try {
      await _refresh();
      await widget.onUpdated?.call();
      if (mounted && _refreshError != null) {
        _showNotice(
          context,
          '${localizedAdmin(context, 'Delivery status saved, but the latest data could not be refreshed.')} '
          '$_refreshError',
        );
      }
    } catch (error) {
      if (mounted) {
        _showNotice(
          context,
          '${localizedAdmin(context, 'Delivery status saved, but the latest data could not be refreshed.')} '
          '${widget.api.errorMessage(error)}',
        );
      }
    } finally {
      if (mounted) setState(() => _updatingDelivery = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(localizedAdmin(context, 'Order details')),
        actions: const [LanguageSwitch()],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _details,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            if (_loadedOrder == null) {
              return const Center(child: CircularProgressIndicator());
            }
          }
          final order = _loadedOrder ?? snapshot.data;
          if (order == null && snapshot.hasError) {
            return _MessageState(
              message: localizedAdmin(
                context,
                widget.api.errorMessage(snapshot.error!),
              ),
              actionLabel: localizedAdmin(context, 'Retry'),
              onAction: () => _refresh(),
            );
          }

          if (order == null)
            return const Center(child: CircularProgressIndicator());
          final customer = _map(order['customer']);
          final summary = _map(order['summary']);
          final payments = _items({'items': order['payments']});
          final delivery = _map(order['delivery']);
          final items = _items({'items': order['items']});
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                if (_refreshError != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '${localizedAdmin(context, 'Refresh failed; saved changes remain applied.')} '
                        '$_refreshError',
                      ),
                    ),
                  ),
                Text(
                  localizedAdmin(context, 'Order {id}', {
                    'id': _shortId(order['id']),
                  }),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      label: Text(
                        '${localizedAdmin(context, 'Order status')}: '
                        '${localizedStatus(context, _string(order['status']))}',
                      ),
                    ),
                    Chip(
                      label: Text(
                        '${localizedAdmin(context, 'Payment')}: '
                        '${localizedStatus(context, _string(order['paymentStatus']))}',
                      ),
                    ),
                  ],
                ),
                _detailsCard(
                  context,
                  'Order information',
                  [
                    _detailLine(context, 'Order number', _string(order['id'])),
                    _detailLine(
                      context,
                      'Payment method',
                      localizedStatus(context, _string(order['paymentMethod'])),
                    ),
                    _detailLine(
                      context,
                      'Delivery option',
                      localizedStatus(
                          context, _string(order['deliveryOption'])),
                    ),
                    _detailLine(
                      context,
                      'Created',
                      _formatDateTime(context, order['createdAt']),
                    ),
                    _detailLine(
                      context,
                      'Last updated',
                      _formatDateTime(context, order['updatedAt']),
                    ),
                    if (order['cancelledAt'] != null)
                      _detailLine(
                        context,
                        'Cancelled',
                        _formatDateTime(context, order['cancelledAt']),
                      ),
                  ],
                ),
                _detailsCard(
                  context,
                  'Customer',
                  [
                    _detailLine(
                      context,
                      'Name',
                      '${_string(customer['firstName'])} ${_string(customer['lastName'])}'
                          .trim(),
                    ),
                    _detailLine(context, 'Email', _string(customer['email'])),
                    _detailLine(context, 'Phone', _string(customer['phone'])),
                  ],
                ),
                _detailsCard(
                  context,
                  'Order items',
                  items.isEmpty
                      ? [Text(localizedAdmin(context, 'No order items found.'))]
                      : items
                          .map((item) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(_displayName(context, item)),
                                subtitle: Text(
                                  '${localizedAdmin(context, 'Quantity')}: ${item['quantity']} · '
                                  '${_string(summary['currency'])} ${item['unitPrice']}',
                                ),
                                trailing: Text(
                                  '${_string(summary['currency'])} ${item['lineTotal']}',
                                ),
                              ))
                          .toList(),
                ),
                _detailsCard(
                  context,
                  'Totals',
                  [
                    _detailLine(
                        context, 'Subtotal', _money(summary, 'subtotal')),
                    _detailLine(
                        context, 'Discount', _money(summary, 'discount')),
                    if (summary['promotionCode'] != null)
                      _detailLine(
                        context,
                        'Promotion',
                        _string(summary['promotionCode']),
                      ),
                    _detailLine(
                      context,
                      'Delivery fee',
                      _money(summary, 'deliveryFee'),
                    ),
                    _detailLine(
                        context, 'Service fee', _money(summary, 'serviceFee')),
                    _detailLine(context, 'Total', _money(summary, 'total')),
                  ],
                ),
                _detailsCard(
                  context,
                  'Delivery address',
                  _snapshotLines(context, order['address']),
                ),
                _detailsCard(
                  context,
                  'Delivery zone',
                  _snapshotLines(context, order['deliveryZone']),
                ),
                _detailsCard(
                  context,
                  'Payment information',
                  payments.isEmpty
                      ? [Text(localizedAdmin(context, 'No payment record.'))]
                      : payments
                          .map((payment) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _detailLine(
                                    context,
                                    'Provider',
                                    _string(payment['provider']),
                                  ),
                                  _detailLine(
                                    context,
                                    'Status',
                                    localizedStatus(
                                      context,
                                      _string(payment['status']),
                                    ),
                                  ),
                                  _detailLine(
                                    context,
                                    'Amount',
                                    '${_string(payment['currency'])} ${payment['amount']}',
                                  ),
                                  _detailLine(
                                    context,
                                    'Created',
                                    _formatDateTime(
                                        context, payment['createdAt']),
                                  ),
                                  if (payment['failureCode'] != null)
                                    _detailLine(
                                      context,
                                      'Failure code',
                                      _string(payment['failureCode']),
                                    ),
                                  const Divider(),
                                ],
                              ))
                          .toList(),
                ),
                if (order['statusHistory'] == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      localizedAdmin(
                        context,
                        'Order status history is not available in the current API.',
                      ),
                    ),
                  ),
                if (delivery.isNotEmpty) _deliveryDetails(context, delivery),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _deliveryDetails(
    BuildContext context,
    Map<String, dynamic> delivery,
  ) {
    final status = _string(delivery['status']);
    final nextStatuses = switch (status) {
      'pending_dispatch' => ['assigned'],
      'assigned' => ['picked_up', 'failed'],
      'picked_up' => ['delivered', 'failed'],
      _ => <String>[],
    };
    final events = _items({'items': delivery['events']});
    return _detailsCard(
      context,
      'Delivery details',
      [
        _detailLine(
          context,
          'Delivery status',
          localizedStatus(context, status),
        ),
        _detailLine(
          context,
          'Tracking code',
          _string(delivery['trackingCode']),
        ),
        _detailLine(
          context,
          'Estimated delivery',
          '${delivery['estimatedMinutes']} ${localizedAdmin(context, 'minutes')}',
        ),
        _detailLine(
          context,
          'Delivered at',
          _formatDateTime(context, delivery['deliveredAt']),
        ),
        if (events.isNotEmpty) ...[
          const Divider(),
          Text(
            localizedAdmin(context, 'Delivery history'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          ...events.map((event) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(localizedStatus(
                  context,
                  _string(event['status']),
                )),
                subtitle: Text(
                  '${_string(event['note'])}\n'
                  '${_formatDateTime(context, event['createdAt'])}',
                ),
              )),
        ],
        if (nextStatuses.isNotEmpty) ...[
          const Divider(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final next in nextStatuses)
                FilledButton.tonal(
                  onPressed: _updatingDelivery
                      ? null
                      : () => _updateDelivery(delivery, next),
                  child: Text(localizedAdmin(
                    context,
                    'Mark {status}',
                    {'status': localizedStatus(context, next)},
                  )),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

Widget _detailsCard(
  BuildContext context,
  String title,
  List<Widget> children,
) =>
    Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );

Widget _detailLine(BuildContext context, String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              localizedAdmin(context, label),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );

String _money(Map<String, dynamic> summary, String key) =>
    '${_string(summary['currency'])} ${summary[key]}';

String _formatDateTime(BuildContext context, Object? value) {
  final date = DateTime.tryParse(_string(value));
  if (date == null) return '—';
  return '${MaterialLocalizations.of(context).formatFullDate(date.toLocal())} '
      '${TimeOfDay.fromDateTime(date.toLocal()).format(context)}';
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : <String, dynamic>{};

int _integer(Object? value) =>
    value is num ? value.toInt() : int.tryParse(_string(value)) ?? 0;

List<Widget> _snapshotLines(BuildContext context, Object? value) {
  final snapshot = _map(value);
  const labels = <String, String>{
    'recipientName': 'Recipient',
    'recipient_name': 'Recipient',
    'phone': 'Phone',
    'city': 'City',
    'district': 'District',
    'street': 'Street',
    'building': 'Building',
    'apartment': 'Apartment',
    'floor': 'Floor',
    'notes': 'Notes',
    'name': 'Name',
    'baseFee': 'Base fee',
    'base_fee': 'Base fee',
    'expressFee': 'Express fee',
    'express_fee': 'Express fee',
    'estimatedMinutes': 'Estimated delivery',
    'estimated_minutes': 'Estimated delivery',
    'label': 'Address label',
  };
  return snapshot.entries
      .where((entry) => labels.containsKey(entry.key) && entry.value != null)
      .map((entry) => _detailLine(
            context,
            labels[entry.key]!,
            _string(entry.value),
          ))
      .toList();
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
    if (!mounted) return;
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

Future<void> _showInventoryMovements(
  BuildContext context,
  AdminApi api,
  String productId,
) async {
  final request = api.get(
    '/admin/inventory/${Uri.encodeComponent(productId)}/movements',
  );
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(localizedAdmin(dialogContext, 'Stock movement history')),
      content: SizedBox(
        width: 420,
        height: 360,
        child: FutureBuilder<Map<String, dynamic>>(
          future: request,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return Center(
                child: Text(
                  localizedAdmin(context, 'Loading stock movements…'),
                ),
              );
            }
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  localizedAdmin(
                    context,
                    api.errorMessage(snapshot.error!),
                  ),
                ),
              );
            }
            final movements = _items(_map(snapshot.data));
            if (movements.isEmpty) {
              return Center(
                child: Text(
                  localizedAdmin(context, 'No stock movements recorded.'),
                ),
              );
            }
            return ListView.builder(
              itemCount: movements.length,
              itemBuilder: (context, index) {
                final movement = movements[index];
                final reason = switch (_string(movement['reason'])) {
                  'order_reserved' => 'Reserved for an order',
                  'order_cancelled' => 'Released after order cancellation',
                  _ => 'Administrator adjustment',
                };
                final createdAt =
                    DateTime.tryParse(_string(movement['createdAt']));
                final delta = _integer(movement['quantityDelta']);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${delta > 0 ? '+' : ''}$delta · '
                    '${localizedAdmin(context, reason)}',
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (createdAt != null)
                        Text(
                          MaterialLocalizations.of(context)
                              .formatMediumDate(createdAt.toLocal()),
                        ),
                      if (movement['orderId'] != null)
                        Text(
                          '${localizedAdmin(context, 'Order number')}: '
                          '${_shortId(movement['orderId'])}',
                        ),
                      if (movement['adminId'] != null)
                        Text(
                          '${localizedAdmin(context, 'Administrator ID')}: '
                          '${_shortId(movement['adminId'])}',
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(localizedAdmin(dialogContext, 'Close')),
        ),
      ],
    ),
  );
}

void _showError(BuildContext context, AdminApi api, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(localizedAdmin(context, api.errorMessage(error))),
    ),
  );
}

void _showNotice(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

void _showTextError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}
