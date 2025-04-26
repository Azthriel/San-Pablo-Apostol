// totals_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TotalsPage extends StatelessWidget {
  const TotalsPage({super.key});

  // Formatea 0.5 → “½ docena”, 1 → “1 docena”, 1.5 → “1 ½ docenas”, etc.
  String _docenaLabel(num val) {
    final d = val.toDouble();
    final intPart = d.floor();
    final isHalf = (d - intPart) >= 0.5;
    if (isHalf && intPart > 0) {
      return '$intPart ½ docenas';
    } else if (isHalf && intPart == 0) {
      return '½ docena';
    } else {
      return '$intPart ${intPart == 1 ? 'docena' : 'docenas'}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
        final membrilloNorm = data['membrilloNormal'] as num? ?? 0;
        final membrilloVeg = data['membrilloVegano'] as num? ?? 0;
        final batataNorm = data['batataNormal'] as num? ?? 0;
        final batataVeg = data['batataVegano'] as num? ?? 0;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📊 Totales de Pastelitos',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Total de docenas
              Text('Total docenas: ${_docenaLabel(totalDoc)}'),
              const Divider(),

              // Sabores en docenas
              Text('Membrillo Normal: ${_docenaLabel(membrilloNorm)}'),
              Text('Membrillo Vegano:  ${_docenaLabel(membrilloVeg)}'),
              const SizedBox(height: 8),
              Text('Batata Normal:    ${_docenaLabel(batataNorm)}'),
              Text('Batata Vegano:     ${_docenaLabel(batataVeg)}'),
            ],
          ),
        );
      },
    );
  }
}
