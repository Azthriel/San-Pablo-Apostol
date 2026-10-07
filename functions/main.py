import os
import re
import hmac
import html
import time
import smtplib
from datetime import datetime, timezone
from email.message import EmailMessage
from email.utils import formataddr, make_msgid
from io import BytesIO

import requests as http_req
from firebase_functions import https_fn, options
from firebase_functions.options import set_global_options
from firebase_admin import initialize_app, auth as fb_auth, firestore as fb_fs

set_global_options(max_instances=10)
initialize_app()

MP_ACCESS_TOKEN = os.environ.get('MP_ACCESS_TOKEN', '')
GMAIL_USER = os.environ.get('GMAIL_USER', '')
GMAIL_APP_PASSWORD = os.environ.get('GMAIL_APP_PASSWORD', '')

# 🔧 Antes apuntaba a sanpabloapostol-46f8c.web.app → las back_urls de MP
# volvían al dominio de Firebase en vez del propio.
APP_URL = 'https://gs-sanpabloapostol420.com.ar'
FUNCTIONS_URL = 'https://us-central1-sanpabloapostol-46f8c.cloudfunctions.net'


def _mp_headers() -> dict:
    return {
        'Authorization': f'Bearer {MP_ACCESS_TOKEN}',
        'Content-Type': 'application/json',
    }


def _http_error(code, message: str) -> https_fn.HttpsError:
    return https_fn.HttpsError(code=code, message=message)


def _require_role(req: https_fn.CallableRequest, role: str) -> None:
    """Corta si el usuario no tiene el custom claim `role` (staff/admin/...)."""
    token = (req.auth.token if req.auth else None) or {}
    if not token.get(role):
        raise _http_error(https_fn.FunctionsErrorCode.PERMISSION_DENIED,
                          'No tenés permiso para esta acción')


def _parse_mp_notification(req: https_fn.Request) -> tuple[str, str]:
    """Devuelve (topic, resource_id) de una notificación de MercadoPago."""
    topic = req.args.get('topic') or req.args.get('type', '')
    resource_id = req.args.get('id', '') or req.args.get('data.id', '')
    body = req.get_json(silent=True) or {}
    if not resource_id and body:
        resource_id = str(body.get('data', {}).get('id', ''))
        topic = topic or body.get('type', '')
    return topic, resource_id


# ═════════════════════════════════════════════════════════════════════════
#  AUTH DE STAFF
# ═════════════════════════════════════════════════════════════════════════

_ROLE_FIELDS = {
    'staff': 'staffPass',
    'admin': 'adminPass',
    'tesoreria': 'tesoreriaPass',
}


@https_fn.on_call(region='us-central1')
def staff_login(req: https_fn.CallableRequest) -> dict:
    """Valida la clave del lado del servidor y le pone el rol (custom claim)
    al usuario anónimo. Las reglas de Firestore chequean ese claim."""
    if req.auth is None:
        raise _http_error(https_fn.FunctionsErrorCode.UNAUTHENTICATED,
                          'Sesión no iniciada')

    data = req.data or {}
    role = str(data.get('role', ''))
    password = str(data.get('password', ''))
    field = _ROLE_FIELDS.get(role)
    if not field or not password:
        raise _http_error(https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
                          'Datos inválidos')

    db = fb_fs.client()
    claves = db.collection('PRIVADO').document('Claves').get().to_dict() or {}
    expected = str(claves.get(field, ''))

    if not expected or not hmac.compare_digest(
        password.encode('utf-8'), expected.encode('utf-8')
    ):
        time.sleep(1.5)  # frena un poco a los que prueban claves
        raise _http_error(https_fn.FunctionsErrorCode.PERMISSION_DENIED,
                          'Contraseña incorrecta')

    uid = req.auth.uid
    claims = dict(fb_auth.get_user(uid).custom_claims or {})
    claims[role] = True
    if role == 'admin':
        claims['staff'] = True  # admin implica staff
    fb_auth.set_custom_user_claims(uid, claims)

    return {'ok': True}


# ═════════════════════════════════════════════════════════════════════════
#  PASTELITOS
# ═════════════════════════════════════════════════════════════════════════

