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
  String paymentStatus = 'Pendiente';
  double docenas = 1.0;
  double? churros; // null = sin churros
  List<FlavorSelection> _flavors = [FlavorSelection()];

  final List<String> branches = [
    'Manada',
    'Unidad scout',
    'Caminantes',
    'Rovers',
    'Educadores',
  ];
  final List<String> paymentOptions = ['Efectivo', 'Transferencia'];
  final List<String> statusOptions = ['Pagado', 'Pendiente'];
  final List<String> flavorOptions = ['Membrillo', 'Batata', 'Mixta'];
  final List<String> sizeOptions = ['Docena', 'Media docena'];
  final List<String> typeOptions = ['Tradicional', 'Vegano'];

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

  String _docenaLabel(double val) {
    final intPart = val.floor();
    final isHalf = (val - intPart) >= 0.5;
    if (isHalf && intPart > 0) return '$intPart ½ docenas';
    if (isHalf && intPart == 0) return '½ docena';
    return '$intPart ${intPart == 1 ? 'docena' : 'docenas'}';
  }

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

  void _removeFlavor(int i) => setState(() => _flavors.removeAt(i));

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedPieces != totalPieces) return;

    final order = {
      'buyerName': _buyerController.text.trim(),
      'sellerName': _sellerController.text.trim(),
      'sellerBranch': sellerBranch,
      'paymentMethod': paymentMethod,
      'paid': paymentStatus == 'Pagado',
      'docenas': docenas,
      'churros': churros ?? 0.0,
      'flavors':
          _flavors
              .map((f) => {'flavor': f.flavor, 'size': f.size, 'type': f.type})
              .toList(),
    };

    await FirestoreService.addOrder(order);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('🎉 Pedido agregado')));

    _formKey.currentState!.reset();
    _buyerController.clear();
    _sellerController.clear();
    setState(() {
      sellerBranch = branches.first;
      paymentMethod = paymentOptions.first;
      paymentStatus = statusOptions.last;
      docenas = 1.0;
      churros = null;
      _flavors = [FlavorSelection()];
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
                // ── Datos del pedido ──────────────────────────
                _SectionCard(
                  title: 'Datos del pedido',
                  icon: Icons.person_outline,
                  children: [
                    TextFormField(
                      controller: _buyerController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del comprador',
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
                        labelText: 'Nombre del vendedor',
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
                    const _FieldLabel(label: 'Rama del vendedor'),
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

                // ── Método de pago ────────────────────────────
                _SectionCard(
                  title: 'Método de pago',
                  icon: Icons.payments_outlined,
                  children: [
                    const _FieldLabel(label: 'Forma de pago'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          paymentOptions
                              .map(
                                (p) => ChoiceChip(
                                  label: Text(p),
                                  selected: paymentMethod == p,
                                  onSelected:
                                      (_) => setState(() => paymentMethod = p),
                                ),
                              )
                              .toList(),
                    ),
                    const SizedBox(height: 16),
                    const _FieldLabel(label: '¿Ya pagó?'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          statusOptions
                              .map(
                                (s) => ChoiceChip(
                                  label: Text(s),
                                  selected: paymentStatus == s,
                                  selectedColor:
                                      s == 'Pagado'
                                          ? Colors.green.shade100
                                          : colorScheme.secondaryContainer,
                                  checkmarkColor:
                                      s == 'Pagado'
                                          ? Colors.green.shade700
                                          : colorScheme.secondary,
                                  onSelected:
                                      (_) => setState(() => paymentStatus = s),
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Pastelitos ────────────────────────────────
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
                    const SizedBox(height: 20),

                    // Contador de piezas
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sabores — ${remainingPieces == 0 ? "¡Completo!" : "faltan $remainingPieces piezas"}',
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
                                    : colorScheme.primaryContainer.withValues(
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
                                      : colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Sabores dinámicos
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
                                if (i > 0)
                                  const Expanded(child: Divider())
                                else
                                  const SizedBox.shrink(),
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

                // ── Churros ───────────────────────────────────
                _SectionCard(
                  title: 'Churros (opcional)',
                  icon: Icons.bakery_dining_outlined,
                  children: [
                    // Mismo dropdown que pastelitos — ½ a 5 docenas + "Sin churros"
                    DropdownButtonFormField<double?>(
                      decoration: const InputDecoration(
                        labelText: 'Cantidad de churros',
                        prefixIcon: Icon(Icons.bakery_dining_outlined),
                      ),
                      initialValue: churros,
                      items: [
                        const DropdownMenuItem<double?>(
                          value: null,
                          child: Text('Sin churros'),
                        ),
                        ...List.generate(10, (i) {
                          final val = (i + 1) * 0.5;
                          return DropdownMenuItem<double?>(
                            value: val,
                            child: Text(_docenaLabel(val)),
                          );
                        }),
                      ],
                      onChanged: (v) => setState(() => churros = v),
                    ),
                    if (churros != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer.withValues(
                              alpha: 0.5,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: colorScheme.secondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_docenaLabel(churros!)} de churros agregados al pedido',
                                style: TextStyle(
                                  color: colorScheme.onSecondaryContainer,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 24),

                // ── Botón enviar ─────────────────────────────
                FilledButton.icon(
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Agregar pedido'),
                  onPressed:
                      selectedPieces == totalPieces ? _handleSubmit : null,
                  style: FilledButton.styleFrom(
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
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
      ),
    );
  }
}
