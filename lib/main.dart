// main.dart
import 'package:eventosspa/firebase_options.dart';
import 'package:eventosspa/orders.dart';
import 'package:eventosspa/orders_list.dart';
import 'package:eventosspa/payment_success_page.dart';
import 'package:eventosspa/purchase_page.dart';
import 'package:eventosspa/tesoreria_page.dart';
import 'package:eventosspa/totals_page.dart';
import 'package:eventosspa/firestore_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
      initialRoute: '/ventas',
      onGenerateRoute: (settings) {
        // Parseamos la URL entrante, incluyendo sus parámetros
        final uri = Uri.parse(settings.name ?? '/ventas');

        // Evaluamos solo el "path" (ej: /pago-ok) e ignoramos lo que viene después del "?"
        switch (uri.path) {
          // ── Pública: pantalla de venta (compra de pastelitos) ──────────
          case '/ventas':
            return MaterialPageRoute(
              builder: (_) => const PurchasePage(),
              settings: settings,
            );

          // ── Internas: uso del grupo scout ───────────────────────────────
          case '/pedidos':
            return MaterialPageRoute(
              builder: (_) => const HomePage(initialTab: HomeTab.pedidos),
              settings: settings,
            );
          case '/estadisticas':
            return MaterialPageRoute(
              builder: (_) => const HomePage(initialTab: HomeTab.estadisticas),
              settings: settings,
            );
          case '/lista':
            return MaterialPageRoute(
              builder: (_) => const HomePage(initialTab: HomeTab.lista),
              settings: settings,
            );

          case '/tesoreria':
            return MaterialPageRoute(
              builder: (_) => const TesoreriaPage(),
              settings: settings,
            );
          case '/pago-ok':
          case '/pago-fallido':
          case '/pago-pendiente':
            return MaterialPageRoute(
              builder: (_) => const PaymentSuccessPage(),
              settings: settings,
            );

          // ── Cualquier otra cosa (incluida "/") → venta pública ──────────
          default:
            return MaterialPageRoute(
              builder: (_) => const PurchasePage(),
              settings: const RouteSettings(name: '/ventas'),
            );
        }
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

enum HomeTab { pedidos, estadisticas, lista }

class HomePage extends StatefulWidget {
  final HomeTab initialTab;
  const HomePage({super.key, this.initialTab = HomeTab.estadisticas});
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  late int _currentIndex;
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  String _managementPass = '';
  bool _loadingConfig = true;
  String? _error;

  // 🔧 Acceso único para toda la sección interna (Pedidos/Estadísticas/Lista).
  // Se valida una vez por sesión contra ManagementAuth.granted (en memoria).
  bool get _granted => ManagementAuth.granted;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialTab.index;
    _loadConfig();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = await ConfigCache.getConfig();
    if (!mounted) return;
    setState(() {
      _managementPass = (config['managementPass'] as String?) ?? '';
      _loadingConfig = false;
    });
  }

  void _checkPassword() {
    final entered = _passwordController.text;
    if (_managementPass.isNotEmpty && entered == _managementPass) {
      setState(() {
        ManagementAuth.granted = true;
        _error = null;
      });
    } else {
      setState(() => _error = 'Contraseña incorrecta');
    }
    _passwordController.clear();
  }

  // ── Pantalla de acceso (no es un dialog dismissible: o entrás, o volvés
  //     a /ventas) ──────────────────────────────────────────────────────
  Widget _buildAccessScreen() {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 20,
        title: Image.asset('assets/spa.png', height: 58, fit: BoxFit.contain),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child:
                    _loadingConfig
                        ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        )
                        : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 40,
                              color: cs.primary,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Acceso restringido',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Esta sección es de uso interno del grupo scout.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              obscureText: true,
                              autofocus: true,
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                prefixIcon: const Icon(Icons.key_outlined),
                                errorText: _error,
                              ),
                              onSubmitted: (_) => _checkPassword(),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed:
                                        () => Navigator.of(
                                          context,
                                        ).pushReplacementNamed('/ventas'),
                                    child: const Text('Volver a Ventas'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _checkPassword,
                                    child: const Text('Entrar'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onDestinationSelected(int i) {
    Navigator.of(context).maybePop(); // cierra el drawer si está abierto
    setState(() => _currentIndex = i);
  }

  String _tabTitle(int i) {
    switch (i) {
      case 0:
        return 'Pedidos';
      case 1:
        return 'Estadísticas';
      case 2:
        return 'Lista de pedidos';
      default:
        return 'San Pablo Apóstol';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_granted) return _buildAccessScreen();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 20,
        title: Text(_tabTitle(_currentIndex)),
      ),
      // 🔧 Drawer en vez de NavigationBar fija: el menú no ocupa espacio en
      // pantalla cuando está cerrado (antes AppBar + NavigationBar +
      // footer se comían una franja fija arriba Y abajo en todo momento).
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Image.asset(
                  'assets/spa.png',
                  height: 64,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerLeft,
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _DrawerItem(
                icon: Icons.add_box_outlined,
                selectedIcon: Icons.add_box,
                label: 'Pedidos',
                selected: _currentIndex == 0,
                onTap: () => _onDestinationSelected(0),
              ),
              _DrawerItem(
                icon: Icons.bar_chart_outlined,
                selectedIcon: Icons.bar_chart,
                label: 'Estadísticas',
                selected: _currentIndex == 1,
                onTap: () => _onDestinationSelected(1),
              ),
              _DrawerItem(
                icon: Icons.list_alt_outlined,
                selectedIcon: Icons.list_alt,
                label: 'Lista',
                selected: _currentIndex == 2,
                onTap: () => _onDestinationSelected(2),
              ),
              const Spacer(),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.storefront_outlined, size: 20),
                  title: const Text('Ir a Ventas'),
                  onTap:
                      () =>
                          Navigator.of(context).pushReplacementNamed('/ventas'),
                ),
              ),
            ],
          ),
        ),
      ),
      // 🔧 IndexedStack: las 3 páginas se crean UNA sola vez y se mantienen
      // vivas en memoria. Antes, al cambiar de tab, `pages` se recreaba
      // enterito en cada build() de HomePage → nuevos widgets → nuevas
      // suscripciones a Firestore en cada cambio de tab.
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          OrderPage(), // tab 0 - carga manual de pedidos, interno
          TotalsPage(), // tab 1 - estadísticas
          OrdersListPage(), // tab 2 - lista; reader por defecto, admin via botón
        ],
      ),
      bottomNavigationBar: const QuarksFooter(
        backgroundColor: Colors.white,
        textColor: Colors.black,
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DrawerItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: selected ? cs.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: Icon(
            selected ? selectedIcon : icon,
            color: selected ? cs.primary : Colors.grey.shade600,
          ),
          title: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? cs.primary : Colors.grey.shade800,
            ),
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
