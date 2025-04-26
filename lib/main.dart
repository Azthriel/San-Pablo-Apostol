// main.dart
import 'package:eventosspa/firebase_options.dart';
import 'package:eventosspa/orders.dart';
import 'package:eventosspa/orders_list.dart';
import 'package:eventosspa/totals_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(EventosSPA());
}

class EventosSPA extends StatelessWidget {
  const EventosSPA({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pastelitos San Pablo Apostol',
      theme: ThemeData(primarySwatch: Colors.deepPurple),
      home: HomePage(),
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
  static const String _listPassword = 'LexieChicho2025';

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _showAuthDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Acceso restringido'),
          content: TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: InputDecoration(
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
              child: Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (_passwordController.text == _listPassword) {
                  setState(() {
                    _authenticated = true;
                    _currentIndex = 2;
                  });
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Autenticación exitosa')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Contraseña incorrecta')),
                  );
                }
                _passwordController.clear();
              },
              child: Text('Entrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [OrderPage(), TotalsPage(), OrdersListPage()];

    return Scaffold(
      appBar: AppBar(
        // Aumentamos la altura del AppBar para que el logo pueda mostrarse más grande
        toolbarHeight: 100,
        // Reducimos el padding izquierdo para dejar al logo más cerca del borde
        titleSpacing: 16,
        title: Image.asset(
          'assets/spa.png',
          // Ajustamos la altura del logo
          height: 80,
          fit: BoxFit.contain,
        ),
        centerTitle: false,
      ),
      body: pages[_currentIndex],
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: Icon(Icons.shopping_cart),
              onPressed: () => setState(() => _currentIndex = 0),
            ),
            IconButton(
              icon: Icon(Icons.bar_chart),
              onPressed: () => setState(() => _currentIndex = 1),
            ),
            IconButton(
              icon: Icon(Icons.list_alt),
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