@https_fn.on_call(region='us-central1')
def create_preference(req: https_fn.CallableRequest) -> dict:
    import traceback
    try:
        data = req.data or {}
        order_data = data.get('orderData', {})
        buyer_name = order_data.get('buyerName', 'Comprador')

        db = fb_fs.client()
        config = (db.collection('PASTELITOS').document('Config').get().to_dict()) or {}

        doc_past = int(config.get('docPastelitos', 10000))
        mdoc_past = int(config.get('mdocPastelitos', 6000))
        doc_chur = int(config.get('docChurros', 8000))
        mdoc_chur = int(config.get('mdocChurros', 4000))

        items = []
        for f in order_data.get('flavors', []):
            size = f.get('size', 'Docena')
            price = doc_past if size == 'Docena' else mdoc_past
            items.append({
                'title': f"Pastelito {f.get('flavor')} {f.get('type')} ({size})",
                'quantity': 1,
                'unit_price': price,
                'currency_id': 'ARS',
            })

        churros = float(order_data.get('churros', 0))
        if churros > 0:
            full_doc = int(churros)
            half_doc = 1 if (churros - full_doc) >= 0.5 else 0
            if full_doc > 0:
                items.append({'title': 'Churros (Docena)', 'quantity': full_doc,
                              'unit_price': doc_chur, 'currency_id': 'ARS'})
            if half_doc > 0:
                items.append({'title': 'Churros (½ docena)', 'quantity': 1,
                              'unit_price': mdoc_chur, 'currency_id': 'ARS'})

        if not items:
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
                message='El pedido está vacío',
            )

        pending_col = (db.collection('PASTELITOS')
                         .document('PendingPayments')
                         .collection('items'))
        pending_ref = pending_col.document()
        pending_ref.set({
            'orderData': order_data,
            'status': 'pending',
            'createdAt': fb_fs.SERVER_TIMESTAMP,
            'orderId': None,
            'preferenceId': None,
        })
        external_ref = pending_ref.id

        pref_body = {
            'items': items,
            'payer': {'name': buyer_name},
            'back_urls': {
                'success': f'{APP_URL}/pago-ok',
                'failure': f'{APP_URL}/pago-fallido',
                'pending': f'{APP_URL}/pago-pendiente',
            },
            'auto_return': 'approved',
            'external_reference': external_ref,
            'notification_url': f'{FUNCTIONS_URL}/mp_webhook',
            'statement_descriptor': 'SPA SCOUTS',
            'binary_mode': True,
        }

        resp = http_req.post(
            'https://api.mercadopago.com/checkout/preferences',
            headers=_mp_headers(),
            json=pref_body,
            timeout=15,
        )

        if resp.status_code not in (200, 201):
            print(f'MP error status={resp.status_code} body={resp.text[:300]}')
            raise https_fn.HttpsError(
                code=https_fn.FunctionsErrorCode.INTERNAL,
                message=f'Error MP ({resp.status_code}): {resp.text[:200]}',
            )

        pref = resp.json()
        pending_ref.update({'preferenceId': pref['id']})

        return {
            'init_point': pref['init_point'],
            'sandbox_init_point': pref.get('sandbox_init_point', ''),
            'preference_id': pref['id'],
            'pending_ref_id': external_ref,
        }

    except https_fn.HttpsError:
        raise
    except Exception as e:
        tb = traceback.format_exc()
        print(f'UNHANDLED ERROR: {tb}')
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INTERNAL,
            message=f'{type(e).__name__}: {str(e)}',
        )


