// firestore_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:eventosspa/master.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// ─── Auth de staff ─────────────────────────────────────────────────────────
// La clave se valida en la Cloud Function `staff_login`, que le pone el rol
// como custom claim al usuario anónimo. Las reglas de Firestore chequean ese
// claim, así que ya no alcanza con "saber la clave" leyendo Config.
// Persistencia SESSION: sobrevive a un F5, se pierde al cerrar la pestaña.
// Los compradores nunca se loguean: la cuenta anónima se crea recién cuando
// alguien ingresa una clave de staff.
enum StaffRole { staff, admin, tesoreria }

class StaffAuth {
  StaffAuth._();
  static final _auth = FirebaseAuth.instance;
  static Map<String, dynamic> _claims = {};

  static bool has(StaffRole r) => _claims[r.name] == true;
  static bool get isStaff => has(StaffRole.staff);
  static bool get isAdmin => has(StaffRole.admin);
  static bool get isTesoreria => has(StaffRole.tesoreria);

  /// Llamar una vez en main(): si la pestaña ya tenía sesión, recupera roles.
  static Future<void> restore() async {
    try {
      if (kIsWeb) await _auth.setPersistence(Persistence.SESSION);
      final user = await _auth.authStateChanges().first;
      if (user == null) return;
      final token = await user.getIdTokenResult();
      _claims = token.claims ?? {};
    } catch (e) {
      printLog('StaffAuth.restore: $e');
    }
  }

  /// Devuelve true si la clave es correcta. Tira excepción si falla la red.
  static Future<bool> login(StaffRole role, String password) async {
    if (password.isEmpty) return false;
    final user = _auth.currentUser ?? (await _auth.signInAnonymously()).user!;
    try {
      await FirebaseFunctions.instance.httpsCallable('staff_login').call({
        'role': role.name,
        'password': password,
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'permission-denied') return false;
      rethrow;
    }
    // Forzar refresh del token para que traiga el claim nuevo
    final token = await user.getIdTokenResult(true);
    _claims = token.claims ?? {};
    return has(role);
  }

  static Future<void> logout() async {
    await _auth.signOut();
    _claims = {};
  }
}

// Antes, HomePage, PurchasePage y TesoreriaPage pegaban a Firestore por
// separado cada vez que se montaban (cada navegación entre tabs/rutas).
// Ahora se lee una sola vez por sesión y se comparte entre todas las páginas.
class ConfigCache {
  ConfigCache._();
  static Map<String, dynamic>? _data;
  static Future<Map<String, dynamic>>? _loading;

  static Future<Map<String, dynamic>> getConfig() {
    if (_data != null) return Future.value(_data!);
    _loading ??= FirebaseFirestore.instance
        .collection('PASTELITOS')
        .doc('Config')
        .get()
        .then((doc) {
          _data = doc.data() ?? {};
          return _data!;
        });
    return _loading!;
  }
}

class FirestoreService {
  static final _fs = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _ordersCol =>
      _fs.collection('PASTELITOS').doc('Ordenes').collection('items');

  static DocumentReference<Map<String, dynamic>> get _totalsDoc =>
      _fs.collection('PASTELITOS').doc('Totales');

  /// Guarda un pedido y actualiza totales (pastelitos + churros)
  static Future<String> addOrder(Map<String, dynamic> order) async {
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

    final double churros = (order['churros'] as num? ?? 0).toDouble();

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
      'churros': churros,
    });

    batch.set(_totalsDoc, {
      'totalDocenas': FieldValue.increment(order['docenas'] as num),
      'membrilloTrad': FieldValue.increment(membrilloTrad),
      'membrilloVegano': FieldValue.increment(membrilloVeg),
      'batataTrad': FieldValue.increment(batataTrad),
      'batataVegano': FieldValue.increment(batataVeg),
      'totalChurros': FieldValue.increment(churros),
      'docenasEntregadas': FieldValue.increment(0),
      'churrosEntregados': FieldValue.increment(0),
    }, SetOptions(merge: true));

    await batch.commit();
    printLog('Pedido guardado y totales actualizados.');
    printLog('Pedido guardado: ${orderRef.id}');
    return orderRef.id;
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

  /// Marca un pedido como entregado y actualiza docenasEntregadas y
  /// churrosEntregados
  static Future<void> markDelivered(String orderId) async {
    final orderRef = _ordersCol.doc(orderId);
    final docSnap = await orderRef.get();
    final data = docSnap.data();
    if (data == null) return;
    final num docenas = data['docenas'] as num? ?? 0;
    final double churros = (data['churros'] as num? ?? 0).toDouble();

    final batch = _fs.batch();
    batch.update(orderRef, {
      'delivered': true,
      'deliveredAt': FieldValue.serverTimestamp(),
    });
    batch.set(_totalsDoc, {
      'docenasEntregadas': FieldValue.increment(docenas),
      'churrosEntregados': FieldValue.increment(churros),
    }, SetOptions(merge: true));

    await batch.commit();
    printLog('Pedido $orderId marcado como entregado');
  }

