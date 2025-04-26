// orders_list.dart
// ignore_for_file: library_private_types_in_public_api

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
        // filtros...
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
                items:
                    branches
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
                ),
                onChanged: (v) => setState(() => sellerFilter = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: baseStream,
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('Error al cargar'));
              if (!snap.hasData) {
                return Center(child: CircularProgressIndicator());
              }

              final docs =
                  snap.data!.docs.where((d) {
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
                    return true;
                  }).toList();

              if (docs.isEmpty) return Center(child: Text('No hay pedidos'));

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final doc = docs[i];
                  final o = doc.data();
                  final flavors =
                      (o['flavors'] as List).cast<Map<String, dynamic>>();
                  final paid = o['paid'] as bool? ?? false;
                  final paidAt = (o['paidAt'] as Timestamp?)?.toDate();
                  final delivered = o['delivered'] as bool? ?? false;
                  final deliveredAt =
                      (o['deliveredAt'] as Timestamp?)?.toDate();

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Comprador: ${o['buyerName']}'),
                          Text(
                            'Vendedor: ${o['sellerName']} (${o['sellerBranch']})',
                          ),
                          Text('Docenas: ${o['docenas']}'),
                          const SizedBox(height: 8),
                          const Text(
                            'Sabores:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          ...flavors.map(
                            (f) => Padding(
                              padding: const EdgeInsets.only(left: 8, top: 4),
                              child: Text(
                                '- ${f['flavor']} (${f['size']}, ${f['type']})',
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // pago
                          if (!paid)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.attach_money),
                              label: const Text('Marcar pagado'),
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
                            )
                          else
                            Text(
                              'Pagado: ${paidAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(paidAt) : '—'}',
                              style: const TextStyle(color: Colors.blue),
                            ),

                          const SizedBox(height: 8),
                          // entrega
                          if (!delivered)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check),
                              label: const Text('Marcar entregado'),
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
                            )
                          else
                            Text(
                              'Entregado: ${deliveredAt != null ? DateFormat('dd/MM/yyyy HH:mm').format(deliveredAt) : '—'}',
                              style: const TextStyle(color: Colors.green),
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