@https_fn.on_request(region='us-central1')
def mp_webhook(req: https_fn.Request) -> https_fn.Response:
    """Recibe notificaciones de MercadoPago y confirma pedidos."""
    try:
        topic, resource_id = _parse_mp_notification(req)
        if topic not in ('payment',) or not resource_id:
            return https_fn.Response('ignored', status=200)

        # Verificar pago en MP
        resp = http_req.get(
            f'https://api.mercadopago.com/v1/payments/{resource_id}',
            headers=_mp_headers(), timeout=15,
        )
        if resp.status_code != 200:
            return https_fn.Response('mp_error', status=200)

        payment = resp.json()
        status = payment.get('status', '')
        external_ref = payment.get('external_reference', '')
        if not external_ref:
            return https_fn.Response('no_ref', status=200)

        db = fb_fs.client()
        pending_ref = (db.collection('PASTELITOS')
                         .document('PendingPayments')
                         .collection('items')
                         .document(external_ref))
        pending_snap = pending_ref.get()
        if not pending_snap.exists:
            return https_fn.Response('not_found', status=200)

        pending_data = pending_snap.to_dict() or {}

        # Actualizar estado del pago (fuera de la transaction, no es crítico)
        pending_ref.update({
            'status': status,
            'mpPaymentId': resource_id,
            'paymentDetail': {
                'status': status,
                'status_detail': payment.get('status_detail', ''),
                'amount': payment.get('transaction_amount', 0),
                'method': payment.get('payment_method_id', ''),
            },
        })

        # Si aprobado → intentar crear la orden de forma idempotente
        if status == 'approved':
            _confirm_order(db, pending_data.get('orderData', {}),
                           resource_id, external_ref, pending_ref)

        return https_fn.Response('ok', status=200)

    except Exception as e:  # pylint: disable=broad-except
        print(f'Webhook error: {e}')
        return https_fn.Response('error', status=200)  # Siempre 200 a MP


def _confirm_order(db, order_data: dict, payment_id: str,
                   pending_ref_id: str, pending_ref):
    """Crea la orden confirmada en Firestore de forma IDEMPOTENTE.

    Usa una Firestore transaction para que, aunque MercadoPago llame al
    webhook múltiples veces para el mismo pago, la orden se cree una sola vez.
    El truco: dentro de la transaction se lee orderId y si ya existe se aborta.
    """
    total_docenas = float(order_data.get('docenas', 0))
    churros = float(order_data.get('churros', 0))
    flavors = order_data.get('flavors', [])

    mt = mv = bt = bv = 0.0
    for f in flavors:
        sabor = f.get('flavor', '')
        tipo = f.get('type', '')
        size = f.get('size', 'Docena')
        inc = 1.0 if size == 'Docena' else 0.5
        if sabor == 'Mixta':
            h = inc / 2
            if tipo == 'Tradicional':
                mt += h; bt += h
            else:
                mv += h; bv += h
        elif sabor == 'Membrillo':
            if tipo == 'Tradicional':
                mt += inc
            else:
                mv += inc
        elif sabor == 'Batata':
            if tipo == 'Tradicional':
                bt += inc
            else:
                bv += inc

    orders_col = (db.collection('PASTELITOS')
                    .document('Ordenes')
                    .collection('items'))
    order_ref = orders_col.document()  # ID nuevo, pre-generado
    totals_ref = db.collection('PASTELITOS').document('Totales')

    # ── Transaction atómica ────────────────────────────────────────────────
    # Lee orderId y escribe todo en un solo round-trip.
    # Si dos webhooks corren en paralelo, el segundo verá orderId != None
    # (seteado por el primero) y devolverá False sin crear nada.
    @fb_fs.transactional
    def _run(transaction):
        snap = pending_ref.get(transaction=transaction)
        if not snap.exists:
            return False

        if snap.to_dict().get('orderId') is not None:
            print(f'[confirm_order] Duplicado ignorado para pending={pending_ref_id}')
            return False

        # Reservar orderId + crear orden + actualizar totales — todo atómico
        transaction.update(pending_ref, {'orderId': order_ref.id})
        transaction.set(order_ref, {
            **order_data,
            'createdAt': fb_fs.SERVER_TIMESTAMP,
            'delivered': False,
            'deliveredAt': None,
            'canceled': False,
            'canceledAt': None,
            'paid': True,
            'paidAt': fb_fs.SERVER_TIMESTAMP,
            'paymentMethod': 'MercadoPago',
            'mpPaymentId': payment_id,
            'pendingRefId': pending_ref_id,
            'churros': churros,
        })
        transaction.set(totals_ref, {
            'totalDocenas': fb_fs.Increment(total_docenas),
            'membrilloTrad': fb_fs.Increment(mt),
            'membrilloVegano': fb_fs.Increment(mv),
            'batataTrad': fb_fs.Increment(bt),
            'batataVegano': fb_fs.Increment(bv),
            'totalChurros': fb_fs.Increment(churros),
            'docenasEntregadas': fb_fs.Increment(0),
        }, merge=True)
        return True

    transaction = db.transaction()
    created = _run(transaction)
    if created:
        print(f'[confirm_order] Orden {order_ref.id} creada — pago {payment_id}')


