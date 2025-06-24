// lib/master.dart
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:typed_data';
import 'dart:html' as html;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';

// VARIABLES \\

//*-Estado de app-*\\
const bool xProfileMode = bool.fromEnvironment('dart.vm.profile');
const bool xReleaseMode = bool.fromEnvironment('dart.vm.product');
const bool xDebugMode = !xProfileMode && !xReleaseMode;
//*-Estado de app-*\\

bool readerApproved = false;

// FUNCIONES \\

void printLog(var text) {
  if (xDebugMode) {
    // ignore: avoid_print
    print('PrintData: $text');
  }
}

// CLASES \\

class FlavorSelection {
  String flavor;
  String size;
  String type;
  FlavorSelection({
    this.flavor = 'Membrillo',
    this.size = 'Docena',
    this.type = 'Tradicional',
  });
}

// EXCEL EXPORTER \\

class ExcelExporter {
  /// Consulta todos los pedidos en Firestore, genera un .xlsx y lo descarga.
  static Future<void> exportOrdersToExcel() async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('PASTELITOS')
              .doc('Ordenes')
              .collection('items')
              .orderBy('createdAt', descending: false)
              .get();
      final docs = querySnapshot.docs;

      // Creo workbook y hoja
      final Excel excel = Excel.createExcel();
      // Por defecto crea hoja llamada 'Sheet1'; la renombramos o usamos directamente:
      final String sheetName = excel.getDefaultSheet()!;
      final Sheet sheet = excel[sheetName];

      // --- Cabecera ---
      final header = <String>[
        'ID',
        'Comprador',
        'Vendedor',
        'Rama',
        'Método de pago',
        '¿Pago realizado?',
        'Fecha de pago',
        '¿Entregado?',
        'Fecha entrega',
        '¿Cancelado?',
        'Fecha cancelación',
        'Docenas',
        'Sabores',
      ];
      sheet.insertRowIterables(header.map((e) => TextCellValue(e)).toList(), 0);

      // Negrita en la cabecera
      for (int col = 0; col < header.length; col++) {
        final cell = sheet.cell(
          CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0),
        );
        cell.cellStyle = CellStyle(bold: true);
      }

      // --- Filas de datos ---
      for (int i = 0; i < docs.length; i++) {
        final o = docs[i].data();
        final buyer = o['buyerName'] ?? '';
        final seller = o['sellerName'] ?? '';
        final branch = o['sellerBranch'] ?? '';
        final paymentMethod = o['paymentMethod'] ?? '';
        final paid = o['paid'] == true ? 'Sí' : 'No';
        final paidAt =
            o['paidAt'] != null
                ? (o['paidAt'] as Timestamp).toDate().toIso8601String()
                : '';
        final delivered = o['delivered'] == true ? 'Sí' : 'No';
        final deliveredAt =
            o['deliveredAt'] != null
                ? (o['deliveredAt'] as Timestamp).toDate().toIso8601String()
                : '';
        final canceled = o['canceled'] == true ? 'Sí' : 'No';
        final canceledAt =
            o['canceledAt'] != null
                ? (o['canceledAt'] as Timestamp).toDate().toIso8601String()
                : '';
        final docenas = o['docenas']?.toString() ?? '';
        final flavorsList = (o['flavors'] as List)
            .cast<Map<String, dynamic>>()
            .map((f) => '${f['flavor']} (${f['size']}, ${f['type']})')
            .join('; ');

        sheet.insertRowIterables(
          <String>[
            docs[i].id,
            buyer,
            seller,
            branch,
            paymentMethod,
            paid,
            paidAt,
            delivered,
            deliveredAt,
            canceled,
            canceledAt,
            docenas,
            flavorsList,
          ].map((e) => TextCellValue(e)).toList(),
          i + 1,
        );
      }

      // --- Generar bytes y forzar descarga ---
      final fileBytes = excel.encode();
      if (fileBytes == null) {
        printLog('Error: no se pudo generar el Excel');
        return;
      }
      final blob = html.Blob([
        Uint8List.fromList(fileBytes),
      ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'pedidos.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);

      printLog('Exportación a Excel completada: pedidos.xlsx');
    } catch (e) {
      printLog('Error exportando a Excel: $e');
    }
  }
}
