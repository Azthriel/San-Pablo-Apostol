// lib/tesoreria_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:eventosspa/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Función top-level que construye el PDF en un isolate separado.
/// Recibe un Map con:
/// - 'bgImage': Uint8List de la imagen de fondo,
/// - 'pagoId': String del identificador,
/// - 'datosPago': Map con todos los campos (incluido 'reciboEmitidoPor' y 'fechaPagoFormatted').
Future<Uint8List> _buildPdfInBackground(Map<String, dynamic> params) async {
  final Uint8List bgImage = params['bgImage'];
  final String pagoId = params['pagoId'];
  final Map<String, dynamic> datosPago = params['datosPago'];

  // 1) Creamos el documento PDF
  final pdf = pw.Document();

  // 2) Insertamos la imagen para medir dimensiones
  final PdfImage backgroundImage = PdfImage.file(pdf.document, bytes: bgImage);
  final double imageWidth = backgroundImage.width.toDouble();
  final double imageHeight = backgroundImage.height.toDouble();
  final pw.MemoryImage background = pw.MemoryImage(bgImage);

  // 3) Agregamos la página
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(imageWidth, imageHeight),
      build: (pw.Context context) {
        return pw.Stack(
          children: [
            pw.Positioned.fill(
              child: pw.Image(background, fit: pw.BoxFit.cover),
            ),
            pw.Padding(
              padding: pw.EdgeInsets.symmetric(
                horizontal: imageWidth * 0.07,
                vertical: imageHeight * 0.06,
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  // Espacio superior
                  pw.SizedBox(height: imageHeight * 0.03),

                  // Título
                  pw.Text(
                    'COMPROBANTE DE PAGO',
                    style: pw.TextStyle(
                      fontSize: imageWidth * 0.04,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: imageHeight * 0.02),

                  // Fecha de emisión
                  pw.Text(
                    'Fecha de emisión: '
                    '${DateTime.now().day.toString().padLeft(2, '0')}/'
                    '${DateTime.now().month.toString().padLeft(2, '0')}/'
                    '${DateTime.now().year}   '
                    '${DateTime.now().hour.toString().padLeft(2, '0')}:'
                    '${DateTime.now().minute.toString().padLeft(2, '0')}:'
                    '${DateTime.now().second.toString().padLeft(2, '0')}',
                    style: pw.TextStyle(
                      fontSize: imageWidth * 0.024,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                  pw.SizedBox(height: imageHeight * 0.025),

                  pw.Divider(thickness: 1.5, color: PdfColors.grey700),
                  pw.SizedBox(height: imageHeight * 0.025),

                  // Cantidad
                  pw.Text(
                    'Cantidad del pago',
                    style: pw.TextStyle(
                      fontSize: imageWidth * 0.025,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '\$${(datosPago['cantidadPago'] as double).toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: imageWidth * 0.06),
                  ),
                  pw.SizedBox(height: imageHeight * 0.035),

                  // Razón
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Razón del pago:',
                        style: pw.TextStyle(
                          fontSize: imageWidth * 0.02,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(width: imageWidth * 0.02),
                      pw.Container(
                        width: imageWidth * 0.55,
                        child: pw.Text(
                          datosPago['razonPago'],
                          style: pw.TextStyle(fontSize: imageWidth * 0.02),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: imageHeight * 0.02),

                  // Forma de pago
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Forma de pago:',
                        style: pw.TextStyle(
                          fontSize: imageWidth * 0.02,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(width: imageWidth * 0.02),
                      pw.Text(
                        datosPago['formaPago'],
                        style: pw.TextStyle(fontSize: imageWidth * 0.02),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: imageHeight * 0.04),

                  pw.Divider(thickness: 1.5, color: PdfColors.grey700),
                  pw.SizedBox(height: imageHeight * 0.025),

                  // Nombre joven
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Nombre del Jóven Protagonista:',
                        style: pw.TextStyle(
                          fontSize: imageWidth * 0.02,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(width: imageWidth * 0.02),
                      pw.Text(
                        datosPago['nombreBeneficiario'],
                        style: pw.TextStyle(fontSize: imageWidth * 0.02),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: imageHeight * 0.02),

                  // Rama joven
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Rama del Jóven Protagonista:',
                        style: pw.TextStyle(
                          fontSize: imageWidth * 0.02,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(width: imageWidth * 0.02),
                      pw.Text(
                        datosPago['ramaBeneficiario'],
                        style: pw.TextStyle(fontSize: imageWidth * 0.02),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: imageHeight * 0.02),

                  // Nombre quien paga
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Nombre de quien paga:',
                        style: pw.TextStyle(
                          fontSize: imageWidth * 0.02,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(width: imageWidth * 0.02),
                      pw.Text(
                        datosPago['nombreQuienPaga'],
                        style: pw.TextStyle(fontSize: imageWidth * 0.02),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: imageHeight * 0.02),
                  // -- Fecha de pago --
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Fecha de pago:',
                        style: pw.TextStyle(
                          fontSize: imageWidth * 0.02,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(width: imageWidth * 0.02),
                      pw.Text(
                        datosPago['fechaPagoFormatted'],
                        style: pw.TextStyle(fontSize: imageWidth * 0.02),
                      ),
                    ],
                  ),

                  pw.SizedBox(height: imageHeight * 0.02),

                  // Comprobante emitido por
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Comprobante emitido por:',
                        style: pw.TextStyle(
                          fontSize: imageWidth * 0.02,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(width: imageWidth * 0.02),
                      pw.Text(
                        datosPago['reciboEmitidoPor'],
                        style: pw.TextStyle(fontSize: imageWidth * 0.02),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: imageHeight * 0.03),

                  pw.Divider(thickness: 1.5, color: PdfColors.grey700),
                  pw.SizedBox(height: imageHeight * 0.025),

                  // Identificador de pago
                  pw.Text(
                    'Identificador de pago',
                    style: pw.TextStyle(
                      fontSize: imageWidth * 0.016,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    pagoId,
                    style: pw.TextStyle(fontSize: imageWidth * 0.016),
                  ),
                  pw.SizedBox(height: imageHeight * 0.03),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  return pdf.save();
}

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
    _fetchConfig();
  }

  @override
  void dispose() {
    _beneficiaryController.dispose();
    _reasonController.dispose();
    _amountController.dispose();
    _payerController.dispose();
    _issuerController.dispose();
    _paymentDateController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _fetchConfig() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('TESORERIA')
              .doc('Config')
              .get();
      final data = doc.data();
      _configPassword = (data?['pass'] as String?) ?? '';
    } catch (_) {
      _configPassword = '';
    }
    if (!mounted) return;
    setState(() {
      _loadingConfig = false;
    });
  }

  void _checkPassword() {
    if (_passwordController.text.trim() == _configPassword) {
      setState(() {
        _authenticated = true;
      });
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Contraseña incorrecta')));
      _passwordController.clear();
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _creating = true;
    });

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

    final String pagoId = await FirestoreService.addPago(pago);

    if (!mounted) return;

    await _generatePdf(pagoId, pago);

    if (mounted) {
      setState(() {
        _creating = false;
      });
      _formKey.currentState!.reset();
      _beneficiaryController.clear();
      _branch = branches.first;
      _reasonController.clear();
      _paymentMethod = paymentOptions.first;
      _amountController.clear();
      _payerController.clear();
      _issuerController.clear();
      _paymentDateController.clear();
      _selectedPaymentDate = DateTime.now();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago guardado y comprobante descargado')),
      );
    }
  }

  Future<void> _generatePdf(
    String pagoId,
    Map<String, dynamic> datosPago,
  ) async {
    // 1) Cargo la imagen de fondo desde assets
    final ByteData bytes = await rootBundle.load('assets/back.png');
    final Uint8List bgImage = bytes.buffer.asUint8List();

    // 2) Preparo parámetros para el isolate
    final params = <String, dynamic>{
      'bgImage': bgImage,
      'pagoId': pagoId,
      'datosPago': datosPago,
    };

    // 3) Construyo el PDF en background con compute
    final Uint8List pdfBytes = await _buildPdfInBackground(params);

    if (!mounted) return;

    // 4) Comparto/descargo el PDF
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'comprobante_pago_$pagoId.pdf',
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
              maxWidth: MediaQuery.of(context).size.width * 0.8,
            ),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Ingrese la contraseña para acceder',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _checkPassword,
                      child: const Text('Verificar'),
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
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Nombre del Jóven Protagonista
                      TextFormField(
                        controller: _beneficiaryController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del Jóven Protagonista',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Obligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Rama del Jóven Protagonista
                      const Text(
                        'Rama del vendedor',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            branches.map((b) {
                              return ChoiceChip(
                                label: Text(b),
                                selected: _branch == b,
                                onSelected: (_) => setState(() => _branch = b),
                              );
                            }).toList(),
                      ),

                      const SizedBox(height: 16),
                      // Forma de pago
                      const Text(
                        'Método de pago',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            paymentOptions.map((p) {
                              return ChoiceChip(
                                label: Text(p),
                                selected: _paymentMethod == p,
                                onSelected:
                                    (_) => setState(() => _paymentMethod = p),
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 16),
                      // Razón del pago
                      TextFormField(
                        controller: _reasonController,
                        decoration: const InputDecoration(
                          labelText: 'Razón del pago',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Obligatorio';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),
                      // Cantidad del pago
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Cantidad del pago',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Obligatorio';
                          }
                          final n = double.tryParse(v.trim());
                          if (n == null) return 'Debe ser un número válido';
                          if (n <= 0) return 'Debe ser mayor que cero';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Nombre de quien paga
                      TextFormField(
                        controller: _payerController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de quien paga',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Obligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Fecha de pago (nuevo)
                      TextFormField(
                        controller: _paymentDateController,
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Fecha de pago',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _selectedPaymentDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() {
                              _selectedPaymentDate = picked;
                              _paymentDateController.text =
                                  '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
                            });
                          }
                        },
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Obligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      // Recibo emitido por
                      TextFormField(
                        controller: _issuerController,
                        decoration: const InputDecoration(
                          labelText: 'Recibo emitido por',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Obligatorio';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      _creating
                          ? const Center(child: CircularProgressIndicator())
                          : ElevatedButton(
                            onPressed: _handleSubmit,
                            child: const Text('Guardar pago'),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