# ═════════════════════════════════════════════════════════════════════════
#  SANPAOKE — entradas para el karaoke
#
#  SANPAOKE/Config              → precioEntrada, cupo, maxPorCompra,
#                                  ventasAbiertas, fecha, hora, lugar
#  SANPAOKE/Totales             → vendidas, ingresaron
#  SANPAOKE/Compras/items/{id}  → una por pago (nombre, email, cantidad...)
#  SANPAOKE/Entradas/items/{id} → una por persona; el QR es "SPK:{id}"
# ═════════════════════════════════════════════════════════════════════════

SPK_QR_PREFIX = 'SPK:'
_EMAIL_RE = re.compile(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')

_TPL_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'templates')
# Interior blanco del cuadrado del diseño de Canva (1414×2000), en px:
# (x0, y0, x1, y1). Si cambiás el diseño, medí de nuevo estos números.
_QR_BOX = (375, 707, 1039, 1371)
_NOMBRE_Y = 1470      # centro vertical de la línea con el nombre
_NUMERO_Y = 1550      # centro vertical de "Entrada X de N"
_TEXTO_MAX_W = 1150   # ancho máximo del nombre antes de achicar la letra
_VERDE = (12, 104, 7)

_tpl_cache: dict = {}


def _spk_refs(db):
    root = db.collection('SANPAOKE')
    return {
        'config': root.document('Config'),
        'totales': root.document('Totales'),
        'compras': root.document('Compras').collection('items'),
        'entradas': root.document('Entradas').collection('items'),
    }


def _template():
    """Carga el PNG y las fuentes una sola vez por instancia."""
    if not _tpl_cache:
        from PIL import Image
        _tpl_cache['img'] = Image.open(
            os.path.join(_TPL_DIR, 'sanpaoke_entrada.png')).convert('RGB')
        _tpl_cache['font_semibold'] = os.path.join(_TPL_DIR, 'Inter-SemiBold.ttf')
        _tpl_cache['font_regular'] = os.path.join(_TPL_DIR, 'Inter-Regular.ttf')
    return _tpl_cache


def _render_entrada(entrada_id: str, nombre: str, numero: int, total: int):
    """Devuelve un PIL.Image con el diseño + QR + nombre + 'Entrada X de N'."""
    import qrcode
    from PIL import ImageDraw, ImageFont

    tpl = _template()
    img = tpl['img'].copy()
    draw = ImageDraw.Draw(img)

    # ── QR ─────────────────────────────────────────────────────────────
    x0, y0, x1, y1 = _QR_BOX
    draw.rectangle((x0, y0, x1 - 1, y1 - 1), fill='white')  # tapa "QR CODE"

    qr = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M,
                       box_size=1, border=2)
    qr.add_data(f'{SPK_QR_PREFIX}{entrada_id}')
    qr.make(fit=True)
    modules = qr.modules_count + 2 * qr.border
    box = (min(x1 - x0, y1 - y0) - 20) // modules  # módulos enteros = nítido
    qr.box_size = box
    qr_img = qr.make_image(fill_color='black', back_color='white').convert('RGB')
    qx = x0 + ((x1 - x0) - qr_img.width) // 2
    qy = y0 + ((y1 - y0) - qr_img.height) // 2
    img.paste(qr_img, (qx, qy))

    # ── Textos ────────────────────────────────────────────────────────
    cx = img.width // 2
    nombre = (nombre or '').strip() or 'Invitado/a'
    size = 64
    font = ImageFont.truetype(tpl['font_semibold'], size)
    while draw.textlength(nombre, font=font) > _TEXTO_MAX_W and size > 30:
        size -= 2
        font = ImageFont.truetype(tpl['font_semibold'], size)
    if draw.textlength(nombre, font=font) > _TEXTO_MAX_W:
        while nombre and draw.textlength(nombre + '…', font=font) > _TEXTO_MAX_W:
            nombre = nombre[:-1]
        nombre += '…'
    draw.text((cx, _NOMBRE_Y), nombre, font=font, fill='black', anchor='mm')

    font_num = ImageFont.truetype(tpl['font_regular'], 44)
    draw.text((cx, _NUMERO_Y), f'Entrada {numero} de {total}',
              font=font_num, fill=_VERDE, anchor='mm')
    return img


