import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import 'api_config.dart';
import 'cart_screen.dart';
import 'customer_api.dart';
import 'favorites_screen.dart';
import 'localization.dart';

class CustomerProfileScreen extends ConsumerStatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  ConsumerState<CustomerProfileScreen> createState() =>
      _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends ConsumerState<CustomerProfileScreen> {
  final _dio = CustomerApi.createDio();
  final _storage = const FlutterSecureStorage();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _phone = TextEditingController();
  final _emailController = TextEditingController();
  String? _email;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _dio.close();
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<Options> _options() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null || token.isEmpty) {
      throw StateError('Sign in is required to view your account.');
    }
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await _dio.get(
        '/auth/profile',
        options: await _options(),
      );
      if (!mounted) return;
      final profile = response.data as Map<String, dynamic>;
      setState(() {
        _firstName.text = profile['firstName']?.toString() ?? '';
        _lastName.text = profile['lastName']?.toString() ?? '';
        _phone.text = profile['phone']?.toString() ?? '';
        _email = profile['email']?.toString();
        _emailController.text = _email ?? '';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = localizedError(context, error);
      });
    }
  }

  Future<void> _save() async {
    if (_firstName.text.trim().isEmpty || _lastName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localized(context, 'Enter your name.'))),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _dio.patch(
        '/auth/profile',
        data: {
          'firstName': _firstName.text.trim(),
          'lastName': _lastName.text.trim(),
          'phone': _phone.text.trim(),
        },
        options: await _options(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(localized(context, 'Profile saved.'))),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedError(context, error))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await CustomerSession.clearTokens();
      ref.invalidate(cartProvider);
      ref.invalidate(favoritesProvider);
      if (mounted) context.go('/login');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localizedError(context, error))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(localized(context, 'Profile')),
        actions: [
          const LanguageSwitch(compact: true),
          IconButton(
            tooltip: localized(context, 'Sign out'),
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _load,
                        child: Text(localized(context, 'Retry')),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextField(
                              controller: _firstName,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: localized(context, 'First name'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _lastName,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: localized(context, 'Last name'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _emailController,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: localized(context, 'Email'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: localized(context, 'Phone'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _saving ? null : _save,
                              child: _saving
                                  ? const CircularProgressIndicator()
                                  : Text(localized(context, 'Save profile')),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _link(
                      context,
                      Icons.location_on_outlined,
                      'Addresses',
                      '/addresses',
                    ),
                    _link(
                      context,
                      Icons.receipt_long_outlined,
                      'Orders',
                      '/orders',
                    ),
                    _link(
                      context,
                      Icons.favorite_border_rounded,
                      'Favorites',
                      '/favorites',
                    ),
                    _link(
                      context,
                      Icons.notifications_none_rounded,
                      'Notifications',
                      '/notifications',
                    ),
                    _link(
                      context,
                      Icons.lock_outline_rounded,
                      'Change password',
                      '/change-password',
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(localized(
                        context,
                        'Notifications are in-app only; preferences are unavailable.',
                      )),
                    ),
                    OutlinedButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(Icons.logout_rounded),
                      label: Text(localized(context, 'Sign out')),
                    ),
                  ],
                ),
    );
  }

  Widget _link(
    BuildContext context,
    IconData icon,
    String title,
    String route,
  ) =>
      Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(localized(context, title)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => context.push(route),
        ),
      );
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _storage = const FlutterSecureStorage();
  final _dio = CustomerApi.createDio();
  bool _showCurrent = false;
  bool _showNext = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _dio.close();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null || token.isEmpty) {
        throw StateError('Sign in is required to change your password.');
      }
      final response = await _dio.patch(
        '/auth/password',
        data: {
          'currentPassword': _current.text,
          'newPassword': _next.text,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final payload = response.data;
      if (payload is! Map ||
          payload['accessToken'] is! String ||
          payload['refreshToken'] is! String) {
        throw const FormatException('Invalid password-change response');
      }
      await _storage.write(
        key: 'auth_token',
        value: payload['accessToken'] as String,
      );
      await _storage.write(
        key: 'refresh_token',
        value: payload['refreshToken'] as String,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(localized(context, 'Password changed.'))),
        );
        context.pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = localizedError(context, error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.length < 8) {
      return localized(context, 'Password must be at least 8 characters');
    }
    if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[^A-Za-z\d]).+$')
        .hasMatch(value)) {
      return localized(
        context,
        'Password must include a letter, number, and symbol',
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(localized(context, 'Change password'))),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextFormField(
                controller: _current,
                obscureText: !_showCurrent,
                decoration: InputDecoration(
                  labelText: localized(context, 'Current password'),
                  suffixIcon: IconButton(
                    onPressed: () =>
                        setState(() => _showCurrent = !_showCurrent),
                    icon: Icon(_showCurrent
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? localized(context, 'Enter your password')
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _next,
                obscureText: !_showNext,
                decoration: InputDecoration(
                  labelText: localized(context, 'New password'),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _showNext = !_showNext),
                    icon: Icon(_showNext
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined),
                  ),
                ),
                validator: _validateNewPassword,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const CircularProgressIndicator()
                    : Text(localized(context, 'Change password')),
              ),
            ],
          ),
        ),
      );
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _password = TextEditingController();
  final _dio = Dio(BaseOptions(baseUrl: apiBaseUrl));
  bool _loading = false;
  bool _sent = false;
  bool _showResetPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _password.dispose();
    _dio.close();
    super.dispose();
  }

  Future<void> _requestCode() async {
    if (_loading ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) {
      setState(() => _error = localized(context, 'Enter a valid email'));
      return;
    }
    await _run(() async {
      await _dio.post(
        '/auth/password-reset/request',
        data: {'email': _email.text.trim()},
      );
      _sent = true;
    });
  }

  Future<void> _resetPassword() async {
    if (_loading) return;
    final value = _password.text;
    if (value.length < 8 ||
        !RegExp(r'^(?=.*[A-Za-z])(?=.*\d)(?=.*[^A-Za-z\d]).+$')
            .hasMatch(value)) {
      setState(() => _error = localized(
            context,
            'Password must include a letter, number, and symbol',
          ));
      return;
    }
    await _run(() async {
      await _dio.post(
        '/auth/password-reset/confirm',
        data: {'token': _token.text.trim(), 'newPassword': value},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(localized(context, 'Password reset complete.'))),
        );
        context.go('/login');
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = localizedError(context, error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(localized(context, 'Forgot password?'))),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: localized(context, 'Email'),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading ? null : _requestCode,
              child: Text(localized(context, 'Send recovery code')),
            ),
            if (_sent) ...[
              const SizedBox(height: 8),
              Text(localized(
                context,
                'If an account matches this email, a recovery code has been sent.',
              )),
              const SizedBox(height: 12),
              TextField(
                controller: _token,
                decoration: InputDecoration(
                  labelText: localized(context, 'Recovery code'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: !_showResetPassword,
                decoration: InputDecoration(
                  labelText: localized(context, 'New password'),
                  suffixIcon: IconButton(
                    tooltip: localized(
                      context,
                      _showResetPassword ? 'Hide password' : 'Show password',
                    ),
                    onPressed: () => setState(
                      () => _showResetPassword = !_showResetPassword,
                    ),
                    icon: Icon(
                      _showResetPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loading ? null : _resetPassword,
                child: Text(localized(context, 'Reset password')),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      );
}
