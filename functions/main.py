import os
import json
import requests as http_req
from firebase_functions import https_fn
from firebase_functions.options import set_global_options
from firebase_admin import initialize_app, firestore as fb_fs

set_global_options(max_instances=10)
initialize_app()

MP_ACCESS_TOKEN = os.environ.get('MP_ACCESS_TOKEN', '')
APP_URL = 'https://sanpabloapostol-46f8c.web.app'
WEBHOOK_URL = os.environ.get(
    'WEBHOOK_URL',
    'https://mp-webhook-jyuvea4bea-uc.a.run.app ',
)


def _mp_headers() -> dict:
    return {
        'Authorization': f'Bearer {MP_ACCESS_TOKEN}',
        'Content-Type': 'application/json',
    }


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

        token = MP_ACCESS_TOKEN
        print(f'DEBUG token len={len(token)} items={len(items)} buyer={buyer_name}')

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

        webhook_url = f'https://us-central1-sanpabloapostol-46f8c.cloudfunctions.net/mp_webhook'

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
            'notification_url': webhook_url,
            'statement_descriptor': 'SPA SCOUTS',
            'binary_mode': True,
        }

        resp = http_req.post(
            'https://api.mercadopago.com/checkout/preferences',
            headers=_mp_headers(),
            json=pref_body,
            timeout=15,
        )
        
        print(f'DEBUG MP status={resp.status_code} body={resp.text[:300]}')

        if resp.status_code not in (200, 201):
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
        topic = req.args.get('topic') or req.args.get('type', '')
        resource_id = req.args.get('id', '')

        body = req.get_json(silent=True) or {}
        if not resource_id and body:
            resource_id = str(body.get('data', {}).get('id', ''))
            topic = topic or body.get('type', '')

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