def _build_email(compra: dict, entradas: list[tuple[str, int]], cfg: dict,
                 to_email: str) -> EmailMessage:
    """Arma el mail con las entradas inline (PNG) + un PDF con todas."""
    nombre = compra.get('nombre', '')
    total = len(entradas)

    imgs = [_render_entrada(eid, nombre, num, total) for eid, num in entradas]
    pngs = []
    for (_, num), im in zip(entradas, imgs):
        buf = BytesIO()
        im.save(buf, format='PNG', optimize=True)
        pngs.append((f'entrada-sanpaoke-{num}.png', buf.getvalue()))
    pdf_buf = BytesIO()
    imgs[0].save(pdf_buf, format='PDF', save_all=True,
                 append_images=imgs[1:], resolution=200)

    detalles = []
    for label, key in (('Fecha', 'fecha'), ('Hora', 'hora'), ('Lugar', 'lugar')):
        if cfg.get(key):
            detalles.append((label, str(cfg[key])))

    plural = 'entradas' if total > 1 else 'entrada'
    e = html.escape
    det_html = ''.join(
        f'<p style="margin:4px 0"><b>{e(k)}:</b> {e(v)}</p>' for k, v in detalles)
    det_txt = '\n'.join(f'{k}: {v}' for k, v in detalles)

    cids = [make_msgid(domain='sanpaoke.local') for _ in pngs]
    imgs_html = ''.join(
        f'<div style="margin:16px 0;text-align:center">'
        f'<img src="cid:{cid[1:-1]}" alt="Entrada {i + 1}" '
        f'style="width:100%;max-width:380px;border-radius:12px;'
        f'border:1px solid #ddd"></div>'
        for i, cid in enumerate(cids))

    texto = (
        f'¡Hola {nombre}!\n\n'
        f'Gracias por tu compra. Te mandamos {total} {plural} para Sanpaoke 🎤\n'
        f'{det_txt}\n\n'
        'Cada entrada tiene su propio QR: mostralo en la puerta desde el celu '
        '(o impreso). Cada QR sirve para que ingrese UNA persona, una sola vez.\n\n'
        'Grupo Scout San Pablo Apóstol\n'
        f'{APP_URL}/sanpaoke\n'
    )
    cuerpo = f'''\
<div style="font-family:Arial,Helvetica,sans-serif;color:#222;max-width:520px;margin:auto">
  <h2 style="color:#0c6807;margin-bottom:4px">¡Hola {e(nombre)}! 🎤</h2>
  <p>Gracias por tu compra. Acá tenés {'tus' if total > 1 else 'tu'}
     <b>{total} {plural}</b> para <b>Sanpaoke</b>.</p>
  {det_html}
  <p style="background:#f2f7f3;padding:12px;border-radius:8px">
    Cada entrada tiene su propio QR: mostralo en la puerta desde el celu
    (o impreso). <b>Cada QR sirve para que ingrese una persona, una sola vez.</b>
    También van todas juntas en el PDF adjunto.
  </p>
  {imgs_html}
  <p style="color:#777;font-size:12px">Grupo Scout San Pablo Apóstol ·
    <a href="{APP_URL}/sanpaoke">{APP_URL.replace('https://', '')}/sanpaoke</a></p>
</div>'''

    msg = EmailMessage()
    msg['Subject'] = f'🎤 Tus {plural} para Sanpaoke ({total})'
    msg['From'] = formataddr(('Grupo Scout San Pablo Apóstol', GMAIL_USER))
    msg['To'] = to_email
    msg.set_content(texto)
    msg.add_alternative(cuerpo, subtype='html')
    html_part = msg.get_payload()[1]
    for cid, (fname, data) in zip(cids, pngs):
        html_part.add_related(data, maintype='image', subtype='png',
                              cid=cid, filename=fname)
    msg.add_attachment(pdf_buf.getvalue(), maintype='application',
                       subtype='pdf', filename='entradas-sanpaoke.pdf')
    return msg


