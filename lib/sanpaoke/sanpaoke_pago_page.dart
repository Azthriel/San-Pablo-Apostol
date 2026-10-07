// lib/sanpaoke/sanpaoke_pago_page.dart
// Vuelta de MercadoPago (/sanpaoke/pago?external_reference=...&status=...).
// Escucha la compra en Firestore hasta que el webhook emite y manda las
// entradas por mail.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SanpaokePagoPage extends StatefulWidget {
  const SanpaokePagoPage({super.key});
  @override
  State<SanpaokePagoPage> createState() => _SanpaokePagoPageState();
}

class _SanpaokePagoPageState extends State<SanpaokePagoPage> {
  String? _compraId;
  String? _mpStatus;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _stream;

  @override
  void initState() {
    super.initState();
    final q = Uri.base.queryParameters;
    _compraId = q['external_reference'];
    _mpStatus = q['collection_status'] ?? q['status'];
    if (_compraId != null && _compraId!.isNotEmpty) {
      // Stream creado UNA vez acá, no en build()
      _stream =
          FirebaseFirestore.instance
              .collection('SANPAOKE')
              .doc('Compras')
              .collection('items')
              .doc(_compraId)
              .snapshots();
    }
  }

  void _volver() => Navigator.of(context).pushReplacementNamed('/sanpaoke');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 20,
        title: Image.asset('assets/spa.png', height: 58, fit: BoxFit.contain),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_stream == null) {
      return _Estado(
        icon: Icons.error_outline,
        color: Theme.of(context).colorScheme.error,
        titulo: 'No encontramos tu compra',
        texto: 'El link parece incompleto.',
        boton: ('Ir a comprar entradas', _volver),
      );
    }
    if (_mpStatus == 'rejected' || _mpStatus == 'failure' || _mpStatus == 'null') {
      return _Estado(
        icon: Icons.cancel_outlined,
        color: Colors.red,
        titulo: 'El pago no se completó',
        texto: 'No se te cobró nada. Podés intentarlo de nuevo.',
        boton: ('Volver a intentar', _volver),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return _Estado(
            icon: Icons.wifi_off,
            color: Colors.orange,
            titulo: 'No pudimos consultar tu compra',
            texto: 'Si el pago se aprobó, igual te van a llegar las entradas por mail.',
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final c = snap.data!.data();
        if (c == null) {
          return _Estado(
            icon: Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            titulo: 'No encontramos tu compra',
            boton: ('Ir a comprar entradas', _volver),
          );
        }

        final status = c['status'] as String? ?? 'pending';
        final cantidad = (c['cantidad'] as num?)?.toInt() ?? 0;
        final email = c['email'] as String? ?? '';
        final emailSent = c['emailSent'] == true;
        final emailError = c['emailError'] as String?;
        final plural = cantidad == 1 ? 'entrada' : 'entradas';

        if (status == 'approved' && emailSent) {
          return _Estado(
            icon: Icons.check_circle_outline,
            color: Theme.of(context).colorScheme.primary,
            titulo: '¡Listo! Nos vemos en Sanpaoke 🎤',
            texto:
                'Te mandamos $cantidad $plural a $email.\n'
                'Si no lo ves, revisá Spam o Promociones.\n'
                'Cada QR sirve para que entre una persona.',
          );
        }
        if (status == 'approved' && emailError != null) {
          return _Estado(
            icon: Icons.mark_email_unread_outlined,
            color: Colors.orange,
            titulo: 'Pago aprobado ✅',
            texto:
                'Tuvimos un problema mandando el mail a $email. '
                'No te preocupes: tus $cantidad $plural ya están registradas. '
                'Escribile al grupo y te las reenviamos.',
          );
        }
        if (status == 'approved') {
          return const _Estado(
            icon: Icons.hourglass_top,
            color: Colors.green,
            titulo: 'Pago aprobado ✅',
            texto: 'Estamos generando tus entradas y mandándolas por mail…',
            cargando: true,
          );
        }
        if (status == 'rejected' || status == 'cancelled') {
          return _Estado(
            icon: Icons.cancel_outlined,
            color: Colors.red,
            titulo: 'El pago no se completó',
            texto: 'No se te cobró nada. Podés intentarlo de nuevo.',
            boton: ('Volver a intentar', _volver),
          );
        }
        // pending / in_process / todavía no llegó el webhook
        return const _Estado(
          icon: Icons.schedule,
          color: Colors.orange,
          titulo: 'Esperando la confirmación del pago…',
          texto:
              'Apenas MercadoPago lo confirme te llegan las entradas por mail. '
              'Podés cerrar esta página.',
          cargando: true,
        );
      },
    );
  }
}

class _Estado extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String titulo;
  final String? texto;
  final (String, VoidCallback)? boton;
  final bool cargando;

  const _Estado({
    required this.icon,
    required this.color,
    required this.titulo,
    this.texto,
    this.boton,
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: color),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            if (texto != null) ...[
              const SizedBox(height: 10),
              Text(texto!, textAlign: TextAlign.center),
            ],
            if (cargando) ...[
              const SizedBox(height: 20),
              const LinearProgressIndicator(),
            ],
            if (boton != null) ...[
              const SizedBox(height: 24),
              FilledButton(onPressed: boton!.$2, child: Text(boton!.$1)),
            ],
          ],
        ),
      ),
    );
  }
}
