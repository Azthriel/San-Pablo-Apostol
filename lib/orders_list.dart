// orders_list.dart
import 'package:eventosspa/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class OrdersListPage extends StatefulWidget {
  const OrdersListPage({super.key});
  @override
  _OrdersListPageState createState() => _OrdersListPageState();
}

class _OrdersListPageState extends State<OrdersListPage> {
  bool showFilters = false;

  String branchFilter = 'Todas';
  String sellerFilter = '';
  String paymentStatusFilter = 'Todos';
  String paymentMethodFilter = 'Todos';
  String deliveryFilter = 'Todos';
  String combinedFilter = 'Todos';

  final _sellerFilterController = TextEditingController();

  final List<String> branches = [
    'Todas',
    'Manada',
    'Unidad scout',
    'Caminantes',
    'Rovers',
    'Educadores',
  ];
  final List<String> paymentStatusOptions = ['Todos', 'Pagados', 'No pagados'];
  final List<String> paymentMethodsList = [
    'Todos',
    'Efectivo',
    'Transferencia',
  ];
  final List<String> deliveryOptions = ['Todos', 'Entregados', 'Pendientes'];
  final List<String> combinedOptions = [
    'Todos',
    'Docena batata',
    'Media batata',
    'Docena membrillo',
    'Media membrillo',
    'Docena mixta',
    'Docena batata vegano',
    'Media batata vegano',
    'Docena membrillo vegano',
    'Media membrillo vegano',
    'Docena mixta vegano',
  ];

  @override
  void dispose() {
    _sellerFilterController.dispose();
    super.dispose();
  }

  String _docenaLabel(num val) {
    final d = val.toDouble();
    final intPart = d.floor();
    final isHalf = (d - intPart) >= 0.5;
    if (isHalf && intPart > 0) return '$intPart ½ docenas';
    if (isHalf && intPart == 0) return '½ docena';
    return '$intPart ${intPart == 1 ? 'docena' : 'docenas'}';
  }

  Widget _buildStatusChip(
    bool active,
    String activeLabel,
    String inactiveLabel,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.12) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? color : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: active ? color : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            active ? activeLabel : inactiveLabel,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? color : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseStream =
        FirebaseFirestore.instance
            .collection('PASTELITOS')
            .doc('Ordenes')
            .collection('items')
            .orderBy('createdAt', descending: false)
            .snapshots();