def _send_email(msg: EmailMessage) -> None:
    if not GMAIL_USER or not GMAIL_APP_PASSWORD:
        raise RuntimeError('Faltan GMAIL_USER / GMAIL_APP_PASSWORD en functions/.env')
    with smtplib.SMTP_SSL('smtp.gmail.com', 465, timeout=30) as smtp:
        smtp.login(GMAIL_USER, GMAIL_APP_PASSWORD)
        smtp.send_message(msg)


def _emitir_entradas(db, compra_ref) -> bool:
    """Crea una entrada por persona. IDEMPOTENTE: si la compra ya tiene
    entradaIds (otro webhook llegó antes) no hace nada."""
    refs = _spk_refs(db)

    @fb_fs.transactional
    def _run(tx):
        snap = compra_ref.get(transaction=tx)
        if not snap.exists:
            return False
        compra = snap.to_dict() or {}
        if compra.get('entradaIds'):
            print(f'[sanpaoke] Entradas ya emitidas para {compra_ref.id}')
            return False

        cantidad = int(compra.get('cantidad', 0))
        ids = []
        for numero in range(1, cantidad + 1):
            ref = refs['entradas'].document()
            ids.append(ref.id)
            tx.set(ref, {
                'compraId': compra_ref.id,
                'nombre': compra.get('nombre', ''),
                'numero': numero,
                'totalCompra': cantidad,
                'usada': False,
                'usadaAt': None,
                'createdAt': fb_fs.SERVER_TIMESTAMP,
            })
        tx.update(compra_ref, {
            'entradaIds': ids,
            'emitidaAt': fb_fs.SERVER_TIMESTAMP,
        })
        tx.set(refs['totales'], {
            'vendidas': fb_fs.Increment(cantidad),
            'ingresaron': fb_fs.Increment(0),
        }, merge=True)
        return True

    created = _run(db.transaction())
    if created:
        print(f'[sanpaoke] Entradas emitidas para compra {compra_ref.id}')
    return created


def _enviar_entradas(db, compra_ref, force: bool = False) -> bool:
    """Manda el mail con las entradas. Toma un "lock" de 2 minutos en la
    compra para que dos webhooks simultáneos no manden el mail dos veces.
    Con force=True (reenvío desde la puerta) ignora emailSent."""

    @fb_fs.transactional
    def _claim(tx):
        snap = compra_ref.get(transaction=tx)
        if not snap.exists:
            return None
        compra = snap.to_dict() or {}
        if not compra.get('entradaIds'):
            return None
        if compra.get('emailSent') and not force:
            return None
        lock = compra.get('emailLockAt')
        if lock and (datetime.now(timezone.utc) - lock).total_seconds() < 120:
            return None
        tx.update(compra_ref, {'emailLockAt': fb_fs.SERVER_TIMESTAMP})
        return compra

    compra = _claim(db.transaction())
    if compra is None:
        return False

    try:
        cfg = _spk_refs(db)['config'].get().to_dict() or {}
        ids = compra['entradaIds']
        entradas = [(eid, i + 1) for i, eid in enumerate(ids)]
        msg = _build_email(compra, entradas, cfg, compra.get('email', ''))
        _send_email(msg)
    except Exception as e:  # pylint: disable=broad-except
        compra_ref.update({
            'emailError': f'{type(e).__name__}: {e}'[:300],
            'emailLockAt': fb_fs.DELETE_FIELD,
        })
        raise

    compra_ref.update({
        'emailSent': True,
        'emailSentAt': fb_fs.SERVER_TIMESTAMP,
        'emailCount': fb_fs.Increment(1),
        'emailError': fb_fs.DELETE_FIELD,
        'emailLockAt': fb_fs.DELETE_FIELD,
    })
    print(f'[sanpaoke] Mail enviado — compra {compra_ref.id}')
    return True


