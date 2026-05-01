// main.dart
import 'package:eventosspa/firebase_options.dart';
import 'package:eventosspa/orders.dart';
import 'package:eventosspa/orders_list.dart';
import 'package:eventosspa/tesoreria_page.dart';
import 'package:eventosspa/totals_page.dart';
import 'package:eventosspa/firestore_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:quarks_version_checker/quarks_version_checker.dart';
import 'package:quarks_footer/quarks_footer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppVersionChecker.instance.start();
  } catch (_) {}
  usePathUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  runApp(const EventosSPA());
}

class EventosSPA extends StatelessWidget {
  const EventosSPA({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'San Pablo Apóstol',
      theme: _buildTheme(),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/tesoreria': (context) => const TesoreriaPage(),
      },
      debugShowCheckedModeBanner: false,
    );
  }

  ThemeData _buildTheme() {
    // Vibrant Emerald base — moderno, bold yet grounded (tendencia 2025-2026)
    final base = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00704A),
      brightness: Brightness.light,
    );

    // Override secondary con amber cálido: complementa al verde y da vida
    final colorScheme = base.copyWith(
      primary: const Color(0xFF006A40),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFB2F0D2),
      onPrimaryContainer: const Color(0xFF00210F),
      secondary: const Color(0xFFD97B0A),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFFFE5BC),
      onSecondaryContainer: const Color(0xFF2C1A00),
      tertiary: const Color(0xFF3A6B9E),
      onTertiary: Colors.white,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF0F5F2),

      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black26,
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 8,
        shadowColor: Colors.black12,
        indicatorColor: colorScheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? colorScheme.primary : Colors.grey.shade500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? colorScheme.primary : Colors.grey.shade400,
            size: 24,
          );
        }),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: const Color(0xFF006A40).withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF5FAF7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        labelStyle: TextStyle(color: Colors.grey.shade600),
        floatingLabelStyle: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        prefixIconColor: WidgetStateColor.resolveWith(
          (states) =>
              states.contains(WidgetState.focused)
                  ? colorScheme.primary
                  : Colors.grey.shade400,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: colorScheme.primaryContainer,
        checkmarkColor: colorScheme.primary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.grey.shade300),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF1A3A2A),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 8,
      ),

      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        space: 1,
        thickness: 1,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  bool _authenticated = false;
  final TextEditingController _passwordController = TextEditingController();
  late String _listPassword;
  bool _loadingPassword = true;

  @override
  void initState() {
    super.initState();
    _loadListPassword();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadListPassword() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('PASTELITOS')
            .doc('Config')
            .get();
    setState(() {
      _listPassword = (doc.data()?['listPassword'] as String?) ?? '';
      _loadingPassword = false;
    });
  }

  Future<void> _showAuthDialog() async {
    if (_loadingPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cargando configuración...')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  color: Theme.of(ctx).colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Text('Acceso restringido'),
              ],
            ),
            content: TextField(
              controller: _passwordController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                prefixIcon: Icon(Icons.key_outlined),
              ),
              onSubmitted: (_) => _checkPassword(ctx),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  _passwordController.clear();
                  Navigator.pop(ctx);
                },
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => _checkPassword(ctx),
                child: const Text('Entrar'),
              ),
            ],
          ),
    );
  }

  void _checkPassword(BuildContext ctx) {
    if (_passwordController.text == _listPassword) {
      setState(() {
        _authenticated = true;
        _currentIndex = 2;
      });
      Navigator.pop(ctx);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Autenticación exitosa')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('❌ Contraseña incorrecta')));
    }
    _passwordController.clear();
  }

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 40,
            ),
            title: const Text('Reiniciar pedidos'),
            content: const Text(
              '¿Seguro? Se eliminarán todos los pedidos y se reiniciarán los totales. Esta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Reiniciar'),
              ),
            ],
          ),
    );
    if (ok == true) {
      await FirestoreService.resetAllOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('🔄 Pedidos y totales reiniciados')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const OrderPage(),
      const TotalsPage(),
      const OrdersListPage(),
    ];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 20,
        title: Image.asset('assets/spa.png', height: 58, fit: BoxFit.contain),
        actions: [
          if (_currentIndex == 2 && _authenticated)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                tooltip: 'Reiniciar pedidos',
                onPressed: _confirmReset,
              ),
            ),
        ],
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (i) {
              if (i == 2 && !_authenticated) {
                _showAuthDialog();
              } else {
                setState(() => _currentIndex = i);
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.shopping_bag_outlined),
                selectedIcon: Icon(Icons.shopping_bag),
                label: 'Pedidos',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart),
                label: 'Totales',
              ),
              NavigationDestination(
                icon: Icon(Icons.list_alt_outlined),
                selectedIcon: Icon(Icons.list_alt),
                label: 'Lista',
              ),
            ],
          ),
          const QuarksFooter(
            backgroundColor: Colors.white,
            textColor: Colors.black,
          ),
        ],
      ),
    );
  }
}
