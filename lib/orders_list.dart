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
  String branchFilter = 'Todas';
  String sellerFilter = '';
  final _sellerFilterController = TextEditingController();
  final List<String> branches = [
    'Todas',
    'Manada',
    'Unidad scout',
    'Caminantes',
    'Rovers',
    'Educadores',
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
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: labelColor),
        ),
        action,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseStream = FirebaseFirestore.instance
        .collection('PASTELITOS')
        .doc('Ordenes')
        .collection('items')
        .orderBy('createdAt', descending: false)
        .snapshots();

    return Column(
      children: [
        // ── Filtros ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Filtrar rama',
                  border: OutlineInputBorder(),
                ),
                value: branchFilter,
                items: branches
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (v) => setState(() => branchFilter = v!),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _sellerFilterController,
                decoration: InputDecoration(
                  labelText: 'Filtrar vendedor',
                  border: OutlineInputBorder(),
                  suffixIcon: sellerFilter.isNotEmpty
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
            ],
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

              final filteredDocs = snap.data!.docs.where((d) {
                final o = d.data();
                if (branchFilter != 'Todas' &&
                    o['sellerBranch'] != branchFilter) {
                  return false;
                }
                if (sellerFilter.isNotEmpty &&
                    !o['sellerName']
                        .toString()
                        .toLowerCase()
                        .contains(sellerFilter.toLowerCase())) {
                  return false;
                }
                return true;
              }).toList();

              if (filteredDocs.isEmpty) {
                return const Center(child: Text('No hay pedidos'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredDocs.length,
                itemBuilder: (_, i) {
                  final doc = filteredDocs[i];
                  final o = doc.data();
                  final flavors = (o['flavors'] as List).cast<Map<String, dynamic>>();
                  final paid = o['paid'] as bool? ?? false;
                  final paidAt = (o['paidAt'] as Timestamp?)?.toDate();
                  final delivered = o['delivered'] as bool? ?? false;
                  final deliveredAt = (o['deliveredAt'] as Timestamp?)?.toDate();
                  final canceled = o['canceled'] as bool? ?? false;
                  final canceledAt = (o['canceledAt'] as Timestamp?)?.toDate();
                  final paymentMethod = o['paymentMethod'] as String? ?? '';

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
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Vendedor: ${o['sellerName']} (${o['sellerBranch']})',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Método de pago: $paymentMethod',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),

                          const SizedBox(height: 12),
                          // Docenas
                          Row(
                            children: [
                              const Icon(Icons.confirmation_number, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                'Docenas: ${o['docenas']}',
                                style: Theme.of(context).textTheme.bodyMedium,
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
                              padding: const EdgeInsets.only(left: 8, bottom: 4),
                              child: Text(
                                '- ${f['flavor']} (${f['size']}, ${f['type']})',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            );
                          }),

                          const SizedBox(height: 16),
                          // Cancelación
                          if (!canceled)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.cancel, color: Colors.red),
                              label: const Text('Cancelar pedido'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                side: const BorderSide(color: Colors.red),
                              ),
                              onPressed: () async {
                                await FirestoreService.cancelOrder(doc.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
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
                              action: paid
                                  ? TextButton.icon(
                                      icon: const Icon(Icons.undo),
                                      label: const Text('Deshacer pago'),
                                      onPressed: () async {
                                        await FirestoreService.unmarkPaid(doc.id);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content:
                                                  Text('Se deshizo el pago'),
                                            ),
                                          );
                                        }
                                      },
                                    )
                                  : ElevatedButton.icon(
                                      icon: const Icon(Icons.attach_money),
                                      label: const Text('Marcar pagado'),
                                      onPressed: () async {
                                        await FirestoreService.markPaid(doc.id);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content:
                                                  Text('Pago registrado ✅'),
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
                              action: delivered
                                  ? TextButton.icon(
                                      icon: const Icon(Icons.undo),
                                      label: const Text('Deshacer entrega'),
                                      onPressed: () async {
                                        await FirestoreService.unmarkDelivered(
                                            doc.id);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Se deshizo la entrega'),
                                            ),
                                          );
                                        }
                                      },
                                    )
                                  : ElevatedButton.icon(
                                      icon: const Icon(Icons.check),
                                      label: const Text('Marcar entregado'),
                                      onPressed: () async {
                                        await FirestoreService.markDelivered(
                                            doc.id);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                  'Pedido entregado ✅'),
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
              );
            },
          ),
        ),
      ],
    );
  }
}
