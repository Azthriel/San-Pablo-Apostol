// lib/qr_scanner_page.dart
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  bool _processing = false;
  bool _isCheckingPermission = true;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    _requestCameraPermission();
  }

  // Función para solicitar permisos explícitos
  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();

    if (mounted) {
      setState(() {
        _hasPermission = status.isGranted;
        _isCheckingPermission = false;
      });
    }
  }

  // Función para procesar el código detectado
  Future<void> _processCode(String value) async {
    if (_processing) return;

    setState(() => _processing = true);

    try {
      // Buscar orden en Firestore por ID
      final snap =
          await FirebaseFirestore.instance
              .collection('PASTELITOS')
              .doc('Ordenes')
              .collection('items')
              .doc(value)
              .get();

      if (!mounted) return;

      if (!snap.exists) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('❌ Pedido no encontrado')));
      } else {
        final order = snap.data()!;
        await _showOrderSheet(context, snap.id, order);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Mostrar carga mientras verificamos permisos
    if (_isCheckingPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('Escanear QR')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Solicitando acceso a la cámara...'),
            ],
          ),
        ),
      );
    }

    // 2. Si denegó los permisos, mostramos un mensaje amigable
    if (!_hasPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('Escanear QR')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Permiso de cámara denegado.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Para escanear el talonario, necesitamos acceso a tu cámara. '
                  'Por favor, habilitalo desde el candadito en la barra de direcciones de tu navegador.',
                  textAlign: TextAlign.center,
                ),
              ),
              ElevatedButton(
                onPressed: _requestCameraPermission,
                child: const Text('Volver a intentar'),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Si hay permisos, renderizamos el escáner (sin Scaffold externo porque AiBarcodeScanner ya tiene uno en v7.1.0)
    return Stack(
      children: [
        AiBarcodeScanner(
          onDetect: (BarcodeCapture capture) {
            final String? code = capture.barcodes.firstOrNull?.rawValue;
            if (code != null && code.isNotEmpty) {
              _processCode(code);
            }
          },
        ),

        // Overlay de procesamiento sobre el escáner
        if (_processing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Procesando pedido...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// --- Detalle del Pedido ---

// Convierte String o num de forma segura (protege contra docs corruptos de Firestore)
num _safeNum(dynamic v) =>
    v is num ? v : num.tryParse(v?.toString() ?? '') ?? 0;

Future<void> _showOrderSheet(
  BuildContext context,
  String docId,
  Map<String, dynamic> order,
) async {
  final flavors =
      (order['flavors'] as List?)?.cast<Map<String, dynamic>>() ?? [];
  final churros = _safeNum(order['churros']).toDouble();
  final delivered = order['delivered'] as bool? ?? false;
  final paid = order['paid'] as bool? ?? false;
  final cs = Theme.of(context).colorScheme;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder:
        (ctx) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.qr_code_2, color: cs.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Pedido Encontrado',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 24),
              _SheetRow('Comprador', order['buyerName'] ?? 'Sin nombre'),
              _SheetRow('Vendedor', '${order['sellerName'] ?? 'N/A'}'),
              const SizedBox(height: 10),
              const Text(
                'Contenido:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...flavors.map(
                (f) => Text('• ${f['flavor']} (${f['size']}, ${f['type']})'),
              ),
              if (churros > 0) Text('• Churros: ${_docLabel(churros)}'),
              const SizedBox(height: 16),
              Row(
                children: [
                  _StatusChip(paid, 'PAGADO', 'NO PAGADO', Colors.green),
                  const SizedBox(width: 8),
                  _StatusChip(delivered, 'ENTREGADO', 'PENDIENTE', cs.primary),
                ],
              ),
              const SizedBox(height: 24),
              if (!delivered)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Confirmar Entrega'),
                    onPressed: () async {
                      final orderRef = FirebaseFirestore.instance
                          .collection('PASTELITOS')
                          .doc('Ordenes')
                          .collection('items')
                          .doc(docId);

                      final totalsRef = FirebaseFirestore.instance
                          .collection('PASTELITOS')
                          .doc('Totales');

                      final docenas = _safeNum(order['docenas']);

                      final batch = FirebaseFirestore.instance.batch();
                      batch.update(orderRef, {
                        'delivered': true,
                        'deliveredAt': FieldValue.serverTimestamp(),
                      });
                      batch.set(totalsRef, {
                        'docenasEntregadas': FieldValue.increment(docenas),
                      }, SetOptions(merge: true));

                      await batch.commit();

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Pedido entregado')),
                        );
                      }
                    },
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ),
  );
}

// Función auxiliar para formatear medias docenas
String _docLabel(double val) {
  final i = val.floor();
  final half = (val - i) >= 0.5;
  if (half && i > 0) return '$i ½ docenas';
  if (half && i == 0) return '½ docena';
  return '$i ${i == 1 ? 'docena' : 'docenas'}';
}

class _SheetRow extends StatelessWidget {
  final String label;
  final String value;
  const _SheetRow(this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: const TextStyle(color: Colors.grey)),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  final bool active;
  final String activeLabel;
  final String inactiveLabel;
  final Color color;
  const _StatusChip(
    this.active,
    this.activeLabel,
    this.inactiveLabel,
    this.color,
  );
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color:
          active
              ? color.withValues(alpha: 0.1)
              : Colors.red.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: active ? color : Colors.red),
    ),
    child: Text(
      active ? activeLabel : inactiveLabel,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.bold,
        color: active ? color : Colors.red,
      ),
    ),
  );
}