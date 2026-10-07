// lib/sanpaoke/sanpaoke_puerta_page.dart
// Interna (staff): control de ingreso de Sanpaoke. Escáner de QR, lista de
// compras con buscador, ingreso manual y reenvío de entradas por mail.
import 'package:ai_barcode_scanner/ai_barcode_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:eventosspa/firestore_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';

const _qrPrefix = 'SPK:';

final _fs = FirebaseFirestore.instance;
DocumentReference<Map<String, dynamic>> get _totalesRef =>
    _fs.collection('SANPAOKE').doc('Totales');
CollectionReference<Map<String, dynamic>> get _comprasCol =>
    _fs.collection('SANPAOKE').doc('Compras').collection('items');
CollectionReference<Map<String, dynamic>> get _entradasCol =>
    _fs.collection('SANPAOKE').doc('Entradas').collection('items');

String _hora(dynamic ts) =>
    ts is Timestamp ? DateFormat('HH:mm').format(ts.toDate()) : '--:--';

// ═══════════════════════════════════════════════════════════════════════════
//  Lógica de ingreso (transacciones → nadie entra dos veces con el mismo QR,
//  aunque dos celulares escaneen la misma entrada a la vez)
// ═══════════════════════════════════════════════════════════════════════════

enum _Resultado { ok, yaUsada, noEncontrada, noEsSanpaoke, error }

class _CheckIn {
  final _Resultado resultado;
  final Map<String, dynamic>? entrada;
  final String? detalle;
  const _CheckIn(this.resultado, {this.entrada, this.detalle});
}

Future<_CheckIn> _marcarIngreso(String entradaId) async {
  try {
    final ref = _entradasCol.doc(entradaId);
    return await _fs.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return const _CheckIn(_Resultado.noEncontrada);
      final data = snap.data()!;
      if (data['usada'] == true) {
        return _CheckIn(_Resultado.yaUsada, entrada: data);
      }
      tx.update(ref, {'usada': true, 'usadaAt': FieldValue.serverTimestamp()});
      tx.set(_totalesRef, {
        'ingresaron': FieldValue.increment(1),
      }, SetOptions(merge: true));
      return _CheckIn(_Resultado.ok, entrada: data);
    });
  } catch (e) {
    return _CheckIn(_Resultado.error, detalle: '$e');
  }
}

Future<void> _deshacerIngreso(String entradaId) async {
  final ref = _entradasCol.doc(entradaId);
  await _fs.runTransaction((tx) async {
    final snap = await tx.get(ref);
    if (snap.data()?['usada'] != true) return;
    tx.update(ref, {'usada': false, 'usadaAt': null});
    tx.set(_totalesRef, {
      'ingresaron': FieldValue.increment(-1),
    }, SetOptions(merge: true));
  });
}

// ═══════════════════════════════════════════════════════════════════════════
//  Página principal de la puerta
// ═══════════════════════════════════════════════════════════════════════════

class SanpaokePuertaPage extends StatefulWidget {
  const SanpaokePuertaPage({super.key});
  @override
  State<SanpaokePuertaPage> createState() => _SanpaokePuertaPageState();
}

