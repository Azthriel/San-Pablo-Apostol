// lib/tesoreria_page.dart
import 'dart:js_interop';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:eventosspa/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

// ─── JS interop (dart:js_interop — sin deprecated dart:html/dart:js) ──────────

/// Descarga directa via Blob URL — llama a window.spaDownloadBlob del index.html
@JS('spaDownloadBlob')
external void _jsDownloadBlob(JSArrayBuffer buffer, String filename);

/// Web Share API con PDF adjunto — llama a window.spaShareFile del index.html
// ignore: unintended_html_in_doc_comment
/// Retorna Promise<bool>
@JS('spaShareFile')
external JSPromise _jsShareFile(JSArrayBuffer buffer, String filename);

/// Detecta si el browser soporta Web Share API — window.spaSupportsShare()
@JS('spaSupportsShare')
external bool _jsSupportsShare();

// ─── Helpers Dart ─────────────────────────────────────────────────────────────

void _downloadViaBlob(Uint8List bytes, String filename) {
  _jsDownloadBlob(bytes.buffer.toJS, filename);
}

bool _supportsFileShare() => _jsSupportsShare();

Future<bool> _shareViaNativeSheet(Uint8List bytes, String filename) async {
  try {
    final result = await _jsShareFile(bytes.buffer.toJS, filename).toDart;
    return (result as JSBoolean?)?.toDart ?? false;
  } catch (_) {
    return false;
  }
}

// ─── PDF builder (top-level para usar con compute()) ─────────────────────────

Future<Uint8List> _buildPdfInBackground(Map<String, dynamic> params) async {
  final Uint8List bgImage = params['bgImage'];
  final String pagoId = params['pagoId'];
  final Map<String, dynamic> d = params['datosPago'];

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
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.SizedBox(height: h * 0.03),
                    pw.Text(
                      'COMPROBANTE DE PAGO',
                      style: pw.TextStyle(
                        fontSize: w * 0.04,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: h * 0.02),
                    pw.Text(
                      'Fecha de emisión: '
                      '${DateTime.now().day.toString().padLeft(2, '0')}/'
                      '${DateTime.now().month.toString().padLeft(2, '0')}/'
                      '${DateTime.now().year}  '
                      '${DateTime.now().hour.toString().padLeft(2, '0')}:'
                      '${DateTime.now().minute.toString().padLeft(2, '0')}',
                      style: pw.TextStyle(
                        fontSize: w * 0.022,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                    pw.SizedBox(height: h * 0.025),
                    pw.Divider(thickness: 1.5, color: PdfColors.grey700),
                    pw.SizedBox(height: h * 0.025),
                    pw.Text(
                      'Cantidad del pago',
                      style: pw.TextStyle(
                        fontSize: w * 0.025,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      '\$${(d['cantidadPago'] as double).toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: w * 0.06),
                    ),
                    pw.SizedBox(height: h * 0.03),
                    _pdfRow(w, 'Razón del pago:', d['razonPago']),
                    pw.SizedBox(height: h * 0.018),
                    _pdfRow(w, 'Forma de pago:', d['formaPago']),
                    pw.SizedBox(height: h * 0.04),
                    pw.Divider(thickness: 1.5, color: PdfColors.grey700),
                    pw.SizedBox(height: h * 0.025),
                    _pdfRow(w, 'Jóven Protagonista:', d['nombreBeneficiario']),
                    pw.SizedBox(height: h * 0.018),
                    _pdfRow(w, 'Rama:', d['ramaBeneficiario']),
                    pw.SizedBox(height: h * 0.018),
                    _pdfRow(w, 'Pagado por:', d['nombreQuienPaga']),
                    pw.SizedBox(height: h * 0.018),
                    _pdfRow(w, 'Fecha de pago:', d['fechaPagoFormatted']),
                    pw.SizedBox(height: h * 0.018),
                    _pdfRow(w, 'Emitido por:', d['reciboEmitidoPor']),
                    pw.SizedBox(height: h * 0.03),
                    pw.Divider(thickness: 1.5, color: PdfColors.grey700),
                    pw.SizedBox(height: h * 0.02),
                    pw.Text(
                      'ID de pago',
                      style: pw.TextStyle(
                        fontSize: w * 0.016,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(pagoId, style: pw.TextStyle(fontSize: w * 0.016)),
                  ],
                ),
              ),
            ],
          ),
    ),
  );

  return pdf.save();
}

