// main.dart
import 'package:eventosspa/firebase_options.dart';
import 'package:eventosspa/master.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (kIsWeb) {
    SemanticsBinding.instance.ensureSemantics();
  }
  runApp(const EventosSPA());
}

class EventosSPA extends StatelessWidget {
  const EventosSPA({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'San Pablo Apóstol',
      theme: ThemeData(primarySwatch: Colors.deepPurple),

      initialRoute: '/',
      routes: {
        '/': (context) => const HomePage(),
        '/tesoreria': (context) => const TesoreriaPage(),
      },
      debugShowCheckedModeBanner: false,
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
  late String _readerPassword;
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

  /// Carga la contraseña desde Firestore:
  /// colección 'PASTELITOS', documento 'Config', campo 'listPassword'
  Future<void> _loadListPassword() async {
    final doc =
        await FirebaseFirestore.instance
            .collection('PASTELITOS')
            .doc('Config')
            .get();
    final data = doc.data();
    setState(() {
      _listPassword = (data?['listPassword'] as String?) ?? '';
      _readerPassword = (data?['readerPass'] as String?) ?? '';
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
      builder: (context) {
        return AlertDialog(
          title: const Text('Acceso restringido'),
          content: TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Contraseña',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _passwordController.clear();
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_passwordController.text.trim() == _listPassword) {
                  setState(() {
                    _authenticated = true;
                    _currentIndex = 2;
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Autenticación exitosa')),
                  );
                } else if (_passwordController.text.trim() == _readerPassword) {
                  setState(() {
                    _authenticated = true;
                    _currentIndex = 2;
                    readerApproved = true;
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Autenticación exitosa (Lector)'),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contraseña incorrecta')),
                  );
                }
                _passwordController.clear();
              },
              child: const Text('Entrar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Reiniciar pedidos'),
          content: const Text(
            '¿Seguro que deseas eliminar todos los pedidos y reiniciar los totales?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Reiniciar'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await FirestoreService.resetAllOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pedidos y totales reiniciados')),
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
        toolbarHeight: 100,
        titleSpacing: 16,
        title: Image.asset('assets/spa.png', height: 80, fit: BoxFit.contain),
        centerTitle: false,
        actions: [
          if (_currentIndex == 2 && _authenticated) ...[
            IconButton(
              icon: const Icon(Icons.output),
              tooltip: 'Exportar en Excel',
              onPressed: ExcelExporter.exportOrdersToExcel,
            ),
          ],
          if (_currentIndex == 2 && _authenticated && !readerApproved) ...[
            IconButton(
              icon: const Icon(Icons.delete_forever),
              tooltip: 'Reiniciar pedidos',
              onPressed: _confirmReset,
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/tesoreria');
        },
        tooltip: 'Tesorería',
        child: const Icon(Icons.attach_money),
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.shopping_cart),
              onPressed: () => setState(() => _currentIndex = 0),
            ),
            IconButton(
              icon: const Icon(Icons.bar_chart),
              onPressed: () => setState(() => _currentIndex = 1),
            ),
            IconButton(
              icon: const Icon(Icons.list_alt),
              onPressed: () {
                if (_authenticated) {
                  setState(() => _currentIndex = 2);
                } else {
                  _showAuthDialog();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