class _SanpaokePuertaPageState extends State<SanpaokePuertaPage> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _totalesStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _comprasStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _entradasStream;
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    if (StaffAuth.isStaff) _initStreams();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Los streams se crean UNA vez, recién cuando hay permiso de staff
  // (antes de loguearse las reglas los rechazarían).
  void _initStreams() {
    _totalesStream = _totalesRef.snapshots();
    _comprasStream =
        _comprasCol.where('status', isEqualTo: 'approved').snapshots();
    _entradasStream = _entradasCol.limit(3000).snapshots();
  }

  void _onLogin() => setState(_initStreams);

  void _abrirScanner() => Navigator.of(
    context,
  ).push(MaterialPageRoute(builder: (_) => const _ScannerPage()));

  @override
  Widget build(BuildContext context) {
    if (!StaffAuth.isStaff) return _LoginScreen(onOk: _onLogin);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 20,
        title: const Text('Puerta Sanpaoke 🎤'),
        actions: [
          IconButton(
            tooltip: 'Ir al panel',
            icon: const Icon(Icons.dashboard_outlined),
            onPressed:
                () => Navigator.of(context).pushReplacementNamed('/pedidos'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirScanner,
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('ESCANEAR', style: TextStyle(letterSpacing: 1.2)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              _buildStats(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre o email',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon:
                        _search.isEmpty
                            ? null
                            : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _search = '');
                              },
                            ),
                  ),
                  onChanged:
                      (v) => setState(() => _search = v.trim().toLowerCase()),
                ),
              ),
              Expanded(child: _buildLista()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStats() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _totalesStream,
      builder: (context, snap) {
        final t = snap.data?.data() ?? {};
        final vendidas = (t['vendidas'] as num?)?.toInt() ?? 0;
        final ingresaron = (t['ingresaron'] as num?)?.toInt() ?? 0;
        final cs = Theme.of(context).colorScheme;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _Stat('Vendidas', '$vendidas', cs.primary),
                      _Stat('Ingresaron', '$ingresaron', cs.secondary),
                      _Stat(
                        'Faltan',
                        '${(vendidas - ingresaron).clamp(0, 1 << 30)}',
                        cs.tertiary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      minHeight: 10,
                      value: vendidas == 0 ? 0 : ingresaron / vendidas,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLista() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _comprasStream,
      builder: (context, comprasSnap) {
        if (comprasSnap.hasError) {
          return Center(child: Text('Error: ${comprasSnap.error}'));
        }
        if (!comprasSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _entradasStream,
          builder: (context, entradasSnap) {
            // Agrupar entradas por compra para mostrar "2/4 ingresaron"
            final usadasPorCompra = <String, int>{};
            for (final d in entradasSnap.data?.docs ?? const []) {
              if (d.data()['usada'] == true) {
                final id = d.data()['compraId'] as String? ?? '';
                usadasPorCompra[id] = (usadasPorCompra[id] ?? 0) + 1;
              }
            }

            var compras = comprasSnap.data!.docs.toList();
            if (_search.isNotEmpty) {
              compras =
                  compras.where((d) {
                    final c = d.data();
                    final n = (c['nombre'] as String? ?? '').toLowerCase();
                    final e = (c['email'] as String? ?? '').toLowerCase();
                    return n.contains(_search) || e.contains(_search);
                  }).toList();
            }
            compras.sort(
              (a, b) => (a.data()['nombre'] as String? ?? '')
                  .toLowerCase()
                  .compareTo((b.data()['nombre'] as String? ?? '').toLowerCase()),
            );

            if (compras.isEmpty) {
              return Center(
                child: Text(
                  _search.isEmpty ? 'Todavía no hay compras' : 'Sin resultados',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              itemCount: compras.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final doc = compras[i];
                final c = doc.data();
                final cantidad = (c['cantidad'] as num?)?.toInt() ?? 0;
                final usadas = usadasPorCompra[doc.id] ?? 0;
                final completa = usadas >= cantidad && cantidad > 0;
                final mailMal =
                    c['emailError'] != null || c['emailSent'] != true;
                return Card(
                  child: ListTile(
                    onTap:
                        () => showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          showDragHandle: true,
                          builder: (_) => _CompraSheet(compraId: doc.id),
                        ),
                    leading: CircleAvatar(
                      backgroundColor:
                          completa
                              ? Colors.green.withValues(alpha: 0.15)
                              : Colors.grey.withValues(alpha: 0.12),
                      child: Text(
                        '$usadas/$cantidad',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: completa ? Colors.green.shade800 : null,
                        ),
                      ),
                    ),
                    title: Text(
                      c['nombre'] as String? ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(c['email'] as String? ?? ''),
                    trailing:
                        mailMal
                            ? const Tooltip(
                              message: 'El mail no salió — tocá para reenviar',
                              child: Icon(
                                Icons.mark_email_unread_outlined,
                                color: Colors.red,
                              ),
                            )
                            : const Icon(Icons.chevron_right),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
      ],
    ),
  );
}

// ═══════════════════════════════════════════════════════════════════════════
//  Detalle de una compra: entradas, ingreso manual y reenvío del mail
// ═══════════════════════════════════════════════════════════════════════════

class _CompraSheet extends StatefulWidget {
  final String compraId;
  const _CompraSheet({required this.compraId});
  @override
  State<_CompraSheet> createState() => _CompraSheetState();
}

class _CompraSheetState extends State<_CompraSheet> {
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _compraStream;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _entradasStream;
  bool _enviando = false;
  String? _msg; // resultado del reenvío (un SnackBar quedaría tapado por el sheet)

  @override
  void initState() {
    super.initState();
    _compraStream = _comprasCol.doc(widget.compraId).snapshots();
    _entradasStream =
        _entradasCol.where('compraId', isEqualTo: widget.compraId).snapshots();
  }

  Future<void> _reenviar(String emailActual) async {
    final ctrl = TextEditingController(text: emailActual);
    final email = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Reenviar entradas'),
            content: TextField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                helperText: 'Si lo escribió mal, corregilo acá',
                prefixIcon: Icon(Icons.mail_outline),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: const Text('Enviar'),
              ),
            ],
          ),
    );
    ctrl.dispose();
    if (email == null || email.isEmpty || !mounted) return;

    setState(() {
      _enviando = true;
      _msg = null;
    });
    String msg;
    try {
      await FirebaseFunctions.instance
          .httpsCallable('sanpaoke_reenviar')
          .call({
            'compraId': widget.compraId,
            if (email != emailActual) 'email': email,
          });
      msg = '✅ Entradas reenviadas a $email';
    } on FirebaseFunctionsException catch (e) {
      msg = '❌ ${e.message ?? e.code}';
    } catch (e) {
      msg = '❌ Error: $e';
    }
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _msg = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _compraStream,
          builder: (context, compraSnap) {
            final c = compraSnap.data?.data();
            if (c == null) {
              return const SizedBox(
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final email = c['email'] as String? ?? '';
            final emailError = c['emailError'] as String?;
            final emailSent = c['emailSent'] == true;
            final tel = c['telefono'] as String? ?? '';

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  c['nombre'] as String? ?? '',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(email),
                if (tel.isNotEmpty) Text(tel),
                const SizedBox(height: 8),
                if (emailError != null)
                  Text(
                    '⚠️ El mail falló: $emailError',
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  )
                else if (!emailSent)
                  const Text(
                    '⚠️ El mail todavía no salió',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                const Divider(height: 24),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _entradasStream,
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final docs =
                        snap.data!.docs.toList()..sort(
                          (a, b) => ((a.data()['numero'] as num?) ?? 0)
                              .compareTo((b.data()['numero'] as num?) ?? 0),
                        );
                    return Column(
                      children: [
                        for (final d in docs) _EntradaTile(doc: d),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _enviando ? null : () => _reenviar(email),
                  icon:
                      _enviando
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.forward_to_inbox_outlined),
                  label: Text(_enviando ? 'Enviando…' : 'Reenviar mail'),
                ),
                if (_msg != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_msg!, textAlign: TextAlign.center),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EntradaTile extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  const _EntradaTile({required this.doc});

  @override
  Widget build(BuildContext context) {
    final e = doc.data();
    final usada = e['usada'] == true;
    final numero = e['numero'] ?? '?';
    final total = e['totalCompra'] ?? '?';

    Future<void> toggle() async {
      if (usada) {
        final ok = await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('¿Deshacer ingreso?'),
                content: Text('La entrada $numero de $total vuelve a quedar sin usar.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('No'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Deshacer'),
                  ),
                ],
              ),
        );
        if (ok == true) await _deshacerIngreso(doc.id);
      } else {
        final r = await _marcarIngreso(doc.id);
        if (r.resultado == _Resultado.error && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${r.detalle}')));
        }
      }
    }

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        usada ? Icons.check_circle : Icons.radio_button_unchecked,
        color: usada ? Colors.green : Colors.grey,
      ),
      title: Text('Entrada $numero de $total'),
      subtitle: Text(usada ? 'Ingresó a las ${_hora(e['usadaAt'])}' : 'Sin usar'),
      trailing:
          usada
              ? TextButton(onPressed: toggle, child: const Text('Deshacer'))
              : FilledButton.tonal(
                onPressed: toggle,
                child: const Text('Marcar ingreso'),
              ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Escáner: lee el QR, marca el ingreso y muestra un cartel GRANDE
//  verde/rojo para que en la puerta se vea de lejos.
// ═══════════════════════════════════════════════════════════════════════════

class _ScannerPage extends StatefulWidget {
  const _ScannerPage();
  @override
  State<_ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<_ScannerPage> {
  bool _checkingPermission = true;
  bool _hasPermission = false;
  bool _processing = false;
  _CheckIn? _ultimo;
  String? _ultimoCodigo;
  DateTime _ultimoAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _pedirPermiso();
  }

  Future<void> _pedirPermiso() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() {
      _hasPermission = status.isGranted;
      _checkingPermission = false;
    });
  }

  Future<void> _onCode(String raw) async {
    final code = raw.trim();
    final now = DateTime.now();
    // El escáner dispara muchas veces por segundo con el mismo QR
    if (_processing || _ultimo != null) return;
    if (code == _ultimoCodigo && now.difference(_ultimoAt).inSeconds < 5) {
      return;
    }
    _ultimoCodigo = code;
    _ultimoAt = now;

    if (!code.startsWith(_qrPrefix)) {
      setState(() => _ultimo = const _CheckIn(_Resultado.noEsSanpaoke));
      return;
    }
    setState(() => _processing = true);
    final r = await _marcarIngreso(code.substring(_qrPrefix.length));
    if (!mounted) return;
    setState(() {
      _processing = false;
      _ultimo = r;
    });
    // El verde se cierra solo; los errores esperan un toque
    if (r.resultado == _Resultado.ok) {
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted && identical(_ultimo, r)) setState(() => _ultimo = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('Escanear entrada')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (!_hasPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('Escanear entrada')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.videocam_off, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Necesitamos acceso a la cámara. Habilitalo desde el '
                  'candadito en la barra de direcciones.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _pedirPermiso,
                  child: const Text('Volver a intentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        AiBarcodeScanner(
          onDetect: (BarcodeCapture capture) {
            final code = capture.barcodes.firstOrNull?.rawValue;
            if (code != null && code.isNotEmpty) _onCode(code);
          },
        ),
        if (_processing)
          const ColoredBox(
            color: Colors.black54,
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_ultimo != null)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _ultimo = null),
              child: _ResultadoOverlay(r: _ultimo!),
            ),
          ),
      ],
    );
  }
}

