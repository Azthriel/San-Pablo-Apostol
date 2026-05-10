// lib/payment_success_page.dart
import 'dart:js_interop';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr/qr.dart';

@JS('spaDownloadBlob')
external void _jsDownloadBlob(JSArrayBuffer buffer, String filename);

void _downloadPdf(Uint8List bytes, String filename) =>
    _jsDownloadBlob(bytes.buffer.toJS, filename);

// ─── PDF con QR (top-level para compute()) ────────────────────────────────────

Future<Uint8List> _buildTicketPdf(Map<String, dynamic> params) async {
  final Uint8List bgImage = params['bgImage'];
  final String orderId = params['orderId'];
  final Map<String, dynamic> order = params['order'];

  final flavors = (order['flavors'] as List).cast<Map<String, dynamic>>();
  final double churros =
      double.tryParse(order['churros']?.toString() ?? '0') ?? 0.0;

  final pdf = pw.Document();
  final PdfImage bg = PdfImage.file(pdf.document, bytes: bgImage);
  final double w = bg.width.toDouble();
  final double h = bg.height.toDouble();

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(w, h),
      build:
          (_) => pw.Stack(
            children: [
              pw.Positioned.fill(
                child: pw.Image(pw.MemoryImage(bgImage), fit: pw.BoxFit.cover),
              ),
              pw.Padding(
                padding: pw.EdgeInsets.symmetric(
                  horizontal: w * 0.07,
                  vertical: h * 0.06,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(height: h * 0.2),
                    pw.Text(
                      'TALONARIO DE PEDIDO',
                      style: pw.TextStyle(
                        fontSize: w * 0.045,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: h * 0.01),
                    pw.Text(
                      'Emitido: '
                      '${DateTime.now().day.toString().padLeft(2, '0')}/'
                      '${DateTime.now().month.toString().padLeft(2, '0')}/'
                      '${DateTime.now().year}  '
                      '${DateTime.now().hour.toString().padLeft(2, '0')}:'
                      '${DateTime.now().minute.toString().padLeft(2, '0')}',
                      style: pw.TextStyle(
                        fontSize: w * 0.02,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                    pw.SizedBox(height: h * 0.02),
                    pw.Divider(thickness: 1.5, color: PdfColors.grey700),
                    pw.SizedBox(height: h * 0.02),

                    // Datos del comprador
                    _row(w, 'Comprador:', order['buyerName'] ?? ''),
                    pw.SizedBox(height: h * 0.012),
                    _row(w, 'Scout vendedor:', order['sellerName'] ?? ''),
                    pw.SizedBox(height: h * 0.012),
                    _row(w, 'Rama:', order['sellerBranch'] ?? ''),
                    pw.SizedBox(height: h * 0.012),
                    _row(w, 'Forma de pago:', order['paymentMethod'] ?? ''),
                    pw.SizedBox(height: h * 0.02),
                    pw.Divider(thickness: 1.5, color: PdfColors.grey700),
                    pw.SizedBox(height: h * 0.02),

                    // Detalle pedido
                    pw.Text(
                      'Detalle del pedido',
                      style: pw.TextStyle(
                        fontSize: w * 0.025,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: h * 0.01),
                    ...flavors.map(
                      (f) => pw.Padding(
                        padding: pw.EdgeInsets.only(bottom: h * 0.008),
                        child: pw.Text(
                          '${f['flavor']} (${f['size']}, ${f['type']})',
                          style: pw.TextStyle(fontSize: w * 0.02),
                        ),
                      ),
                    ),
                    if (churros > 0)
                      pw.Padding(
                        padding: pw.EdgeInsets.only(top: h * 0.008),
                        child: pw.Text(
                          'Churros: ${_docLabel(churros)}',
                          style: pw.TextStyle(fontSize: w * 0.02),
                        ),
                      ),
                    pw.SizedBox(height: h * 0.02),
                    pw.Divider(thickness: 1.5, color: PdfColors.grey700),
                    pw.SizedBox(height: h * 0.02),

                    // QR + ID
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'Código de pedido',
                              style: pw.TextStyle(
                                fontSize: w * 0.018,
                                fontWeight: pw.FontWeight.bold,
                              ),
                            ),
                            pw.SizedBox(height: h * 0.008),
                            pw.Text(
                              orderId,
                              style: pw.TextStyle(fontSize: w * 0.014),
                            ),
                            pw.SizedBox(height: h * 0.01),
                            pw.Text(
                              'Presentá este QR\nal retirar tu pedido',
                              style: pw.TextStyle(
                                fontSize: w * 0.016,
                                fontStyle: pw.FontStyle.italic,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ],
                        ),
                        pw.Spacer(),
                        _buildQrWidget(orderId, w * 0.22),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
    ),
  );

  return pdf.save();
}

pw.Widget _buildQrWidget(String data, double size) {
  final qrCode = QrCode.fromData(
    data: data,
    errorCorrectLevel: QrErrorCorrectLevel.M,
  );
  final qrImage = QrImage(qrCode);
  final n = qrCode.moduleCount;
  final cell = size / n;

  return pw.Container(
    width: size,
    height: size,
    color: PdfColors.white,
    child: pw.Column(
      children: List.generate(
        n,
        (r) => pw.Row(
          children: List.generate(
            n,
            (c) => pw.Container(
              width: cell,
              height: cell,
              color: qrImage.isDark(r, c) ? PdfColors.black : PdfColors.white,
            ),
          ),
        ),
      ),
    ),
  );
}

pw.Widget _row(double w, String label, String value) => pw.Row(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(
      label,
      style: pw.TextStyle(fontSize: w * 0.02, fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(width: w * 0.02),
    pw.Expanded(child: pw.Text(value, style: pw.TextStyle(fontSize: w * 0.02))),
  ],
);

String _docLabel(double val) {
  final i = val.floor();
  final half = (val - i) >= 0.5;
  if (half && i > 0) return '$i ½ docenas';
  if (half && i == 0) return '½ docena';
  return '$i ${i == 1 ? 'docena' : 'docenas'}';
}

// ─── Page ─────────────────────────────────────────────────────────────────────

class PaymentSuccessPage extends StatefulWidget {
  final String? directOrderId;
  final Map<String, dynamic>? directOrderData;

  const PaymentSuccessPage({
    super.key,
    this.directOrderId,
    this.directOrderData,
  });

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage> {
  String? _externalRef;
  String? _collectionStatus;
  Uint8List? _bgImage;
  bool _generatingPdf = false;

  @override
  void initState() {
    super.initState();
    final uri = Uri.base;
    _externalRef = uri.queryParameters['external_reference'];
    _collectionStatus =
        uri.queryParameters['collection_status'] ??
        uri.queryParameters['status'];
    _loadBg();
  }

  Future<void> _loadBg() async {
    _bgImage = (await rootBundle.load('assets/back.png')).buffer.asUint8List();
    if (mounted) setState(() {});
  }

  Future<void> _downloadTicket(
    Map<String, dynamic> order,
    String orderId,
  ) async {
    if (_bgImage == null) return;
    setState(() => _generatingPdf = true);
    try {
      final bytes = await compute(_buildTicketPdf, {
        'bgImage': _bgImage!,
        'orderId': orderId,
        'order': order,
      });
      _downloadPdf(bytes, 'talonario_$orderId.pdf');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📄 Talonario descargado')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Widget _buildSuccessContent(
    String orderId,
    Map<String, dynamic> order, {
    bool cashPayment = false,
  }) {
    final flavors = (order['flavors'] as List).cast<Map<String, dynamic>>();
    final double churros =
        double.tryParse(order['churros']?.toString() ?? '0') ?? 0.0;
    final cs = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Column(
            children: [
              Icon(
                cashPayment ? Icons.receipt_long : Icons.check_circle,
                color: cashPayment ? cs.secondary : Colors.green,
                size: 80,
              ),
              const SizedBox(height: 16),
              Text(
                cashPayment ? '¡Pedido registrado!' : '¡Pedido confirmado!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                cashPayment
                    ? 'Tu pedido quedó anotado. Coordiná el pago en efectivo con el scout.'
                    : 'Tu pago fue acreditado correctamente.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 24),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SummaryRow('👤 Comprador', order['buyerName'] ?? ''),
                      _SummaryRow(
                        '🧭 Scout vendedor',
                        '${order['sellerName']} · ${order['sellerBranch']}',
                      ),
                      const Divider(height: 20),
                      ...flavors.map(
                        (f) => _SummaryRow(
                          '🎂',
                          '${f['flavor']} (${f['size']}, ${f['type']})',
                        ),
                      ),
                      if (churros > 0)
                        _SummaryRow('🍩 Churros', _docLabel(churros)),
                      const Divider(height: 20),
                      _SummaryRow(
                        '💳 Pago',
                        cashPayment ? 'Efectivo (pendiente)' : 'MercadoPago ✅',
                      ),
                      _SummaryRow(
                        '🆔 ID pedido',
                        orderId.substring(0, 8).toUpperCase(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              _generatingPdf
                  ? const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 8),
                      Text('Generando talonario...'),
                    ],
                  )
                  : FilledButton.icon(
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('Descargar talonario PDF'),
                    onPressed:
                        _bgImage != null
                            ? () => _downloadTicket(order, orderId)
                            : null,
                  ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  } else {
                    Navigator.pushReplacementNamed(context, '/');
                  }
                },
                child: const Text('Hacer otro pedido'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.directOrderId != null && widget.directOrderData != null) {
      return _ScaffoldWrapper(
        child: _buildSuccessContent(
          widget.directOrderId!,
          widget.directOrderData!,
          cashPayment: true,
        ),
      );
    }
    final cs = Theme.of(context).colorScheme;

    // Pago rechazado / fallido
    if (_collectionStatus == 'rejected' || _collectionStatus == 'failure') {
      return _ScaffoldWrapper(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cancel_outlined, color: Colors.red, size: 72),
              const SizedBox(height: 16),
              const Text(
                'El pago no fue aprobado',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Podés intentarlo de nuevo.'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      );
    }

    // Sin referencia → mal link
    if (_externalRef == null) {
      return _ScaffoldWrapper(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: cs.error, size: 72),
              const SizedBox(height: 16),
              const Text('Página no encontrada'),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                child: const Text('Ir al inicio'),
              ),
            ],
          ),
        ),
      );
    }

    return _ScaffoldWrapper(
      child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection('PASTELITOS')
                .doc('PendingPayments')
                .collection('items')
                .doc(_externalRef)
                .snapshots(),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }

          final data = snap.data?.data();
          final status = data?['status'] as String? ?? 'pending';
          final orderId = data?['orderId'] as String?;

          // Aprobado con orden creada
          if (status == 'approved' && orderId != null) {
            final order = data?['orderData'] as Map<String, dynamic>? ?? {};
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 540),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 80,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '¡Pedido confirmado!',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tu pago fue acreditado correctamente.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                      ),
                      const SizedBox(height: 24),

                      // Resumen del pedido
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SummaryRow(
                                '👤 Comprador',
                                order['buyerName'] ?? '',
                              ),
                              _SummaryRow(
                                '🧭 Scout vendedor',
                                '${order['sellerName']} · ${order['sellerBranch']}',
                              ),
                              const Divider(height: 20),
                              ...(order['flavors'] as List? ?? [])
                                  .cast<Map<String, dynamic>>()
                                  .map(
                                    (f) => _SummaryRow(
                                      '🎂',
                                      '${f['flavor']} (${f['size']}, ${f['type']})',
                                    ),
                                  ),
                              Builder(
                                builder: (context) {
                                  final double cantChurros =
                                      double.tryParse(
                                        order['churros']?.toString() ?? '0',
                                      ) ??
                                      0.0;
                                  if (cantChurros > 0) {
                                    return _SummaryRow(
                                      '🍩 Churros',
                                      _docLabel(cantChurros),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                              const Divider(height: 20),
                              _SummaryRow('💳 Pago', 'MercadoPago ✅'),
                              _SummaryRow(
                                '🆔 ID pedido',
                                orderId.substring(0, 8).toUpperCase(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Descargar talonario
                      _generatingPdf
                          ? const Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 8),
                              Text('Generando talonario...'),
                            ],
                          )
                          : FilledButton.icon(
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('Descargar talonario PDF'),
                            onPressed:
                                _bgImage != null
                                    ? () => _downloadTicket(order, orderId)
                                    : null,
                          ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed:
                            () => Navigator.pushReplacementNamed(context, '/'),
                        child: const Text('Hacer otro pedido'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          // Pending / processing
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  'Confirmando tu pago...',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  status == 'approved'
                      ? 'Creando tu pedido...'
                      : 'Esto puede tardar unos segundos.',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
      ],
    ),
  );
}

class _ScaffoldWrapper extends StatelessWidget {
  final Widget child;
  const _ScaffoldWrapper({required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('San Pablo Apóstol')),
    body: child,
  );
}
