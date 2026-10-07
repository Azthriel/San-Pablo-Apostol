// lib/sanpaoke/sanpaoke_page.dart
// Pública: compra de entradas para Sanpaoke (karaoke) con MercadoPago.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quarks_footer/quarks_footer.dart';
import 'package:url_launcher/url_launcher.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _money = NumberFormat.currency(locale: 'es_AR', symbol: r'$', decimalDigits: 0);

class SanpaokePage extends StatefulWidget {
  const SanpaokePage({super.key});
  @override
  State<SanpaokePage> createState() => _SanpaokePageState();
}

class _SanpaokePageState extends State<SanpaokePage> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _email2Ctrl = TextEditingController();
  final _telCtrl = TextEditingController();

  // Config leída UNA vez en initState (no en build)
  late final Future<Map<String, dynamic>> _configFuture;
  int _cantidad = 1;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _configFuture = FirebaseFirestore.instance
        .collection('SANPAOKE')
        .doc('Config')
        .get()
        .then((d) => d.data() ?? <String, dynamic>{});
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _emailCtrl.dispose();
    _email2Ctrl.dispose();
    _telCtrl.dispose();
    super.dispose();
  }

  Future<void> _pagar() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await FirebaseFunctions.instance
          .httpsCallable('sanpaoke_create_preference')
          .call({
            'nombre': _nombreCtrl.text.trim(),
            'email': _emailCtrl.text.trim(),
            'telefono': _telCtrl.text.trim(),
            'cantidad': _cantidad,
          });
      final data = Map<String, dynamic>.from(res.data as Map);
      final initPoint = data['init_point'] as String? ?? '';
      if (initPoint.isEmpty) throw Exception('No se recibió el link de pago');
      // '_self': MP vuelve a /sanpaoke/pago en esta misma pestaña
      await launchUrl(Uri.parse(initPoint), webOnlyWindowName: '_self');
    } on FirebaseFunctionsException catch (e) {
      _snack(e.message ?? 'No se pudo iniciar el pago');
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 20,
        title: Image.asset('assets/spa.png', height: 58, fit: BoxFit.contain),
      ),
      bottomNavigationBar: const QuarksFooter(
        backgroundColor: Colors.white,
        textColor: Colors.black,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _configFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error cargando el evento: ${snap.error}'));
          }
          return _buildContent(context, snap.data ?? {});
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, Map<String, dynamic> cfg) {
    final cs = Theme.of(context).colorScheme;
    final abiertas = cfg['ventasAbiertas'] == true;
    final precio = (cfg['precioEntrada'] as num?)?.toInt() ?? 0;
    final maxCompra = (cfg['maxPorCompra'] as num?)?.toInt() ?? 10;
    if (_cantidad > maxCompra) _cantidad = maxCompra;
    final detalles = <(IconData, String)>[
      if ((cfg['fecha'] ?? '').toString().isNotEmpty)
        (Icons.event_outlined, cfg['fecha'].toString()),
      if ((cfg['hora'] ?? '').toString().isNotEmpty)
        (Icons.schedule_outlined, cfg['hora'].toString()),
      if ((cfg['lugar'] ?? '').toString().isNotEmpty)
        (Icons.place_outlined, cfg['lugar'].toString()),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Banner del evento ─────────────────────────────────
              Card(
                color: cs.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.mic_external_on,
                              color: cs.onPrimaryContainer, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Sanpaoke 🎤',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: cs.onPrimaryContainer,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Noche de karaoke del Grupo Scout San Pablo Apóstol',
                        style: TextStyle(color: cs.onPrimaryContainer),
                      ),
                      if (detalles.isNotEmpty) const SizedBox(height: 12),
                      for (final (icon, txt) in detalles)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            children: [
                              Icon(icon, size: 18, color: cs.onPrimaryContainer),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  txt,
                                  style: TextStyle(
                                    color: cs.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!abiertas || precio <= 0)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(Icons.event_busy_outlined,
                            size: 40, color: cs.secondary),
                        const SizedBox(height: 12),
                        const Text(
                          'La venta de entradas no está habilitada',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Volvé a pasar más adelante 🙌',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                _buildForm(context, precio, maxCompra),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, int precio, int maxCompra) {
    final cs = Theme.of(context).colorScheme;
    final total = precio * _cantidad;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Comprá tus entradas',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Te llegan por mail, con un QR por persona.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nombreCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nombre y apellido',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator:
                    (v) =>
                        (v == null || v.trim().length < 2)
                            ? 'Ingresá tu nombre'
                            : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email (acá te llegan las entradas)',
                  prefixIcon: Icon(Icons.mail_outline),
                ),
                validator:
                    (v) =>
                        _emailRe.hasMatch(v?.trim() ?? '')
                            ? null
                            : 'Ingresá un email válido',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email2Ctrl,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Repetí el email',
                  prefixIcon: Icon(Icons.mark_email_read_outlined),
                ),
                validator:
                    (v) =>
                        (v?.trim().toLowerCase() ==
                                _emailCtrl.text.trim().toLowerCase())
                            ? null
                            : 'Los emails no coinciden',
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono (opcional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: 20),

              // ── Cantidad ──────────────────────────────────────────
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Cantidad de entradas',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton.outlined(
                    icon: const Icon(Icons.remove),
                    onPressed:
                        _cantidad > 1
                            ? () => setState(() => _cantidad--)
                            : null,
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '$_cantidad',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton.filled(
                    icon: const Icon(Icons.add),
                    onPressed:
                        _cantidad < maxCompra
                            ? () => setState(() => _cantidad++)
                            : null,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${_money.format(precio)} por entrada · máximo $maxCompra por compra',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const Divider(height: 32),
              Row(
                children: [
                  const Text('Total', style: TextStyle(fontSize: 16)),
                  const Spacer(),
                  Text(
                    _money.format(total),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: cs.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _loading ? null : _pagar,
                icon:
                    _loading
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                        : const Icon(Icons.payment),
                label: Text(_loading ? 'Abriendo MercadoPago…' : 'Pagar con MercadoPago'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