    return Column(
      children: [
        // Botón filtros
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Text(
                'Lista de pedidos',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              FilledButton.tonalIcon(
                icon: Icon(
                  showFilters ? Icons.filter_alt_off : Icons.filter_alt,
                  size: 18,
                ),
                label: Text(showFilters ? 'Ocultar' : 'Filtros'),
                onPressed: () => setState(() => showFilters = !showFilters),
                style: FilledButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),

        // Panel de filtros
        if (showFilters)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFilterRow(
                    children: [
                      _FilterField(
                        label: 'Rama',
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(isDense: true),
                          initialValue: branchFilter,
                          items:
                              branches
                                  .map(
                                    (b) => DropdownMenuItem(
                                      value: b,
                                      child: Text(b),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => setState(() => branchFilter = v!),
                        ),
                      ),
                      _FilterField(
                        label: 'Vendedor',
                        child: TextField(
                          controller: _sellerFilterController,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Buscar...',
                            suffixIcon:
                                sellerFilter.isNotEmpty
                                    ? IconButton(
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () {
                                        _sellerFilterController.clear();
                                        setState(() => sellerFilter = '');
                                      },
                                    )
                                    : null,
                          ),
                          onChanged: (v) => setState(() => sellerFilter = v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildFilterRow(
                    children: [
                      _FilterField(
                        label: 'Estado pago',
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(isDense: true),
                          initialValue: paymentStatusFilter,
                          items:
                              paymentStatusOptions
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (v) => setState(() => paymentStatusFilter = v!),
                        ),
                      ),
                      _FilterField(
                        label: 'Método de pago',
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(isDense: true),
                          initialValue: paymentMethodFilter,
                          items:
                              paymentMethodsList
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(m),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              (v) => setState(() => paymentMethodFilter = v!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildFilterRow(
                    children: [
                      _FilterField(
                        label: 'Entrega',
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(isDense: true),
                          initialValue: deliveryFilter,
                          items:
                              deliveryOptions
                                  .map(
                                    (d) => DropdownMenuItem(
                                      value: d,
                                      child: Text(d),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => setState(() => deliveryFilter = v!),
                        ),
                      ),
                      _FilterField(
                        label: 'Combinación',
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(isDense: true),
                          initialValue: combinedFilter,
                          items:
                              combinedOptions
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => setState(() => combinedFilter = v!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

        // Lista
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: baseStream,
            builder: (context, snap) {
              if (snap.hasError) return const Center(child: Text('Error'));
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allDocs = snap.data!.docs;
              final filteredDocs =
                  allDocs.where((d) {
                    final o = d.data();
                    if (branchFilter != 'Todas' &&
                        o['sellerBranch'] != branchFilter) {
                      return false;
                    }
                    if (sellerFilter.isNotEmpty &&
                        !o['sellerName'].toString().toLowerCase().contains(
                          sellerFilter.toLowerCase(),
                        )) {
                      return false;
                    }
                    final paid = o['paid'] as bool? ?? false;
                    if (paymentStatusFilter == 'Pagados' && !paid) return false;
                    if (paymentStatusFilter == 'No pagados' && paid) {
                      return false;
                    }
                    if (paymentMethodFilter != 'Todos' &&
                        o['paymentMethod'] != paymentMethodFilter) {
                      return false;
                    }
                    final delivered = o['delivered'] as bool? ?? false;
                    if (deliveryFilter == 'Entregados' && !delivered) {
                      return false;
                    }
                    if (deliveryFilter == 'Pendientes' && delivered) {
                      return false;
                    }
                    if (combinedFilter != 'Todos') {
                      final docFlavors =
                          (o['flavors'] as List).cast<Map<String, dynamic>>();
                      final parts = combinedFilter.split(' ');
                      final sizePart = parts[0];
                      if (parts[1].toLowerCase() == 'mixta') {
                        if (docFlavors.length < 2) return false;
                        if (parts.length == 3) {
                          final typePart = parts[2];
                          if (!docFlavors.every((f) => f['type'] == typePart)) {
                            return false;
                          }
                        }
                      } else {
                        final flavorPart = parts[1].toLowerCase();
                        final hasMatch = docFlavors.any((f) {
                          final matchSize = f['size'] == sizePart;
                          final matchFlavor =
                              f['flavor'].toString().toLowerCase() ==
                              flavorPart;
                          final matchType =
                              parts.length == 3
                                  ? f['type'].toString().toLowerCase() ==
                                      parts[2].toLowerCase()
                                  : true;
                          return matchSize && matchFlavor && matchType;
                        });
                        if (!hasMatch) return false;
                      }
                    }
                    return true;
                  }).toList();

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No hay pedidos',
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  if (filteredDocs.length != allDocs.length)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${filteredDocs.length} de ${allDocs.length} pedidos',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // En pantallas anchas mostramos 2 columnas
                        if (constraints.maxWidth > 700) {
                          return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.72,
                                ),
                            itemCount: filteredDocs.length,
                            itemBuilder:
                                (_, i) =>
                                    _buildOrderCard(context, filteredDocs[i]),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filteredDocs.length,
                          separatorBuilder:
                              (_, __) => const SizedBox(height: 12),
                          itemBuilder:
                              (_, i) =>
                                  _buildOrderCard(context, filteredDocs[i]),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final o = doc.data();
    final flavors = (o['flavors'] as List).cast<Map<String, dynamic>>();
    final paid = o['paid'] as bool? ?? false;
    final paidAt = (o['paidAt'] as Timestamp?)?.toDate();
    final delivered = o['delivered'] as bool? ?? false;
    final deliveredAt = (o['deliveredAt'] as Timestamp?)?.toDate();
    final canceled = o['canceled'] as bool? ?? false;
    final canceledAt = (o['canceledAt'] as Timestamp?)?.toDate();
    final paymentMethod = o['paymentMethod'] as String? ?? '';
    final churros = (o['churros'] as num? ?? 0).toDouble();

    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header de la tarjeta
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color:
                  canceled
                      ? Colors.red.shade50
                      : colorScheme.primaryContainer.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o['buyerName'] ?? '',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${o['sellerName']} · ${o['sellerBranch']}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canceled)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Cancelado',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info del pedido
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _InfoChip(
                      icon: Icons.confirmation_number_outlined,
                      label: _docenaLabel(o['docenas'] as num? ?? 0),
                    ),
                    _InfoChip(
                      icon:
                          paymentMethod == 'Efectivo'
                              ? Icons.money
                              : Icons.account_balance_outlined,
                      label: paymentMethod,
                    ),
                    if (churros > 0)
                      _InfoChip(
                        icon: Icons.bakery_dining_outlined,
                        label: 'Churros: ${_docenaLabel(churros)}',
                        color: Colors.brown.shade400,
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                // Sabores
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.cake_outlined,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Sabores',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...flavors.map(
                        (f) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '• ${f['flavor']} (${f['size']}, ${f['type']})',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (!canceled) ...[
                  const SizedBox(height: 12),

                  // Estado pago y entrega
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatusChip(
                          paid,
                          'Pagado',
                          'Sin pagar',
                          Colors.green,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildStatusChip(
                          delivered,
                          'Entregado',
                          'Pendiente',
                          colorScheme.primary,
                        ),
                      ),
                    ],
                  ),

                  // Fechas
                  if (paidAt != null || deliveredAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (paidAt != null)
                            Text(
                              'Pagado: ${DateFormat('dd/MM/yy HH:mm').format(paidAt)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.green.shade700),
                            ),
                          if (deliveredAt != null)
                            Text(
                              'Entregado: ${DateFormat('dd/MM/yy HH:mm').format(deliveredAt)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colorScheme.primary),
                            ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Acciones
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Pago
                      paid
                          ? OutlinedButton.icon(
                            icon: const Icon(Icons.undo, size: 16),
                            label: const Text('Deshacer pago'),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: Colors.grey,
                            ),
                            onPressed: () async {
                              await FirestoreService.unmarkPaid(doc.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Pago deshecho'),
                                  ),
                                );
                              }
                            },
                          )
                          : FilledButton.tonalIcon(
                            icon: const Icon(Icons.attach_money, size: 16),
                            label: const Text('Marcar pagado'),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              backgroundColor: Colors.green.shade50,
                              foregroundColor: Colors.green.shade700,
                            ),
                            onPressed: () async {
                              await FirestoreService.markPaid(doc.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Pago registrado ✅'),
                                  ),
                                );
                              }
                            },
                          ),

                      // Entrega
                      delivered
                          ? OutlinedButton.icon(
                            icon: const Icon(Icons.undo, size: 16),
                            label: const Text('Deshacer entrega'),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              foregroundColor: Colors.grey,
                            ),
                            onPressed: () async {
                              await FirestoreService.unmarkDelivered(doc.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Entrega deshecha'),
                                  ),
                                );
                              }
                            },
                          )
                          : FilledButton.tonalIcon(
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Marcar entregado'),
                            style: FilledButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () async {
                              await FirestoreService.markDelivered(doc.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Pedido entregado ✅'),
                                  ),
                                );
                              }
                            },
                          ),

                      // Cancelar
                      OutlinedButton.icon(
                        icon: const Icon(
                          Icons.cancel_outlined,
                          size: 16,
                          color: Colors.red,
                        ),
                        label: const Text('Cancelar'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        onPressed: () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder:
                                (ctx) => AlertDialog(
                                  title: const Text('Cancelar pedido'),
                                  content: Text(
                                    '¿Cancelar el pedido de ${o['buyerName']}?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed:
                                          () => Navigator.pop(ctx, false),
                                      child: const Text('No'),
                                    ),
                                    FilledButton(
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Cancelar pedido'),
                                    ),
                                  ],
                                ),
                          );
                          if (ok == true) {
                            await FirestoreService.cancelOrder(doc.id);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Pedido cancelado'),
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ] else if (canceledAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Cancelado el ${DateFormat('dd/MM/yy HH:mm').format(canceledAt)}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow({required List<Widget> children}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > 500) {
          return Row(
            children:
                children
                    .map(
                      (c) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: c,
                        ),
                      ),
                    )
                    .toList(),
          );
        }
        return Column(
          children:
              children
                  .map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: c,
                    ),
                  )
                  .toList(),
        );
      },
    );
  }
}

class _FilterField extends StatelessWidget {
  final String label;
  final Widget child;
  const _FilterField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _InfoChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: c),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: c,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