class _ResultadoOverlay extends StatelessWidget {
  final _CheckIn r;
  const _ResultadoOverlay({required this.r});

  @override
  Widget build(BuildContext context) {
    final e = r.entrada ?? {};
    final nombre = e['nombre'] as String? ?? '';
    final numero = '${e['numero'] ?? '?'} de ${e['totalCompra'] ?? '?'}';

    final (Color color, IconData icon, String titulo, String sub) =
        switch (r.resultado) {
          _Resultado.ok => (
            Colors.green.shade700,
            Icons.check_circle,
            '¡PASÁ!',
            '$nombre\nEntrada $numero',
          ),
          _Resultado.yaUsada => (
            Colors.red.shade700,
            Icons.block,
            'YA INGRESÓ',
            '$nombre · Entrada $numero\nUsada a las ${_hora(e['usadaAt'])}',
          ),
          _Resultado.noEncontrada => (
            Colors.red.shade700,
            Icons.help_outline,
            'NO EXISTE',
            'Esta entrada no está registrada',
          ),
          _Resultado.noEsSanpaoke => (
            Colors.orange.shade800,
            Icons.qr_code_2,
            'QR INVÁLIDO',
            'Este QR no es una entrada de Sanpaoke',
          ),
          _Resultado.error => (
            Colors.grey.shade800,
            Icons.wifi_off,
            'ERROR',
            r.detalle ?? 'Probá de nuevo',
          ),
        };

    return Material(
      color: color.withValues(alpha: 0.96),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 140, color: Colors.white),
                const SizedBox(height: 16),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  sub,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 22),
                ),
                const SizedBox(height: 32),
                Text(
                  r.resultado == _Resultado.ok
                      ? ''
                      : 'Tocá para seguir escaneando',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  Login de staff (misma clave que el panel interno)
// ═══════════════════════════════════════════════════════════════════════════

class _LoginScreen extends StatefulWidget {
  final VoidCallback onOk;
  const _LoginScreen({required this.onOk});
  @override
  State<_LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<_LoginScreen> {
  final _ctrl = TextEditingController();
  bool _checking = false;
  String? _error;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final pass = _ctrl.text;
    _ctrl.clear();
    setState(() {
      _checking = true;
      _error = null;
    });
    String? error;
    try {
      if (!await StaffAuth.login(StaffRole.staff, pass)) {
        error = 'Contraseña incorrecta';
      }
    } catch (_) {
      error = 'Error de conexión, probá de nuevo';
    }
    if (!mounted) return;
    setState(() {
      _checking = false;
      _error = error;
    });
    if (error == null) widget.onOk();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 20,
        title: Image.asset('assets/spa.png', height: 58, fit: BoxFit.contain),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic_external_on, size: 40, color: cs.primary),
                    const SizedBox(height: 12),
                    const Text(
                      'Puerta Sanpaoke',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _ctrl,
                      obscureText: true,
                      autofocus: true,
                      enabled: !_checking,
                      decoration: InputDecoration(
                        labelText: 'Contraseña de staff',
                        prefixIcon: const Icon(Icons.key_outlined),
                        errorText: _error,
                      ),
                      onSubmitted: (_) => _entrar(),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _checking ? null : _entrar,
                        child:
                            _checking
                                ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Text('Entrar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
