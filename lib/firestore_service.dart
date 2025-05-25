// firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:eventosspa/master.dart';

class FirestoreService {
  static final _fs = FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _ordersCol =>
      _fs.collection('PASTELITOS').doc('Ordenes').collection('items');
  static DocumentReference<Map<String, dynamic>> get _totalsDoc =>
      _fs.collection('PASTELITOS').doc('Totales');

  /// Guarda un pedido, inicializa docenasEntregadas a 0 y actualiza totales
  static Future<void> addOrder(Map<String, dynamic> order) async {
    final orderRef = _ordersCol.doc();

    double membrilloTrad = 0, membrilloVeg = 0, batataTrad = 0, batataVeg = 0;
    for (final f in order['flavors'] as List<dynamic>) {
      final sabor = f['flavor'] as String;
      final tipo = f['type'] as String;
      final size = f['size'] as String;
      final inc = size == 'Docena' ? 1.0 : 0.5;

      if (sabor == 'Mixta') {
        final half = inc / 2;
        if (tipo == 'Tradicional') {
          membrilloTrad += half;
          batataTrad += half;
        } else {
          membrilloVeg += half;
          batataVeg += half;
        }
      } else if (sabor == 'Membrillo') {
        if (tipo == 'Tradicional') {
          membrilloTrad += inc;
        } else {
          membrilloVeg += inc;
        }
      } else if (sabor == 'Batata') {
        if (tipo == 'Tradicional') {
          batataTrad += inc;
        } else {
          batataVeg += inc;
        }
      }
    }

    final batch = _fs.batch();

    batch.set(orderRef, {
      ...order,
      'createdAt': FieldValue.serverTimestamp(),
      'delivered': false,
      'deliveredAt': null,
      'canceled': false,
      'canceledAt': null,
      'paid': order['paid'] as bool? ?? false,
      'paidAt':
          (order['paid'] as bool? ?? false)
              ? FieldValue.serverTimestamp()
              : null,
    });

    batch.set(_totalsDoc, {
      'totalDocenas': FieldValue.increment(order['docenas'] as num),
      'membrilloTrad': FieldValue.increment(membrilloTrad),
      'membrilloVegano': FieldValue.increment(membrilloVeg),
      'batataTrad': FieldValue.increment(batataTrad),
      'batataVegano': FieldValue.increment(batataVeg),
      'docenasEntregadas': FieldValue.increment(0),
    }, SetOptions(merge: true));

    await batch.commit();
    printLog('Pedido guardado y totales actualizados.');
  }

  /// Marca un pedido como pagado
  static Future<void> markPaid(String orderId) async {
    await _ordersCol.doc(orderId).update({
      'paid': true,
      'paidAt': FieldValue.serverTimestamp(),
    });
    printLog('Pedido $orderId marcado como pagado');
  }

  /// Deshace el pago
  static Future<void> unmarkPaid(String orderId) async {
    await _ordersCol.doc(orderId).update({'paid': false, 'paidAt': null});
    printLog('Pago de pedido $orderId deshecho');
  }

  /// Marca un pedido como entregado y actualiza docenasEntregadas
  static Future<void> markDelivered(String orderId) async {
    final orderRef = _ordersCol.doc(orderId);
    final docSnap = await orderRef.get();
    final data = docSnap.data();
    if (data == null) return;
    final num docenas = data['docenas'] as num? ?? 0;

    final batch = _fs.batch();
    batch.update(orderRef, {
      'delivered': true,
      'deliveredAt': FieldValue.serverTimestamp(),
    });
    batch.set(_totalsDoc, {
      'docenasEntregadas': FieldValue.increment(docenas),
    }, SetOptions(merge: true));

    await batch.commit();
    printLog('Pedido $orderId marcado como entregado');
  }

  /// Deshace la entrega y actualiza docenasEntregadas
  static Future<void> unmarkDelivered(String orderId) async {
    final orderRef = _ordersCol.doc(orderId);
    final docSnap = await orderRef.get();
    final data = docSnap.data();
    if (data == null) return;
    final num docenas = data['docenas'] as num? ?? 0;

    final batch = _fs.batch();
    batch.update(orderRef, {'delivered': false, 'deliveredAt': null});
    batch.set(_totalsDoc, {
      'docenasEntregadas': FieldValue.increment(-docenas),
    }, SetOptions(merge: true));

    await batch.commit();
    printLog('Entrega de pedido $orderId deshecha');
  }

  /// Cancela un pedido y ajusta los totales (sin tocar docenasEntregadas)
  static Future<void> cancelOrder(String orderId) async {
    final orderRef = _ordersCol.doc(orderId);
    final docSnap = await orderRef.get();
    final data = docSnap.data();
    if (data == null) return;

    final num docenas = data['docenas'] as num? ?? 0;
    double membrilloTrad = 0, membrilloVeg = 0, batataTrad = 0, batataVeg = 0;
    final flavors =
        (data['flavors'] as List<dynamic>).cast<Map<String, dynamic>>();

    for (final f in flavors) {
      final sabor = f['flavor'] as String;
      final tipo = f['type'] as String;
      final size = f['size'] as String;
      final inc = size == 'Docena' ? 1.0 : 0.5;
      if (sabor == 'Mixta') {
        final half = inc / 2;
        if (tipo == 'Tradicional') {
          membrilloTrad += half;
          batataTrad += half;
        } else {
          membrilloVeg += half;
          batataVeg += half;
        }
      } else if (sabor == 'Membrillo') {
        if (tipo == 'Tradicional') {
          membrilloTrad += inc;
        } else {
          membrilloVeg += inc;
        }
      } else if (sabor == 'Batata') {
        if (tipo == 'Tradicional') {
          batataTrad += inc;
        } else {
          batataVeg += inc;
        }
      }
    }

    final batch = _fs.batch();
    batch.update(orderRef, {
      'canceled': true,
      'canceledAt': FieldValue.serverTimestamp(),
    });
    batch.set(_totalsDoc, {
      'totalDocenas': FieldValue.increment(-docenas),
      'membrilloTrad': FieldValue.increment(-membrilloTrad),
      'membrilloVegano': FieldValue.increment(-membrilloVeg),
      'batataTrad': FieldValue.increment(-batataTrad),
      'batataVegano': FieldValue.increment(-batataVeg),
    }, SetOptions(merge: true));

    await batch.commit();
    printLog('Pedido $orderId cancelado y totales actualizados.');
  }

  /// Elimina todos los pedidos y reinicia totales a cero
  static Future<void> resetAllOrders() async {
    final batch = _fs.batch();
    final ordersSnap = await _ordersCol.get();
    for (final doc in ordersSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.set(_totalsDoc, {
      'totalDocenas': 0,
      'membrilloTrad': 0,
      'membrilloVegano': 0,
      'batataTrad': 0,
      'batataVegano': 0,
      'docenasEntregadas': 0,
    });
    await batch.commit();
    printLog('Todos los pedidos eliminados y totales reiniciados.');
  }

  /// Stream de pedidos (ordenados por createdAt)
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamOrders() {
    return _ordersCol.orderBy('createdAt', descending: false).snapshots();
  }
}