pw.Widget _pdfRow(double w, String label, String value) => pw.Row(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(
      label,
      style: pw.TextStyle(fontSize: w * 0.02, fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(width: w * 0.02),
    pw.Container(
      width: w * 0.55,
      child: pw.Text(value, style: pw.TextStyle(fontSize: w * 0.02)),
    ),
  ],
);

// ─── Page ─────────────────────────────────────────────────────────────────────

class TesoreriaPage extends StatefulWidget {
  const TesoreriaPage({super.key});
  @override
  _TesoreriaPageState createState() => _TesoreriaPageState();
}

class _TesoreriaPageState extends State<TesoreriaPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _beneficiaryController;
  late TextEditingController _reasonController;
  late TextEditingController _amountController;
  late TextEditingController _payerController;
  late TextEditingController _issuerController;
  late TextEditingController _paymentDateController;
  late TextEditingController _passwordController;

  DateTime? _selectedPaymentDate;
  bool _creating = false;
  bool _loadingConfig = true;
  bool _authenticated = false;
  String _configPassword = '';

  // Cache de imagen de fondo — se carga una sola vez
  Uint8List? _cachedBgImage;

  final List<String> branches = [
    'Manada',
    'Unidad scout',
    'Caminantes',
    'Rovers',
    'Educadores',
  ];
  String _branch = 'Manada';
  final List<String> paymentOptions = ['Efectivo', 'Transferencia'];
  String _paymentMethod = 'Efectivo';

  @override
  void initState() {
    super.initState();
    _beneficiaryController = TextEditingController();
    _reasonController = TextEditingController();
    _amountController = TextEditingController();
    _payerController = TextEditingController();
    _issuerController = TextEditingController();
    _paymentDateController = TextEditingController();
    _passwordController = TextEditingController();
    _selectedPaymentDate = DateTime.now();
    _paymentDateController.text = _formatDate(DateTime.now());
    _fetchConfig();
  }

  @override
  void dispose() {
    for (final c in [
      _beneficiaryController,
      _reasonController,
      _amountController,
      _payerController,
      _issuerController,
      _paymentDateController,
      _passwordController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _fetchConfig() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('TESORERIA')
              .doc('Config')
              .get();
      _configPassword = (doc.data()?['pass'] as String?) ?? '';
    } catch (_) {}
    if (!mounted) return;
    setState(() => _loadingConfig = false);
  }

  void _checkPassword() {
    if (_passwordController.text.trim() == _configPassword) {
      setState(() => _authenticated = true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('❌ Contraseña incorrecta')));
      _passwordController.clear();
    }
  }

  Future<Uint8List> _getBgImage() async {
    _cachedBgImage ??=
        (await rootBundle.load('assets/back.png')).buffer.asUint8List();
    return _cachedBgImage!;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _creating = true);

    final pago = <String, dynamic>{
      'nombreBeneficiario': _beneficiaryController.text.trim(),
      'ramaBeneficiario': _branch,
      'razonPago': _reasonController.text.trim(),
      'formaPago': _paymentMethod,
      'cantidadPago': double.tryParse(_amountController.text.trim()) ?? 0.0,
      'nombreQuienPaga': _payerController.text.trim(),
      'reciboEmitidoPor': _issuerController.text.trim(),
      'fechaPago': _selectedPaymentDate?.toIso8601String() ?? '',
      'fechaPagoFormatted': _paymentDateController.text.trim(),
    };

    // 1) Guardar en Firestore
    final pagoId = await FirestoreService.addPago(pago);

    // 2) Generar PDF en background via compute() — no bloquea la UI
    final bgImage = await _getBgImage();
    final pdfBytes = await compute(_buildPdfInBackground, {
      'bgImage': bgImage,
      'pagoId': pagoId,
      'datosPago': pago,
    });

    if (!mounted) return;
    setState(() => _creating = false);

    // 3) Mostrar opciones
    await _showShareDialog(
      pdfBytes: pdfBytes,
      filename: 'comprobante_$pagoId.pdf',
      buyerName: pago['nombreBeneficiario'] as String,
    );

    // 4) Resetear form
    _formKey.currentState!.reset();
    _beneficiaryController.clear();
    _reasonController.clear();
    _amountController.clear();
    _payerController.clear();
    _issuerController.clear();
    _paymentDateController.text = _formatDate(DateTime.now());
    setState(() {
      _branch = branches.first;
      _paymentMethod = paymentOptions.first;
      _selectedPaymentDate = DateTime.now();
    });
  }

  Future<void> _showShareDialog({
    required Uint8List pdfBytes,
    required String filename,
    required String buyerName,
  }) async {
    final mobileShare = _supportsFileShare();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          icon: Icon(
            Icons.check_circle,
            color: Colors.green.shade600,
            size: 48,
          ),
          title: const Text('¡Pago guardado!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Comprobante de $buyerName generado.',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),

              // Descargar
              FilledButton.icon(
                icon: const Icon(Icons.download_outlined),
                label: const Text('Descargar PDF'),
                onPressed: () {
                  _downloadViaBlob(pdfBytes, filename);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('📄 PDF descargado')),
                  );
                },
              ),
              const SizedBox(height: 10),

              // Compartir (solo mobile / browsers con Web Share API)
              if (mobileShare)
                OutlinedButton.icon(
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Compartir vía WhatsApp, Email... (Solo celular)'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: cs.primary),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final ok = await _shareViaNativeSheet(pdfBytes, filename);
                    if (!ok && mounted) {
                      // Fallback silencioso: descarga directa
                      _downloadViaBlob(pdfBytes, filename);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Compartir no disponible — PDF descargado',
                          ),
                        ),
                      );
                    }
                  },
                )
              else
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.phone_iphone,
                        size: 16,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Compartir por WhatsApp/Email disponible desde el celular.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingConfig) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tesorería')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_authenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tesorería')),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
              maxHeight: 300,
            ),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Acceso restringido',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: Icon(Icons.key_outlined),
                      ),
                      onSubmitted: (_) => _checkPassword(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _checkPassword,
                        child: const Text('Verificar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Tesorería')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionCard(
                    title: 'Jóven Protagonista',
                    icon: Icons.person_outline,
                    children: [
                      TextFormField(
                        controller: _beneficiaryController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre completo',
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Obligatorio'
                                    : null,
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel(label: 'Rama'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            branches
                                .map(
                                  (b) => ChoiceChip(
                                    label: Text(b),
                                    selected: _branch == b,
                                    onSelected:
                                        (_) => setState(() => _branch = b),
                                  ),
                                )
                                .toList(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _SectionCard(
                    title: 'Datos del pago',
                    icon: Icons.payments_outlined,
                    children: [
                      TextFormField(
                        controller: _reasonController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Razón del pago',
                          prefixIcon: Icon(Icons.description_outlined),
                        ),
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Obligatorio'
                                    : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Cantidad',
                          prefixIcon: Icon(Icons.attach_money),
                          prefixText: '\$ ',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Obligatorio';
                          }
                          final n = double.tryParse(v.trim());
                          if (n == null) return 'Número inválido';
                          if (n <= 0) return 'Debe ser mayor a cero';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel(label: 'Forma de pago'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            paymentOptions
                                .map(
                                  (p) => ChoiceChip(
                                    label: Text(p),
                                    selected: _paymentMethod == p,
                                    onSelected:
                                        (_) =>
                                            setState(() => _paymentMethod = p),
                                  ),
                                )
                                .toList(),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _paymentDateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Fecha de pago',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                          suffixIcon: Icon(Icons.edit_calendar_outlined),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedPaymentDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedPaymentDate = picked;
                              _paymentDateController.text = _formatDate(picked);
                            });
                          }
                        },
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Obligatorio'
                                    : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _SectionCard(
                    title: 'Participantes',
                    icon: Icons.group_outlined,
                    children: [
                      TextFormField(
                        controller: _payerController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de quien paga',
                          prefixIcon: Icon(Icons.account_circle_outlined),
                        ),
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Obligatorio'
                                    : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _issuerController,
                        decoration: const InputDecoration(
                          labelText: 'Recibo emitido por',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator:
                            (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Obligatorio'
                                    : null,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _creating
                      ? Center(
                        child: Column(
                          children: [
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(
                              'Generando comprobante...',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                      : FilledButton.icon(
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Guardar y generar comprobante'),
                        onPressed: _handleSubmit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade700,
      ),
    );
  }
}
