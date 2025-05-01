// totals_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TotalsPage extends StatelessWidget {
  const TotalsPage({super.key});

  /// Convierte un número de docenas en un label, por ejemplo '1 ½ docenas'
  String _docenaLabel(num val) {
    final d = val.toDouble();
    final intPart = d.floor();
    final isHalf = (d - intPart) >= 0.5;
    if (isHalf && intPart > 0) return '$intPart ½ docenas';
    if (isHalf && intPart == 0) return '½ docena';
    return '$intPart ${intPart == 1 ? 'docena' : 'docenas'}';
  }

  /// Construye una tarjeta métrica con título en dos líneas y valor en dos líneas
  Widget _buildMetricCard(
    BuildContext context,
    String label, // ej. 'Membrillo Trad.'
    String value, // ej. '1 ½ docenas'
    IconData icon,
  ) {
    final primary = Theme.of(context).colorScheme.primary;

    // Separar label
    final labelParts = label.split(' ');
    final title1 = labelParts.first;
    final title2 = labelParts.length > 1 ? labelParts.sublist(1).join(' ') : '';

    // Separar valor
    final valueParts = value.split(' ');
    final suffix = valueParts.last; // 'docenas' o 'docena'
    final numberStr = valueParts.sublist(0, valueParts.length - 1).join(' ');

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        child: Row(
          children: [
            Icon(icon, size: 28, color: primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Título en dos líneas
                  Text(
                    title1,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (title2.isNotEmpty)
                    Text(
                      title2,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  const SizedBox(height: 8),
                  // Valor en dos líneas
                  Text(
                    numberStr,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(color: primary, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    suffix,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '📊 Totales de Pastelitos',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // ── Totales generales ──
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('PASTELITOS')
                .doc('Totales')
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Center(child: Text('Error cargando totales'));
              }
              if (!snap.hasData || !snap.data!.exists) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snap.data!.data()!;
              final totalDoc = data['totalDocenas'] as num? ?? 0;
              final membrilloTrad = data['membrilloTrad'] as num? ?? 0;
              final membrilloVeg = data['membrilloVegano'] as num? ?? 0;
              final batataTrad = data['batataTrad'] as num? ?? 0;
              final batataVeg = data['batataVegano'] as num? ?? 0;

              return Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Total general
                      Row(
                        children: [
                          Icon(
                            Icons.auto_stories,
                            size: 36,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Total',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _docenaLabel(totalDoc),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondary),
                          ),
                        ],
                      ),
                      const Divider(height: 32),
                      // Grid de sabores
                      GridView.count(
                        crossAxisCount: 2,
                        childAspectRatio: 0.85,
                        shrinkWrap: true,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _buildMetricCard(
                            context,
                            'Membrillo Trad.',
                            _docenaLabel(membrilloTrad),
                            Icons.food_bank,
                          ),
                          _buildMetricCard(
                            context,
                            'Membrillo Veg.',
                            _docenaLabel(membrilloVeg),
                            Icons.eco,
                          ),
                          _buildMetricCard(
                            context,
                            'Batata Trad.',
                            _docenaLabel(batataTrad),
                            Icons.local_dining,
                          ),
                          _buildMetricCard(
                            context,
                            'Batata Veg.',
                            _docenaLabel(batataVeg),
                            Icons.grass,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 32),
          Text(
            '⌛ Pastelitos por entregar',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // ── Pastelitos pendientes ──
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('PASTELITOS')
                .doc('Ordenes')
                .collection('items')
                .where('delivered', isEqualTo: false)
                .where('canceled', isEqualTo: false)
                .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Center(child: Text('Error cargando pendientes'));
              }
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final pending = snap.data!.docs.fold<num>(
                0,
                (total, doc) => total + (doc.data()['docenas'] as num? ?? 0),
              );
              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 20, horizontal: 16),
                  child: Row(
                    children: [
                      Icon(
                        Icons.hourglass_bottom,
                        size: 36,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      // Valor pendiente en dos líneas
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pending
                                .toDouble()
                                .truncate()
                                .toString() + // si es entero
                                (pending % 1 >= 0.5 ? '½' : ''),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary),
                          ),
                          Text(
                            pending % 1 >= 0.5
                                ? '½ docena'
                                : pending == 1
                                    ? 'docena'
                                    : 'docenas',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