  /// Deshace la entrega y actualiza docenasEntregadas y churrosEntregados
  static Future<void> unmarkDelivered(String orderId) async {
    final orderRef = _ordersCol.doc(orderId);
    final docSnap = await orderRef.get();
    final data = docSnap.data();
    if (data == null) return;
    final num docenas = data['docenas'] as num? ?? 0;
    final double churros = (data['churros'] as num? ?? 0).toDouble();

    final batch = _fs.batch();
    batch.update(orderRef, {'delivered': false, 'deliveredAt': null});
    batch.set(_totalsDoc, {
      'docenasEntregadas': FieldValue.increment(-docenas),
      'churrosEntregados': FieldValue.increment(-churros),
    }, SetOptions(merge: true));

    await batch.commit();
    printLog('Entrega de pedido $orderId deshecha');
  }

  /// Cancela un pedido y ajusta los totales
  static Future<void> cancelOrder(String orderId) async {
    final orderRef = _ordersCol.doc(orderId);
    final docSnap = await orderRef.get();
    final data = docSnap.data();
    if (data == null) return;

    final num docenas = data['docenas'] as num? ?? 0;
    final double churros = (data['churros'] as num? ?? 0).toDouble();
    final bool delivered = data['delivered'] as bool? ?? false;
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
      'totalChurros': FieldValue.increment(-churros),
      if (delivered) ...{
        'docenasEntregadas': FieldValue.increment(-docenas),
        'churrosEntregados': FieldValue.increment(-churros),
      },
    }, SetOptions(merge: true));

    await batch.commit();
    printLog('Pedido $orderId cancelado y totales actualizados.');
  }

  /// Elimina DEFINITIVAMENTE un pedido específico (borra el documento).
  /// Distinto de cancelOrder: ahí el pedido sigue existiendo marcado como
  /// cancelado; acá desaparece. Si todavía no estaba cancelado, primero
  /// descuenta sus totales (incluida la entrega, si la tenía) para no dejar
  /// los números de Estadísticas/Tesorería desactualizados.
  static Future<void> deleteOrder(String orderId) async {
    final orderRef = _ordersCol.doc(orderId);
    final docSnap = await orderRef.get();
    final data = docSnap.data();
    if (data == null) return;

    final canceled = data['canceled'] as bool? ?? false;
    final batch = _fs.batch();

    if (!canceled) {
      final num docenas = data['docenas'] as num? ?? 0;
      final double churros = (data['churros'] as num? ?? 0).toDouble();
      final bool delivered = data['delivered'] as bool? ?? false;
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

      batch.set(_totalsDoc, {
        'totalDocenas': FieldValue.increment(-docenas),
        'membrilloTrad': FieldValue.increment(-membrilloTrad),
        'membrilloVegano': FieldValue.increment(-membrilloVeg),
        'batataTrad': FieldValue.increment(-batataTrad),
        'batataVegano': FieldValue.increment(-batataVeg),
        'totalChurros': FieldValue.increment(-churros),
        if (delivered) ...{
          'docenasEntregadas': FieldValue.increment(-docenas),
          'churrosEntregados': FieldValue.increment(-churros),
        },
      }, SetOptions(merge: true));
    }

    batch.delete(orderRef);
    await batch.commit();
    printLog('Pedido $orderId eliminado definitivamente.');
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
      'totalChurros': 0,
      'docenasEntregadas': 0,
      'churrosEntregados': 0,
    });
    await batch.commit();
    printLog('Todos los pedidos eliminados y totales reiniciados.');
  }

  /// Stream de pedidos (ordenados por createdAt)
  static Stream<QuerySnapshot<Map<String, dynamic>>> streamOrders() {
    return _ordersCol.orderBy('createdAt', descending: false).snapshots();
  }

  /// Guarda un pago en Tesorería
  static Future<String> addPago(Map<String, dynamic> pago) async {
    final CollectionReference<Map<String, dynamic>> pagosCol = _fs
        .collection('TESORERIA')
        .doc('PAGOS')
        .collection('COMPROBANTES');

    final DocumentReference<Map<String, dynamic>> docRef = pagosCol.doc();
    await docRef.set({...pago, 'createdAt': FieldValue.serverTimestamp()});

    printLog('Pago ${docRef.id} guardado en Tesorería');
    return docRef.id;
  }
}
