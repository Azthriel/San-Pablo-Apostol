// firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eventosspa/master.dart';

class FirestoreService {
  static final _fs = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _ordersCol =>
      _fs.collection('PASTELITOS').doc('Ordenes').collection('items');
  static DocumentReference<Map<String, dynamic>> get _totalsDoc =>
      _fs.collection('PASTELITOS').doc('Totales');

  /// Guarda un pedido y actualiza los totales, incluyendo timestamp de pago si corresponde
  static Future<void> addOrder(Map<String, dynamic> order) async {
    final orderRef = _ordersCol.doc();
    final totalsRef = _totalsDoc;

    // Cálculo de sabores idéntico al que ya tenías...
    double membrilloNormal = 0, membrilloVegano = 0, batataNormal = 0, batataVegano = 0;
    for (final f in order['flavors'] as List<dynamic>) {
      final sabor = f['flavor'] as String;
      final tipo  = f['type']   as String;
      final size  = f['size']   as String;
      final inc   = size == 'Docena' ? 1.0 : 0.5;

      if (sabor == 'Mixta') {
        final half = inc / 2;
        if (tipo == 'Normal') {
          membrilloNormal += half;
          batataNormal   += half;
        } else {
          membrilloVegano += half;
          batataVegano    += half;
        }
      } else if (sabor == 'Membrillo') {
        if (tipo == 'Normal') {
          membrilloNormal += inc;
        } else {
          membrilloVegano += inc;
        }
      } else if (sabor == 'Batata') {
        if (tipo == 'Normal') {
          batataNormal += inc;
        } else {
          batataVegano += inc;
        }
      }
    }

    final batch = _fs.batch();

    // 1) Guardar la orden
    batch.set(orderRef, {
      ...order,
      'createdAt': FieldValue.serverTimestamp(),
      'delivered': false,
      'deliveredAt': null,
      'paid': order['paid'] as bool? ?? false,
      // si llega paid=true, grabamos timestamp; si no, null
      'paidAt': (order['paid'] as bool? ?? false)
          ? FieldValue.serverTimestamp()
          : null,
    });

    // 2) Actualizar Totales igual que antes...
    batch.set(totalsRef, {
      'totalDocenas':    FieldValue.increment(order['docenas'] as num),
      'membrilloNormal': FieldValue.increment(membrilloNormal),
      'membrilloVegano': FieldValue.increment(membrilloVegano),
      'batataNormal':    FieldValue.increment(batataNormal),
      'batataVegano':    FieldValue.increment(batataVegano),
    }, SetOptions(merge: true));

    await batch.commit();
    printLog('Pedido guardado y totales actualizados.');
  }

  /// Marca un pedido como pagado (para pagos posteriores)
  static Future<void> markPaid(String orderId) async {
    await _ordersCol.doc(orderId).update({
      'paid': true,
      'paidAt': FieldValue.serverTimestamp(),
    });
    printLog('Pedido $orderId marcado como pagado');
  }

  /// Marca un pedido como entregado
  static Future<void> markDelivered(String orderId) async {
    await _ordersCol.doc(orderId).update({
      'delivered': true,
      'deliveredAt': FieldValue.serverTimestamp(),
    });
    printLog('Pedido $orderId marcado como entregado');
  }
}
