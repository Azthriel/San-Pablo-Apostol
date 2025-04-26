# Proyecto web Flutter para gestionar pedidos de pastelitos en el grupo scout San Pablo Apostol

![Logo](assets/spa.png)

## Descripción

Esta aplicación web, construida con Flutter Web y Firebase, permite a los miembros de tu grupo scout:

- **Realizar pedidos** de pastelitos (docenas o medias docenas) y elegir sabores (Membrillo, Batata, Mixta).
- **Seleccionar método de pago** (Efectivo o Transferencia) y marcar si ya pagaron.
- **Marcar entrega** de los pedidos y registrar la fecha/hora.
- **Visualizar totales** de docenas y desglose por sabores en tiempo real.
- **Filtrar** la lista de pedidos por rama y por nombre de vendedor.
- **Proteger** acceso a la lista de pedidos mediante contraseña.

## Tecnologías

- [Flutter Web](https://flutter.dev)
- [Firebase Firestore](https://firebase.google.com/docs/firestore)
- [Cloud Firestore](https://pub.dev/packages/cloud_firestore)
- [intl](https://pub.dev/packages/intl)

## Estructura

```dart
lib/
├── main.dart           # Entry point y navegación entre pantallas
├── orders.dart         # Formulario para agregar pedidos
├── orders_list.dart    # Lista de pedidos con filtros y botones de estado
├── totals_page.dart    # Pantalla de totales en tiempo real
├── firestore_service.dart  # Lógica de lectura/escritura en Firestore
├── master.dart         # Modelos y utilidades (FlavorSelection, printLog)
└── firebase_options.dart   # Configuración de Firebase (generado por FlutterFire CLI)
assets/
└── spa.png             # Logotipo usado en el AppBar
pubspec.yaml           # Dependencias y assets
README.md
```

## Requisitos

- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- Cuenta de Firebase con un proyecto configurado (Firestore habilitado).
- FlutterFire CLI para generar `firebase_options.dart`.

## Contraseña de acceso

- La pestaña de lista de pedidos está protegida con la contraseña por defecto: `LexieChicho2025`.