@https_fn.on_call(region='us-central1')
def sanpaoke_create_preference(req: https_fn.CallableRequest) -> dict:
    """Pública: crea la compra en estado pending y la preferencia de MP."""
    import traceback
    E = https_fn.FunctionsErrorCode
    try:
        data = req.data or {}
        nombre = str(data.get('nombre', '')).strip()[:80]
        email = str(data.get('email', '')).strip().lower()[:120]
        telefono = str(data.get('telefono', '')).strip()[:30]
        try:
            cantidad = int(data.get('cantidad', 0))
        except (TypeError, ValueError):
            cantidad = 0

        db = fb_fs.client()
        refs = _spk_refs(db)
        cfg = refs['config'].get().to_dict() or {}

        if not cfg.get('ventasAbiertas', False):
            raise _http_error(E.FAILED_PRECONDITION,
                              'La venta de entradas está cerrada')
        precio = int(cfg.get('precioEntrada', 0))
        if precio <= 0:
            raise _http_error(E.FAILED_PRECONDITION,
                              'Falta configurar el precio de la entrada')
        max_compra = int(cfg.get('maxPorCompra', 10))

        if len(nombre) < 2:
            raise _http_error(E.INVALID_ARGUMENT, 'Ingresá tu nombre')
        if not _EMAIL_RE.match(email):
            raise _http_error(E.INVALID_ARGUMENT, 'El email no es válido')
        if not 1 <= cantidad <= max_compra:
            raise _http_error(E.INVALID_ARGUMENT,
                              f'Podés comprar entre 1 y {max_compra} entradas')

        cupo = int(cfg.get('cupo', 0))
        if cupo > 0:
            vendidas = int((refs['totales'].get().to_dict() or {}).get('vendidas', 0))
            quedan = max(cupo - vendidas, 0)
            if cantidad > quedan:
                msg = ('¡Se agotaron las entradas!' if quedan == 0
                       else f'Solo quedan {quedan} entradas')
                raise _http_error(E.RESOURCE_EXHAUSTED, msg)

        monto = precio * cantidad
        compra_ref = refs['compras'].document()
        compra_ref.set({
            'nombre': nombre,
            'email': email,
            'telefono': telefono,
            'cantidad': cantidad,
            'precioUnitario': precio,
            'monto': monto,
            'status': 'pending',
            'entradaIds': [],
            'emailSent': False,
            'preferenceId': None,
            'createdAt': fb_fs.SERVER_TIMESTAMP,
        })

        pref_body = {
            'items': [{
                'id': 'sanpaoke-entrada',
                'title': 'Entrada Sanpaoke',
                'quantity': cantidad,
                'unit_price': precio,
                'currency_id': 'ARS',
            }],
            'payer': {'name': nombre},
            'back_urls': {
                'success': f'{APP_URL}/sanpaoke/pago',
                'failure': f'{APP_URL}/sanpaoke/pago',
                'pending': f'{APP_URL}/sanpaoke/pago',
            },
            'auto_return': 'approved',
            'external_reference': compra_ref.id,
            'notification_url': f'{FUNCTIONS_URL}/sanpaoke_webhook',
            'statement_descriptor': 'SANPAOKE',
            'binary_mode': True,
        }
        resp = http_req.post('https://api.mercadopago.com/checkout/preferences',
                             headers=_mp_headers(), json=pref_body, timeout=15)
        if resp.status_code not in (200, 201):
            print(f'[sanpaoke] MP error {resp.status_code}: {resp.text[:300]}')
            compra_ref.update({'status': 'error_preferencia'})
            raise _http_error(E.INTERNAL,
                              'No se pudo iniciar el pago, probá de nuevo')

        pref = resp.json()
        compra_ref.update({'preferenceId': pref['id']})
        return {'init_point': pref['init_point'], 'compra_id': compra_ref.id}

    except https_fn.HttpsError:
        raise
    except Exception as e:  # pylint: disable=broad-except
        print(f'[sanpaoke] UNHANDLED: {traceback.format_exc()}')
        raise _http_error(E.INTERNAL, f'{type(e).__name__}: {e}')


