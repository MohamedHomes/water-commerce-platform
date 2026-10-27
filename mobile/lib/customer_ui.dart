import 'package:flutter/material.dart';

class AquaFlowCustomerTheme {
  static const _ink = Color(0xFF12313D);
  static const _ocean = Color(0xFF087E8B);
  static const _mint = Color(0xFFE7F5F3);

  static ThemeData get theme {
    final scheme = ColorScheme.fromSeed(
      seedColor: _ocean,
      brightness: Brightness.light,
      surface: const Color(0xFFF6F9FA),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme.copyWith(
        primary: _ocean,
        onPrimary: Colors.white,
        secondary: const Color(0xFF28A98B),
        surface: const Color(0xFFF6F9FA),
        onSurface: _ink,
        primaryContainer: _mint,
      ),
      scaffoldBackgroundColor: const Color(0xFFF6F9FA),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF6F9FA),
        foregroundColor: _ink,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: _ink,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE9EFF1)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFDCE7E9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFDCE7E9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _ocean, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(44, 44),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: _mint,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFE2ECEE)),
        ),
        labelStyle: const TextStyle(color: _ink),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE9EFF1),
        space: 20,
        thickness: 1,
      ),
    );
  }
}

class ProductArtwork extends StatelessWidget {
  const ProductArtwork({
    required this.imageUrl,
    this.iconSize = 34,
    this.fit = BoxFit.cover,
    super.key,
  });

  final String? imageUrl;
  final double iconSize;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty || Uri.tryParse(url)?.hasAuthority != true) {
      return _placeholder(context);
    }
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (_, __, ___) => _placeholder(context),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: progress.expectedTotalBytes == null
                  ? null
                  : progress.cumulativeBytesLoaded /
                      progress.expectedTotalBytes!,
            ),
          ),
        );
      },
    );
  }

  Widget _placeholder(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Center(
          child: Icon(
            Icons.water_drop_rounded,
            size: iconSize,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    required this.title,
    this.action,
    this.onAction,
    super.key,
  });

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      );
}
