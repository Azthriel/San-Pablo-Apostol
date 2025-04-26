// totals_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class TotalsPage extends StatelessWidget {
  const TotalsPage({super.key});

  String _docenaLabel(num val) {
    final d = val.toDouble();
    final intPart = d.floor();
    final isHalf = (d - intPart) >= 0.5;
    if (isHalf && intPart > 0) return '$intPart ½ docenas';
    if (isHalf && intPart == 0) return '½ docena';
    return '$intPart ${intPart == 1 ? 'docena' : 'docenas'}';
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
        final membrilloTrad = data['membrilloTrad'] as num? ?? 0;
        final membrilloVeg = data['membrilloVegano'] as num? ?? 0;
        final batataTrad = data['batataTrad'] as num? ?? 0;
        final batataVeg = data['batataVegano'] as num? ?? 0;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📊 Totales de Pastelitos vendidos por el grupo',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              Text('Total docenas: ${_docenaLabel(totalDoc)}'),
              const Divider(),

              Text('Membrillo Tradicional: ${_docenaLabel(membrilloTrad)}'),
              Text('Membrillo Vegano:      ${_docenaLabel(membrilloVeg)}'),
              const SizedBox(height: 8),
              Text('Batata Tradicional:    ${_docenaLabel(batataTrad)}'),
              Text('Batata Vegano:         ${_docenaLabel(batataVeg)}'),
            ],
          ),
        );
      },
    );
  }
}
