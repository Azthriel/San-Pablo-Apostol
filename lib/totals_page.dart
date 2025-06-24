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

  /// Construye una tarjeta métrica con título en dos líneas, valor en dos líneas y bolsas necesarias
  Widget _buildMetricCard(
    BuildContext context,
    String label,
    num val,
    IconData icon,
  ) {
    final primary = Theme.of(context).colorScheme.primary;
    final labelParts = label.split(' ');
    final title1 = labelParts.first;
    final title2 = labelParts.length > 1 ? labelParts.sublist(1).join(' ') : '';
    final valueStr = _docenaLabel(val);
    final valueParts = valueStr.split(' ');
    final suffix = valueParts.last;
    final numberStr = valueParts.sublist(0, valueParts.length - 1).join(' ');
    // Calcular bolsas (1 bolsa por cada media docena)
    final bagCount = (val * 2).round();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
        child: Row(
          children: [
            Icon(icon, size: 28, color: primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title1,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (title2.isNotEmpty)
                    Text(
                      title2,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    numberStr,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    suffix,
                    style: Theme.of(
                      context,
                    ).textTheme.titleMedium?.copyWith(color: primary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '🛍️ $bagCount bolsas',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: primary),
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
            '📊 Pastelitos vendidos por el grupo',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Totales generales
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream:
                FirebaseFirestore.instance
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

              // Calcular bolsas totales
              final totalBags = (totalDoc * 2).round();

              return Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // En dispositivos angostos, usar Wrap para evitar overflow
                          if (constraints.maxWidth < 400) {
                            return Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Icon(
                                  Icons.auto_stories,
                                  size: 36,
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                                Text(
                                  'Total',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  _docenaLabel(totalDoc),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                                Text(
                                  '🛍️ $totalBags bolsas',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                                ),
                              ],
                            );
                          }
                          // Pantallas más anchas
                          return Row(
                            children: [
                              Icon(
                                Icons.auto_stories,
                                size: 36,
                                color: Theme.of(context).colorScheme.secondary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Total',
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _docenaLabel(totalDoc),
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Spacer(),
                              Text(
                                '🛍️ $totalBags bolsas',
                                style: Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color:
                                      Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const Divider(height: 32),
                      // Layout responsive para Grid
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final cols = constraints.maxWidth < 600 ? 1 : 2;
                          final aspect =
                              constraints.maxWidth < 600 ? 1.5 : 0.85;
                          return GridView.count(
                            crossAxisCount: cols,
                            childAspectRatio: aspect,
                            shrinkWrap: true,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            physics: const NeverScrollableScrollPhysics(),
                            children: [
                              _buildMetricCard(
                                context,
                                'Membrillo Trad.',
                                membrilloTrad,
                                Icons.food_bank,
                              ),
                              _buildMetricCard(
                                context,
                                'Membrillo Veg.',
                                membrilloVeg,
                                Icons.eco,
                              ),
                              _buildMetricCard(
                                context,
                                'Batata Trad.',
                                batataTrad,
                                Icons.local_dining,
                              ),
                              _buildMetricCard(
                                context,
                                'Batata Veg.',
                                batataVeg,
                                Icons.grass,
                              ),
                            ],
                          );
                        },
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
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Pastelitos pendientes usando Totales.docenasEntregadas
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream:
                FirebaseFirestore.instance
                    .collection('PASTELITOS')
                    .doc('Totales')
                    .snapshots(),
            builder: (context, snap) {
              if (snap.hasError) {
                return const Center(child: Text('Error cargando pendientes'));
              }
              if (!snap.hasData || !snap.data!.exists) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snap.data!.data()!;
              final totalDoc = data['totalDocenas'] as num? ?? 0;
              final delivered = data['docenasEntregadas'] as num? ?? 0;
              final pending = totalDoc - delivered;

              final label = _docenaLabel(pending);
              final parts = label.split(' ');
              final numberStr = parts.sublist(0, parts.length - 1).join(' ');
              final suffix = parts.last;
              // También calculamos bolsas pendientes si hace falta usarlas luego
              final pendingBags = (pending * 2).round();

              return Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 20,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.hourglass_bottom,
                        size: 36,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              numberStr,
                              style: Theme.of(
                                context,
                              ).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Text(
                              suffix,
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            Text(
                              '🛍️ $pendingBags bolsas',
                              style: Theme.of(
                                context,
                              ).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
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