@https_fn.on_request(region='us-central1',
                     memory=options.MemoryOption.MB_512, timeout_sec=120)
def sanpaoke_webhook(req: https_fn.Request) -> https_fn.Response:
    """Notificaciones de MP para sanpaoke: emite entradas y manda el mail."""
    try:
        topic, resource_id = _parse_mp_notification(req)
        if topic not in ('payment',) or not resource_id:
            return https_fn.Response('ignored', status=200)

        resp = http_req.get(f'https://api.mercadopago.com/v1/payments/{resource_id}',
                            headers=_mp_headers(), timeout=15)
        if resp.status_code != 200:
            return https_fn.Response('mp_error', status=200)

        payment = resp.json()
        status = payment.get('status', '')
        external_ref = payment.get('external_reference', '')
        if not external_ref:
            return https_fn.Response('no_ref', status=200)

        db = fb_fs.client()
        compra_ref = _spk_refs(db)['compras'].document(external_ref)
        snap = compra_ref.get()
        if not snap.exists:
            return https_fn.Response('not_found', status=200)
        compra = snap.to_dict() or {}

        pagado = float(payment.get('transaction_amount', 0) or 0)
        update = {
            'status': status,
            'mpPaymentId': resource_id,
            'paymentDetail': {
                'status': status,
                'status_detail': payment.get('status_detail', ''),
                'amount': pagado,
                'method': payment.get('payment_method_id', ''),
            },
        }
        if status == 'approved' and pagado + 0.01 < float(compra.get('monto', 0)):
            # Nunca debería pasar (el monto lo arma el servidor), pero por las dudas
            print(f'[sanpaoke] Monto inválido compra={external_ref} pagado={pagado}')
            update['status'] = 'monto_invalido'
            compra_ref.update(update)
            return https_fn.Response('bad_amount', status=200)

        compra_ref.update(update)

        if status == 'approved':
            _emitir_entradas(db, compra_ref)
            try:
                _enviar_entradas(db, compra_ref)
            except Exception as e:  # pylint: disable=broad-except
                # La compra queda con emailError; se reenvía desde la puerta
                print(f'[sanpaoke] Error mandando mail {external_ref}: {e}')

        return https_fn.Response('ok', status=200)

    except Exception as e:  # pylint: disable=broad-except
        print(f'[sanpaoke] Webhook error: {e}')
        return https_fn.Response('error', status=200)  # Siempre 200 a MP


@https_fn.on_call(region='us-central1',
                  memory=options.MemoryOption.MB_512, timeout_sec=120)
def sanpaoke_reenviar(req: https_fn.CallableRequest) -> dict:
    """Staff: reenvía las entradas de una compra (opcionalmente a otro mail,
    para el que lo escribió mal)."""
    _require_role(req, 'staff')
    E = https_fn.FunctionsErrorCode
    data = req.data or {}
    compra_id = str(data.get('compraId', '')).strip()
    nuevo_email = str(data.get('email', '') or '').strip().lower()
    if not compra_id:
        raise _http_error(E.INVALID_ARGUMENT, 'Falta compraId')

    db = fb_fs.client()
    compra_ref = _spk_refs(db)['compras'].document(compra_id)
    snap = compra_ref.get()
    if not snap.exists:
        raise _http_error(E.NOT_FOUND, 'Compra no encontrada')
    if not (snap.to_dict() or {}).get('entradaIds'):
        raise _http_error(E.FAILED_PRECONDITION,
                          'Esta compra todavía no tiene entradas (pago no aprobado)')

    if nuevo_email:
        if not _EMAIL_RE.match(nuevo_email):
            raise _http_error(E.INVALID_ARGUMENT, 'El email no es válido')
        compra_ref.update({'email': nuevo_email})

    try:
        sent = _enviar_entradas(db, compra_ref, force=True)
    except Exception as e:  # pylint: disable=broad-except
        raise _http_error(E.INTERNAL, f'No se pudo mandar el mail: {e}')
    if not sent:
        raise _http_error(E.ABORTED,
                          'Se está mandando en este momento, esperá un minuto')
    return {'ok': True}
