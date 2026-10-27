import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'cart_screen.dart';
import 'localization.dart';

class CustomerNavigationShell extends ConsumerStatefulWidget {
  const CustomerNavigationShell({
    required this.navigationShell,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<CustomerNavigationShell> createState() =>
      _CustomerNavigationShellState();
}

class _CustomerNavigationShellState
    extends ConsumerState<CustomerNavigationShell> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(cartProvider.notifier).loadCart());
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = ref.watch(
      cartProvider.select(
        (state) => state.items.fold<int>(0, (sum, item) => sum + item.quantity),
      ),
    );
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: CustomerBottomNavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        cartItemCount: itemCount,
        onDestinationSelected: widget.navigationShell.goBranch,
      ),
    );
  }
}

class CustomerBottomNavigationBar extends StatelessWidget {
  const CustomerBottomNavigationBar({
    required this.selectedIndex,
    required this.cartItemCount,
    required this.onDestinationSelected,
    super.key,
  });

  final int selectedIndex;
  final int cartItemCount;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: const Icon(Icons.home_rounded),
              label: localized(context, 'Home'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.grid_view_outlined),
              selectedIcon: const Icon(Icons.grid_view_rounded),
              label: localized(context, 'Categories'),
            ),
            NavigationDestination(
              icon: Badge(
                isLabelVisible: cartItemCount > 0,
                label: Text(cartItemCount > 99 ? '99+' : '$cartItemCount'),
                child: const Icon(Icons.shopping_bag_outlined),
              ),
              selectedIcon: Badge(
                isLabelVisible: cartItemCount > 0,
                label: Text(cartItemCount > 99 ? '99+' : '$cartItemCount'),
                child: const Icon(Icons.shopping_bag_rounded),
              ),
              label: localized(context, 'Cart'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.favorite_border_rounded),
              selectedIcon: const Icon(Icons.favorite_rounded),
              label: localized(context, 'Favorites'),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline_rounded),
              selectedIcon: const Icon(Icons.person_rounded),
              label: localized(context, 'Profile'),
            ),
          ],
        ),
      );
}
