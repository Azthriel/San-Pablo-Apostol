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
/// - 'datosPago': Map con todos los campos (incluido 'reciboEmitidoPor').
Future<Uint8List> _buildPdfInBackground(Map<String, dynamic> params) async {
  final Uint8List bgImage = params['bgImage'];
  final String pagoId = params['pagoId'];
  final Map<String, dynamic> datosPago = params['datosPago'];

  // 1) Creamos el documento PDF
  final pdf = pw.Document();

  // 2) Insertamos la imagen en el documento para obtener sus dimensiones
  final PdfImage backgroundImage = PdfImage.file(pdf.document, bytes: bgImage);
  final double imageWidth = backgroundImage.width.toDouble();
  final double imageHeight = backgroundImage.height.toDouble();

  final pw.MemoryImage background = pw.MemoryImage(bgImage);

  // 3) Agregamos la página con el mismo tamaño de la imagen
  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat(imageWidth, imageHeight),
      build: (pw.Context context) {
        return pw.Stack(
          children: [
            // Imagen de fondo que cubre todo
            pw.Positioned.fill(
              child: pw.Image(background, fit: pw.BoxFit.cover),
            ),

            // Contenido: alineado a la izquierda dentro de un padding proporcional
            pw.Padding(
              padding: pw.EdgeInsets.symmetric(
                horizontal: imageWidth * 0.07, // 7% de margen horizontal
                vertical: imageHeight * 0.06, // 6% de margen vertical
              ),
              child: pw.Column(
                mainAxisAlignment:
                    pw.MainAxisAlignment.center, // Mantenemos centrado vertical
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Espacio superior
                  pw.SizedBox(height: imageHeight * 0.03),

                  // ---------- TÍTULO PRINCIPAL ----------
                  pw.Text(
                    'COMPROBANTE DE PAGO',
                    style: pw.TextStyle(
                      fontSize: imageWidth * 0.04, // 4% del ancho
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: imageHeight * 0.02),

                  // ---------- FECHA DE EMISIÓN ----------
                  pw.Text(
                    'Fecha de emisión: '
                    '${DateTime.now().day.toString().padLeft(2, '0')}/'
                    '${DateTime.now().month.toString().padLeft(2, '0')}/'
                    '${DateTime.now().year}   '
                    '${DateTime.now().hour.toString().padLeft(2, '0')}:'
                    '${DateTime.now().minute.toString().padLeft(2, '0')}:'
                    '${DateTime.now().second.toString().padLeft(2, '0')}',
                    style: pw.TextStyle(
                      fontSize: imageWidth * 0.024, // 2.4% del ancho
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                  pw.SizedBox(height: imageHeight * 0.025),

                  // ---------- DIVIDER ----------
                  pw.Divider(thickness: 1.5, color: PdfColors.grey700),
                  pw.SizedBox(height: imageHeight * 0.025),

                  // ---------- CANTIDAD DEL PAGO ----------
                  pw.Text(
                    'Cantidad del pago',
                    style: pw.TextStyle(
                      fontSize: imageWidth * 0.025, // 2.5% del ancho
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '\$${(datosPago['cantidadPago'] as double).toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: imageWidth * 0.06, // 6% del ancho
                    ),
                  ),
                  pw.SizedBox(height: imageHeight * 0.035),

                  // ---------- RAZÓN DEL PAGO ----------
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Razón del pago:',
                        style: pw.TextStyle(
                          fontSize: imageWidth * 0.02, // 2% del ancho
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(width: imageWidth * 0.02),
                      pw.Container(
                        width: imageWidth * 0.55,
                        child: pw.Text(
                          datosPago['razonPago'],
                          style: pw.TextStyle(
                            fontSize: imageWidth * 0.02, // 2% del ancho
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: imageHeight * 0.02),

                  // ---------- FORMA DE PAGO ----------
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Forma de pago:',
                        style: pw.TextStyle(
                          fontSize: imageWidth * 0.02, // 2% del ancho
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(width: imageWidth * 0.02),
                      pw.Text(
                        datosPago['formaPago'],
                        style: pw.TextStyle(
                          fontSize: imageWidth * 0.02, // 2% del ancho
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: imageHeight * 0.04),

                  // ---------- DIVIDER ----------
                  pw.Divider(thickness: 1.5, color: PdfColors.grey700),
                  pw.SizedBox(height: imageHeight * 0.025),

                  // ---------- NOMBRE DEL JÓVEN PROTAGONISTA ----------
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

                  // ---------- RAMA DEL JÓVEN PROTAGONISTA ----------
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

                  // ---------- NOMBRE DE QUIEN PAGA ----------
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

                  // ---------- RECIBO EMITIDO POR (sin divider arriba) ----------
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Comprobante emitido por:',
                        style: pw.TextStyle(
                          fontSize: imageWidth * 0.02, // 2% del ancho
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(width: imageWidth * 0.02),
                      pw.Text(
                        datosPago['reciboEmitidoPor'],
                        style: pw.TextStyle(
                          fontSize: imageWidth * 0.02, // 2% del ancho
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: imageHeight * 0.03),

                  // ---------- DIVIDER ----------
                  pw.Divider(thickness: 1.5, color: PdfColors.grey700),
                  pw.SizedBox(height: imageHeight * 0.025),

                  // ---------- IDENTIFICADOR DE PAGO ----------
                  pw.Text(
                    'Identificador de pago',
                    style: pw.TextStyle(
                      fontSize: imageWidth * 0.016, // 1.6% del ancho
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    pagoId,
                    style: pw.TextStyle(
                      fontSize: imageWidth * 0.016, // 1.6% del ancho
                    ),
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

  // Controladores para cada TextField del comprobante
  late TextEditingController _beneficiaryController;
  late TextEditingController _branchController;
  late TextEditingController _reasonController;
  late TextEditingController _paymentMethodController;
  late TextEditingController _amountController;
  late TextEditingController _payerController;
  late TextEditingController _issuerController;

  // Controlador para el campo de contraseña
  late TextEditingController _passwordController;

  bool _creating = false;
  bool _loadingConfig = true;
  bool _authenticated = false;
  String _configPassword = '';

  @override
  void initState() {
    super.initState();
    _beneficiaryController = TextEditingController();
    _branchController = TextEditingController();
    _reasonController = TextEditingController();
    _paymentMethodController = TextEditingController();
    _amountController = TextEditingController();
    _payerController = TextEditingController();
    _issuerController = TextEditingController();
    _passwordController = TextEditingController();
    _fetchConfig();
  }

  @override
  void dispose() {
    _beneficiaryController.dispose();
    _branchController.dispose();
    _reasonController.dispose();
    _paymentMethodController.dispose();
    _amountController.dispose();
    _payerController.dispose();
    _issuerController.dispose();
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
      'ramaBeneficiario': _branchController.text.trim(),
      'razonPago': _reasonController.text.trim(),
      'formaPago': _paymentMethodController.text.trim(),
      'cantidadPago': double.tryParse(_amountController.text.trim()) ?? 0.0,
      'nombreQuienPaga': _payerController.text.trim(),
      'reciboEmitidoPor': _issuerController.text.trim(),
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
      _branchController.clear();
      _reasonController.clear();
      _paymentMethodController.clear();
      _amountController.clear();
      _payerController.clear();
      _issuerController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago guardado y comprobante generado')),
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
    final Uint8List pdfBytes = await compute(_buildPdfInBackground, params);

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
        appBar: AppBar(title: Text('Tesorería')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_authenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tesorería')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
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

    // Si está autenticado, muestro el UI completo para ingresar pagos
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
                      TextFormField(
                        controller: _branchController,
                        decoration: const InputDecoration(
                          labelText: 'Rama del Jóven Protagonista',
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

                      // Forma de pago
                      TextFormField(
                        controller: _paymentMethodController,
                        decoration: const InputDecoration(
                          labelText: 'Forma de pago',
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
