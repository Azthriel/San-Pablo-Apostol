// lib/purchase_page.dart
// ignore_for_file: unused_field

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eventosspa/firestore_service.dart';
import 'package:eventosspa/master.dart';
import 'package:eventosspa/payment_success_page.dart';
import 'package:eventosspa/secret.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class PurchasePage extends StatefulWidget {
  const PurchasePage({super.key});
  @override
  PurchasePageState createState() => PurchasePageState();
}

class PurchasePageState extends State<PurchasePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _buyerController;
  late TextEditingController _sellerController;

  String sellerBranch = 'Manada';
  String _paymentMethod = 'MercadoPago'; // 'MercadoPago' | 'Efectivo'
  Uint8List? _bgImage;
  double docenas = 1.0;
  double? churros;
  List<FlavorSelection> _flavors = [FlavorSelection()];
  bool _loading = false;

  // Precios de Firestore
  double _docPastelitos = 10000;
  double _mdocPastelitos = 6000;
  double _docChurros = 8000;
  double _mdocChurros = 4000;
  bool _pricesLoaded = false;

  final List<String> branches = [
    'Manada',
    'Unidad scout',
    'Caminantes',
    'Rovers',
    'Educadores',
  ];
  final List<String> flavorOptions = ['Membrillo', 'Batata', 'Mixta'];
  final List<String> sizeOptions = ['Docena', 'Media docena'];
  final List<String> typeOptions = ['Tradicional', 'Vegano'];

  int get totalPieces => (docenas * 12).toInt();
  int get selectedPieces =>
      _flavors.fold(0, (s, f) => s + (f.size == 'Docena' ? 12 : 6));
  int get remainingPieces => totalPieces - selectedPieces;

  /// Precio total calculado localmente (indicativo; el server valida)
  double get _total {
    double t = 0;
    for (final f in _flavors) {
      t += f.size == 'Docena' ? _docPastelitos : _mdocPastelitos;
    }
    if (churros != null && churros! > 0) {
      final full = churros!.floor();
      final half = (churros! - full) >= 0.5 ? 1 : 0;
      t += full * _docChurros + half * _mdocChurros;
    }
    return t;
  }

  @override
  void initState() {
    super.initState();
    _buyerController = TextEditingController();
    _sellerController = TextEditingController();
    _loadPrices();
    _loadBg();
  }

  @override
  void dispose() {
    _buyerController.dispose();
    _sellerController.dispose();
    super.dispose();
  }

  Future<void> _loadBg() async {
    _bgImage = (await rootBundle.load('assets/back.png')).buffer.asUint8List();
  }

  Future<void> _loadPrices() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('PASTELITOS')
              .doc('Config')
              .get();
      final d = doc.data() ?? {};
      setState(() {
        _docPastelitos = (d['docPastelitos'] as num? ?? 10000).toDouble();
        _mdocPastelitos = (d['mdocPastelitos'] as num? ?? 6000).toDouble();
        _docChurros = (d['docChurros'] as num? ?? 8000).toDouble();
        _mdocChurros = (d['mdocChurros'] as num? ?? 4000).toDouble();
        _pricesLoaded = true;
      });
    } catch (_) {
      setState(() => _pricesLoaded = true);
    }
  }

  String _docenaLabel(double val) {
    final i = val.floor();
    final half = (val - i) >= 0.5;
    if (half && i > 0) return '$i ½ docenas';
    if (half && i == 0) return '½ docena';
    return '$i ${i == 1 ? 'docena' : 'docenas'}';
  }

  String _currency(double val) =>
      '\$${val.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}';

  void _addFlavor() {
    if (remainingPieces >= 6) {
      setState(
        () => _flavors.add(
          FlavorSelection(
            size: remainingPieces >= 12 ? 'Docena' : 'Media docena',
          ),
        ),
      );
    }
  }

  Future<void> _handleCash() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedPieces != totalPieces) return;
    setState(() => _loading = true);

    try {
      final order = {
        'buyerName': _buyerController.text.trim(),
        'sellerName': _sellerController.text.trim(),
        'sellerBranch': sellerBranch,
        'paymentMethod': 'Efectivo',
        'paid': false,
        'docenas': docenas,
        'churros': 0.0,
        'flavors':
            _flavors
                .map(
                  (f) => {'flavor': f.flavor, 'size': f.size, 'type': f.type},
                )
                .toList(),
      };

      final orderId = await FirestoreService.addOrder(order);

      if (!mounted) return;

      // Navegar al ticket directamente sin pasar por MP
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => PaymentSuccessPage(
                directOrderId: orderId,
                directOrderData: order,
              ),
        ),
      );

      // Resetear form
      _formKey.currentState!.reset();
      _buyerController.clear();
      _sellerController.clear();
      setState(() {
        sellerBranch = branches.first;
        _paymentMethod = 'MercadoPago';
        docenas = 1.0;
        _flavors = [FlavorSelection()];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _removeFlavor(int i) => setState(() => _flavors.removeAt(i));

  Future<void> _handlePay() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedPieces != totalPieces) return;

    setState(() => _loading = true);

    try {
      final orderData = {
        'buyerName': _buyerController.text.trim(),
        'sellerName': _sellerController.text.trim(),
        'sellerBranch': sellerBranch,
        'paymentMethod': 'MercadoPago',
        'paid': false,
        'docenas': docenas,
        'churros': churros ?? 0.0,
        'flavors':
            _flavors
                .map(
                  (f) => {'flavor': f.flavor, 'size': f.size, 'type': f.type},
                )
                .toList(),
      };

      final response = await http.post(
        Uri.parse(preference),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'data': {'orderData': orderData},
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Error en la función de pago: ${response.statusCode} ${response.body}',
        );
      }

      final responseData = jsonDecode(response.body) as Map<String, dynamic>;
      final initPoint = responseData['result']['init_point'] as String? ?? '';

      if (initPoint.isEmpty) throw Exception('No se recibió URL de pago');

      await launchUrl(Uri.parse(initPoint), mode: LaunchMode.platformDefault);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (!_pricesLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Banner ──────────────────────────────────
                Card(
                  color: cs.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.shopping_cart_outlined,
                          color: cs.onPrimaryContainer,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Encargar pastelitos',
                                style: Theme.of(
                                  context,
                                ).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: cs.onPrimaryContainer,
                                ),
                              ),
                              Text(
                                'Pagás directo con MercadoPago 🧉',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: cs.onPrimaryContainer),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Datos personales ─────────────────────────
                _SectionCard(
                  title: 'Tus datos',
                  icon: Icons.person_outline,
                  children: [
                    TextFormField(
                      controller: _buyerController,
                      decoration: const InputDecoration(
                        labelText: 'Tu nombre completo',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator:
                          (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Obligatorio'
                                  : null,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _sellerController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del scout que te vendió',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator:
                          (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Obligatorio'
                                  : null,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    const _FieldLabel(label: 'Rama del scout'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          branches
                              .map(
                                (b) => ChoiceChip(
                                  label: Text(b),
                                  selected: sellerBranch == b,
                                  onSelected:
                                      (_) => setState(() => sellerBranch = b),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Pastelitos ───────────────────────────────
                _SectionCard(
                  title: 'Pastelitos',
                  icon: Icons.cake_outlined,
                  children: [
                    DropdownButtonFormField<double>(
                      decoration: const InputDecoration(
                        labelText: 'Cantidad de docenas',
                        prefixIcon: Icon(Icons.confirmation_number_outlined),
                      ),
                      initialValue: docenas,
                      items: List.generate(10, (i) {
                        final val = (i + 1) * 0.5;
                        return DropdownMenuItem(
                          value: val,
                          child: Text(_docenaLabel(val)),
                        );
                      }),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          docenas = v;
                          _flavors = [
                            FlavorSelection(
                              size: v * 12 >= 12 ? 'Docena' : 'Media docena',
                            ),
                          ];
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Precio referencia pastelitos
                    _PriceHint(
                      label: 'Docena pastelitos',
                      price: _currency(_docPastelitos),
                    ),
                    _PriceHint(
                      label: 'Media docena',
                      price: _currency(_mdocPastelitos),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sabores — ${remainingPieces == 0 ? '¡Completo!' : 'faltan $remainingPieces piezas'}',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                remainingPieces == 0
                                    ? Colors.green.shade100
                                    : cs.primaryContainer.withValues(
                                      alpha: 0.6,
                                    ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$selectedPieces / $totalPieces',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color:
                                  remainingPieces == 0
                                      ? Colors.green.shade700
                                      : cs.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    ...List.generate(_flavors.length, (i) {
                      final f = _flavors[i];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              top: i > 0 ? 16 : 0,
                              bottom: 8,
                            ),
                            child: Row(
                              children: [
                                if (i > 0) const Expanded(child: Divider()),
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: i > 0 ? 8 : 0,
                                    right: 8,
                                  ),
                                  child: Text(
                                    'Docena ${i + 1}',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall?.copyWith(
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (i > 0) const Expanded(child: Divider()),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: f.flavor,
                                  decoration: const InputDecoration(
                                    labelText: 'Sabor',
                                  ),
                                  items:
                                      flavorOptions
                                          .map(
                                            (g) => DropdownMenuItem(
                                              value: g,
                                              child: Text(g),
                                            ),
                                          )
                                          .toList(),
                                  onChanged:
                                      (v) => setState(() => f.flavor = v!),
                                ),
                              ),
                              if (_flavors.length > 1) ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _removeFlavor(i),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: f.size,
                                  decoration: const InputDecoration(
                                    labelText: 'Tamaño',
                                  ),
                                  items:
                                      sizeOptions
                                          .where(
                                            (s) =>
                                                s != 'Docena' ||
                                                remainingPieces >= 12 ||
                                                f.size == 'Docena',
                                          )
                                          .map(
                                            (s) => DropdownMenuItem(
                                              value: s,
                                              child: Text(s),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (v) => setState(() => f.size = v!),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  initialValue: f.type,
                                  decoration: const InputDecoration(
                                    labelText: 'Tipo',
                                  ),
                                  items:
                                      typeOptions
                                          .map(
                                            (t) => DropdownMenuItem(
                                              value: t,
                                              child: Text(t),
                                            ),
                                          )
                                          .toList(),
                                  onChanged: (v) => setState(() => f.type = v!),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }),

                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonalIcon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Añadir docena'),
                        onPressed: remainingPieces >= 6 ? _addFlavor : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Forma de pago ────────────────────────
                _SectionCard(
                  title: 'Forma de pago',
                  icon: Icons.payments_outlined,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          ['MercadoPago', 'Efectivo']
                              .map(
                                (m) => ChoiceChip(
                                  label: Text(m),
                                  selected: _paymentMethod == m,
                                  onSelected:
                                      (_) => setState(() => _paymentMethod = m),
                                  avatar: Icon(
                                    m == 'MercadoPago'
                                        ? Icons.credit_card
                                        : Icons.money,
                                    size: 16,
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                    if (_paymentMethod == 'Efectivo')
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.amber.shade300),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: Colors.amber,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'El pedido queda registrado sin pagar. '
                                  'Coordiná el pago con el scout.',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                // ── Resumen de precio ────────────────────────
                if (_total > 0)
                  Card(
                    color: cs.secondaryContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.receipt_outlined,
                            color: cs.onSecondaryContainer,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Total estimado',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyLarge?.copyWith(
                              color: cs.onSecondaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _currency(_total),
                            style: Theme.of(
                              context,
                            ).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: cs.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),

                // ── Botón pago ────────────────────────────────
                _loading
                    ? const Center(child: CircularProgressIndicator())
                    : FilledButton.icon(
                      icon: Icon(
                        _paymentMethod == 'MercadoPago'
                            ? Icons.payment
                            : Icons.check_circle_outline,
                      ),
                      label: Text(
                        _paymentMethod == 'MercadoPago'
                            ? 'Pagar con MercadoPago'
                            : 'Confirmar pedido',
                      ),
                      onPressed:
                          selectedPieces == totalPieces
                              ? (_paymentMethod == 'MercadoPago'
                                  ? _handlePay
                                  : _handleCash)
                              : null,
                      style: FilledButton.styleFrom(
                        backgroundColor:
                            _paymentMethod == 'MercadoPago'
                                ? const Color(0xFF009EE3)
                                : Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceHint extends StatelessWidget {
  final String label;
  final String price;
  const _PriceHint({required this.label, required this.price});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
          ),
          const Spacer(),
          Text(
            price,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade700,
    ),
  );
}