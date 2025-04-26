// orders.dart
import 'package:eventosspa/master.dart';
import 'package:eventosspa/firestore_service.dart';
import 'package:flutter/material.dart';

class OrderPage extends StatefulWidget {
  const OrderPage({super.key});

  @override
  OrderPageState createState() => OrderPageState();
}

class OrderPageState extends State<OrderPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _buyerController;
  late TextEditingController _sellerController;

  String sellerBranch = 'Manada';
  String paymentMethod = 'Efectivo';
  String paymentStatus = 'Pendiente'; // NUEVO: si ya pagó o no
  double docenas = 1.0;
  List<FlavorSelection> _flavors = [FlavorSelection()];

  final List<String> branches = [
    'Manada',
    'Unidad scout',
    'Caminantes',
    'Rovers',
    'Educadores',
  ];
  final List<String> paymentOptions = ['Efectivo', 'Transferencia'];
  final List<String> statusOptions = ['Pagado', 'Pendiente']; // NUEVO
  final List<String> flavorOptions = ['Membrillo', 'Batata', 'Mixta'];
  final List<String> sizeOptions = ['Docena', 'Media docena'];
  final List<String> typeOptions = ['Normal', 'Vegano'];

  int get totalPieces => (docenas * 12).toInt();
  int get selectedPieces =>
      _flavors.fold<int>(0, (sum, f) => sum + (f.size == 'Docena' ? 12 : 6));
  int get remainingPieces => totalPieces - selectedPieces;

  @override
  void initState() {
    super.initState();
    _buyerController = TextEditingController();
    _sellerController = TextEditingController();
  }

  @override
  void dispose() {
    _buyerController.dispose();
    _sellerController.dispose();
    super.dispose();
  }

  void _addFlavor() {
    if (remainingPieces >= 6) {
      final defaultSize = remainingPieces >= 12 ? 'Docena' : 'Media docena';
      setState(() {
        _flavors.add(FlavorSelection(size: defaultSize));
      });
    }
  }

  void _removeFlavor(int i) {
    setState(() => _flavors.removeAt(i));
  }

  String _docenaLabel(double val) {
    final intPart = val.floor();
    final isHalf = (val - intPart) >= 0.5;
    if (isHalf && intPart > 0) {
      return '$intPart ½ docenas';
    } else if (isHalf && intPart == 0) {
      return '½ docena';
    } else {
      return '$intPart ${intPart == 1 ? 'docena' : 'docenas'}';
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedPieces != totalPieces) return;

    final order = {
      'buyerName': _buyerController.text.trim(),
      'sellerName': _sellerController.text.trim(),
      'sellerBranch': sellerBranch,
      'paymentMethod': paymentMethod,
      'paid': paymentStatus == 'Pagado', // NUEVO: booleano
      'docenas': docenas,
      'flavors':
          _flavors
              .map((f) => {'flavor': f.flavor, 'size': f.size, 'type': f.type})
              .toList(),
    };

    await FirestoreService.addOrder(order);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Pedido agregado 🎉')));

    _formKey.currentState!.reset();
    _buyerController.clear();
    _sellerController.clear();
    setState(() {
      sellerBranch = branches.first;
      paymentMethod = paymentOptions.first;
      paymentStatus = statusOptions.last; // 'Pendiente'
      docenas = 1.0;
      _flavors = [FlavorSelection()];
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Nombre del comprador
                    TextFormField(
                      controller: _buyerController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del comprador',
                        border: OutlineInputBorder(),
                      ),
                      validator:
                          (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Obligatorio'
                                  : null,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Nombre del vendedor
                    TextFormField(
                      controller: _sellerController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del vendedor',
                        border: OutlineInputBorder(),
                      ),
                      validator:
                          (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Obligatorio'
                                  : null,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Rama del vendedor
                    const Text(
                      'Rama del vendedor',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          branches.map((b) {
                            return ChoiceChip(
                              label: Text(b),
                              selected: sellerBranch == b,
                              onSelected:
                                  (_) => setState(() => sellerBranch = b),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Método de pago
                    const Text(
                      'Método de pago',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          paymentOptions.map((p) {
                            return ChoiceChip(
                              label: Text(p),
                              selected: paymentMethod == p,
                              onSelected:
                                  (_) => setState(() => paymentMethod = p),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Estado de pago
                    const Text(
                      '¿Ya pagó?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          statusOptions.map((s) {
                            return ChoiceChip(
                              label: Text(s),
                              selected: paymentStatus == s,
                              onSelected:
                                  (_) => setState(() => paymentStatus = s),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Cantidad de docenas
                    DropdownButtonFormField<double>(
                      decoration: const InputDecoration(
                        labelText: 'Cantidad de docenas',
                        border: OutlineInputBorder(),
                      ),
                      value: docenas,
                      items: List.generate(10, (index) {
                        final val = (index + 1) * 0.5;
                        return DropdownMenuItem(
                          value: val,
                          child: Text(_docenaLabel(val)),
                        );
                      }),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() {
                          docenas = v;
                          final defaultSize =
                              v * 12 >= 12 ? 'Docena' : 'Media docena';
                          _flavors = [FlavorSelection(size: defaultSize)];
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // Sabores dinámicos
                    Text(
                      'Elige sabores para completar $totalPieces piezas (faltan $remainingPieces)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: List.generate(_flavors.length, (i) {
                        final f = _flavors[i];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Docena #i
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: f.flavor,
                              decoration: InputDecoration(
                                labelText: 'Docena #${i + 1}',
                                border: OutlineInputBorder(),
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
                              onChanged: (v) => setState(() => f.flavor = v!),
                            ),
                            const SizedBox(height: 8),

                            // Tamaño
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: f.size,
                              decoration: const InputDecoration(
                                labelText: 'Tamaño',
                                border: OutlineInputBorder(),
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
                            const SizedBox(height: 8),

                            // Tipo
                            DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: f.type,
                              decoration: const InputDecoration(
                                labelText: 'Tipo',
                                border: OutlineInputBorder(),
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

                            if (_flavors.length > 1)
                              Align(
                                alignment: Alignment.centerRight,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _removeFlavor(i),
                                ),
                              ),
                            if (i < _flavors.length - 1)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: Divider(thickness: 1),
                              ),
                          ],
                        );
                      }),
                    ),

                    const SizedBox(height: 16),
                    // Botón 'Añadir docena'
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Añadir docena'),
                          onPressed: remainingPieces >= 6 ? _addFlavor : null,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    // Botón 'Agregar pedido'
                    ElevatedButton(
                      onPressed:
                          selectedPieces == totalPieces ? _handleSubmit : null,
                      child: const Text('Agregar pedido'),
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
}
