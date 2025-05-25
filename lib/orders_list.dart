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
  // Para mostrar/ocultar filtros
  bool showFilters = false;

  // Filtros de pedido
  String branchFilter = 'Todas';
  String sellerFilter = '';
  String paymentStatusFilter = 'Todos';
  String paymentMethodFilter = 'Todos';
  String deliveryFilter = 'Todos';
  String combinedFilter = 'Todos';

  final _sellerFilterController = TextEditingController();

  // Opciones de filtro
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

  /// Construye una fila de estado (pago o entrega), usando Wrap para evitar overflow
  Widget _buildStatusRow({
    required BuildContext context,
    required String label,
    required Widget action,
    Color? labelColor,
  }) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: labelColor),
        ),
        action,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // stream según tu código original
    final baseStream =
        FirebaseFirestore.instance
            .collection('PASTELITOS')
            .doc('Ordenes')
            .collection('items')
            .orderBy('createdAt', descending: false)
            .snapshots();

    return Column(
      children: [
        // Botón para mostrar/ocultar filtros
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: Icon(showFilters ? Icons.filter_alt_off : Icons.filter_alt),
              label: Text(showFilters ? 'Ocultar filtros' : 'Mostrar filtros'),
              onPressed: () => setState(() => showFilters = !showFilters),
            ),
          ),
        ),

        // Panel de filtros (solo si showFilters == true)
        if (showFilters)
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Filtrar rama
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Filtrar rama',
                      border: OutlineInputBorder(),
                    ),
                    value: branchFilter,
                    items:
                        branches
                            .map(
                              (b) => DropdownMenuItem(value: b, child: Text(b)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => branchFilter = v!),
                  ),
                  const SizedBox(height: 8),
                  // Filtrar vendedor
                  TextField(
                    controller: _sellerFilterController,
                    decoration: InputDecoration(
                      labelText: 'Filtrar vendedor',
                      border: OutlineInputBorder(),
                      suffixIcon:
                          sellerFilter.isNotEmpty
                              ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _sellerFilterController.clear();
                                  setState(() => sellerFilter = '');
                                },
                              )
                              : null,
                    ),
                    onChanged: (v) => setState(() => sellerFilter = v),
                  ),
                  const SizedBox(height: 8),
                  // Filtrar estado de pago
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Filtrar estado de pago',
                      border: OutlineInputBorder(),
                    ),
                    value: paymentStatusFilter,
                    items:
                        paymentStatusOptions
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => paymentStatusFilter = v!),
                  ),
                  const SizedBox(height: 8),
                  // Filtrar método de pago
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Filtrar método de pago',
                      border: OutlineInputBorder(),
                    ),
                    value: paymentMethodFilter,
                    items:
                        paymentMethodsList
                            .map(
                              (m) => DropdownMenuItem(value: m, child: Text(m)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => paymentMethodFilter = v!),
                  ),
                  const SizedBox(height: 8),
                  // Filtrar entrega
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Filtrar entrega',
                      border: OutlineInputBorder(),
                    ),
                    value: deliveryFilter,
                    items:
                        deliveryOptions
                            .map(
                              (d) => DropdownMenuItem(value: d, child: Text(d)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => deliveryFilter = v!),
                  ),
                  const SizedBox(height: 8),
                  // Filtrar combinación (tamaño + sabor [+ tipo])
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Filtrar combinación',
                      border: OutlineInputBorder(),
                    ),
                    value: combinedFilter,
                    items:
                        combinedOptions
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => combinedFilter = v!),
                  ),
                ],
              ),
            ),
          ),

        // ── Lista ───────────────────────────────────────────
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: baseStream,
            builder: (context, snap) {
              if (snap.hasError) return const Center(child: Text('Error'));
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allDocs = snap.data!.docs;
              final totalCount = allDocs.length;
              final filteredDocs =
                  allDocs.where((d) {
                    final o = d.data();
                    // Filtro por rama
                    if (branchFilter != 'Todas' &&
                        o['sellerBranch'] != branchFilter) {
                      return false;
                    }
                    // Filtro por vendedor
                    if (sellerFilter.isNotEmpty &&
                        !o['sellerName'].toString().toLowerCase().contains(
                          sellerFilter.toLowerCase(),
                        )) {
                      return false;
                    }
                    // Filtro por estado de pago
                    final paid = o['paid'] as bool? ?? false;
                    if (paymentStatusFilter == 'Pagados' && !paid) return false;
                    if (paymentStatusFilter == 'No pagados' && paid) {
                      return false;
                    }
                    // Filtro por método de pago
                    if (paymentMethodFilter != 'Todos' &&
                        o['paymentMethod'] != paymentMethodFilter) {
                      return false;
                    }
                    // Filtro por entrega
                    final delivered = o['delivered'] as bool? ?? false;
                    if (deliveryFilter == 'Entregados' && !delivered) {
                      return false;
                    }
                    if (deliveryFilter == 'Pendientes' && delivered) {
                      return false;
                    }
                    // Filtro combinado
                    if (combinedFilter != 'Todos') {
                      final docFlavors =
                          (o['flavors'] as List).cast<Map<String, dynamic>>();
                      final parts = combinedFilter.split(' ');
                      final sizePart = parts[0];
                      if (parts[1].toLowerCase() == 'mixta') {
                        // debe haber más de un sabor
                        if (docFlavors.length < 2) return false;
                        // opcional: verificar tipo si se especifica
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

              final filteredCount = filteredDocs.length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (filteredCount != totalCount) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        '$filteredCount filtradas de $totalCount',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],

                  if (filteredCount == 0)
                    Expanded(child: Center(child: Text('No hay pedidos')))
                  else
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredCount,
                        itemBuilder: (_, i) {
                          final doc = filteredDocs[i];
                          final o = doc.data();
                          final flavors =
                              (o['flavors'] as List)
                                  .cast<Map<String, dynamic>>();
                          final paid = o['paid'] as bool? ?? false;
                          final paidAt = (o['paidAt'] as Timestamp?)?.toDate();
                          final delivered = o['delivered'] as bool? ?? false;
                          final deliveredAt =
                              (o['deliveredAt'] as Timestamp?)?.toDate();
                          final canceled = o['canceled'] as bool? ?? false;
                          final canceledAt =
                              (o['canceledAt'] as Timestamp?)?.toDate();
                          final paymentMethod =
                              o['paymentMethod'] as String? ?? '';

                          return Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Comprador y vendedor
                                  Text(
                                    'Comprador: ${o['buyerName']}',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Vendedor: ${o['sellerName']} (${o['sellerBranch']})',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Método de pago: $paymentMethod',
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 12),
                                  // Docenas
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.confirmation_number,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Docenas: ${o['docenas']}',
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Sabores
                                  Text(
                                    'Sabores:',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  ...flavors.map((f) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        left: 8,
                                        bottom: 4,
                                      ),
                                      child: Text(
                                        '- ${f['flavor']} (${f['size']}, ${f['type']})',
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                      ),
                                    );
                                  }),
                                  const SizedBox(height: 16),
                                  // Cancelación
                                  if (!canceled)
                                    ElevatedButton.icon(
                                      icon: const Icon(
                                        Icons.cancel,
                                        color: Colors.red,
                                      ),
                                      label: const Text('Cancelar pedido'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.black87,
                                        side: const BorderSide(
                                          color: Colors.red,
                                        ),
                                      ),
                                      onPressed: () async {
                                        await FirestoreService.cancelOrder(
                                          doc.id,
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text('Pedido cancelado'),
                                            ),
                                          );
                                        }
                                      },
                                    )
                                  else
                                    Text(
                                      'Cancelado: ${canceledAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(canceledAt) : '—'}',
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  const SizedBox(height: 12),
                                  // Pago
                                  if (!canceled)
                                    _buildStatusRow(
                                      context: context,
                                      label:
                                          'Pagado: ${paidAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(paidAt) : '—'}',
                                      labelColor: Colors.blue,
                                      action:
                                          paid
                                              ? TextButton.icon(
                                                icon: const Icon(Icons.undo),
                                                label: const Text(
                                                  'Deshacer pago',
                                                ),
                                                onPressed: () async {
                                                  await FirestoreService.unmarkPaid(
                                                    doc.id,
                                                  );
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Se deshizo el pago',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                              )
                                              : ElevatedButton.icon(
                                                icon: const Icon(
                                                  Icons.attach_money,
                                                ),
                                                label: const Text(
                                                  'Marcar pagado',
                                                ),
                                                onPressed: () async {
                                                  await FirestoreService.markPaid(
                                                    doc.id,
                                                  );
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Pago registrado ✅',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                    ),
                                  const SizedBox(height: 8),
                                  // Entrega
                                  if (!canceled)
                                    _buildStatusRow(
                                      context: context,
                                      label:
                                          'Entregado: ${deliveredAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(deliveredAt) : '—'}',
                                      labelColor: Colors.green,
                                      action:
                                          delivered
                                              ? TextButton.icon(
                                                icon: const Icon(Icons.undo),
                                                label: const Text(
                                                  'Deshacer entrega',
                                                ),
                                                onPressed: () async {
                                                  await FirestoreService.unmarkDelivered(
                                                    doc.id,
                                                  );
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Se deshizo la entrega',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                              )
                                              : ElevatedButton.icon(
                                                icon: const Icon(Icons.check),
                                                label: const Text(
                                                  'Marcar entregado',
                                                ),
                                                onPressed: () async {
                                                  await FirestoreService.markDelivered(
                                                    doc.id,
                                                  );
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      const SnackBar(
                                                        content: Text(
                                                          'Pedido entregado ✅',
                                                        ),
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                    ),
                                ],
                              ),
                            ),
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
}
