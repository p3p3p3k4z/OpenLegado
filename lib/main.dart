import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

// Importaciones de Firebase
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // Este archivo se genera con `flutterfire configure`

// --------- IMPORTACIONES PARA NOTIFICACIONES FCM ---------
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert'; // Para codificar/decodificar JSON en el payload

// --------- IMPORTACIONES PARA ANUNCIOS ---------
import 'config/app_config.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mobile_ads/google_mobile_ads.dart';

// --- INICIO: Variables Globales para Notificaciones ---
/// Globalmente accesible o inyectado donde sea necesario
final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

/// Opcional: Configuración para flutter_local_notifications
FlutterLocalNotificationsPlugin? _flutterLocalNotificationsPlugin;
AndroidNotificationChannel? _androidNotificationChannel;

// Es buena práctica tener una clave de navegador global si necesitas navegar desde un callback de notificación
// GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(); // Descomenta si la necesitas

// --- FIN: Variables Globales para Notificaciones ---


// --- INICIO: Manejador de mensajes en segundo plano (background/terminated) ---
// DEBE SER UNA FUNCIÓN DE NIVEL SUPERIOR (fuera de cualquier clase)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Si estás usando otros plugins de Firebase en el manejador de segundo plano,
  // asegúrate de llamar a `initializeApp` antes de usarlos.
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform); // Descomentar si es necesario

  print("Handling a background message: ${message.messageId}");
  print('Message data: ${message.data}');
  if (message.notification != null) {
    print('Message also contained a notification: ${message.notification!.title}');
  }
  // Aquí podrías guardar la notificación en almacenamiento local si es necesario,
  // o realizar alguna tarea ligera. NO actualices UI directamente desde aquí.
}
// --- FIN: Manejador de mensajes en segundo plano ---

void main() async {
  // 1. Asegura que los widgets de Flutter estén inicializados
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicializa Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting('es_MX', null);

  // --- INICIO: Configuración de Notificaciones FCM ---
  // Establecer el manejador de mensajes en segundo plano
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Solicitar permisos de notificación (importante para iOS y Android 13+)
  await _requestNotificationPermissions();

  // Inicializar listeners de FCM para mensajes en primer plano y abiertos
  await _initFCMListeners();

  // Opcional: Inicializar flutter_local_notifications
  await _initLocalNotifications();

  // Opcional: Obtener y mostrar/guardar el token FCM
  _getAndPrintFCMToken();
  // --- FIN: Configuración de Notificaciones FCM ---


  // 3. Inicializa Servicios de Anuncios (condicionalmente)
  //    Tu código de anuncios existente permanece aquí...
  if (AppConfig.adsEnabled) {
    if (kIsWeb && AppConfig.adsEnabledWeb) {
      print("MAIN: Anuncios Web (AdSense) están configurados...");
    } else if (!kIsWeb && (AppConfig.adsEnabledAndroid)) {
      try {
        print("MAIN: Intentando inicializar Google Mobile Ads SDK...");
        await MobileAds.instance.initialize();
        print("MAIN: Google Mobile Ads SDK inicializado correctamente.");
      } catch (e) {
        print("MAIN: Error al inicializar Google Mobile Ads SDK: $e");
      }
    } else if (!kIsWeb) {
      print("MAIN: Anuncios móviles (AdMob) deshabilitados...");
    }
  } else {
    print("MAIN: Los anuncios están globalmente deshabilitados...");
  }

  // 4. Ejecuta la aplicación
  runApp(LegadoApp());
}

// --- INICIO: Funciones Auxiliares para Notificaciones ---
Future<void> _requestNotificationPermissions() async {
  NotificationSettings settings = await _firebaseMessaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('User granted notification permission');
  } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
    print('User granted provisional notification permission');
  } else {
    print('User declined or has not accepted notification permission');
    // Considera mostrar un diálogo explicando por qué necesitas los permisos si fueron denegados.
  }
}

Future<void> _initLocalNotifications() async {
  _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  _androidNotificationChannel = const AndroidNotificationChannel(
    'legado_high_importance_channel', // ID único del canal
    'Notificaciones Importantes de Legado', // Título visible para el usuario
    description: 'Este canal se usa para notificaciones importantes de la app Legado.', // Descripción
    importance: Importance.high,
    playSound: true,
  );

  // Crear el canal en Android
  await _flutterLocalNotificationsPlugin!
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_androidNotificationChannel!);

  // Configuración de inicialización para Android e iOS
  const AndroidInitializationSettings initializationSettingsAndroid =
  AndroidInitializationSettings('@mipmap/ic_launcher'); // Usa el icono de tu app

  final DarwinInitializationSettings initializationSettingsIOS =
  DarwinInitializationSettings(
      onDidReceiveLocalNotification: _onDidReceiveIOSLocalNotification);

  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  await _flutterLocalNotificationsPlugin!.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: _onDidReceiveLocalNotificationResponse,
  );
}

// Callback para iOS < 10 (raro hoy en día, pero bueno tenerlo por completitud)
void _onDidReceiveIOSLocalNotification(
    int id, String? title, String? body, String? payload) async {
  print('iOS < 10 local notification received: $title with payload: $payload');
  // Aquí podrías mostrar un diálogo o manejar el payload
}

// Callback cuando se toca una notificación LOCAL (mostrada por flutter_local_notifications)
void _onDidReceiveLocalNotificationResponse(NotificationResponse notificationResponse) async {
  final String? payload = notificationResponse.payload;
  if (payload != null) {
    debugPrint('Local notification payload: $payload');
    try {
      Map<String, dynamic> data = json.decode(payload);
      _handleMessageNavigation(data, "Local Notification Tap");
    } catch (e) {
      debugPrint('Error decoding payload: $e. Payload was: $payload');
      // Manejar el payload como una simple cadena si no es JSON
      // o intentar navegar con el payload directamente si es una ruta simple.
    }
  }
}

Future<void> _initFCMListeners() async {
  // 1. Cuando la app está en primer plano
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('FCM: Got a message whilst in the foreground!');
    print('FCM: Message data: ${message.data}');

    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android; // Específico de Android

    // Si el mensaje contiene una carga de notificación y tenemos el plugin local inicializado
    if (notification != null && _flutterLocalNotificationsPlugin != null && _androidNotificationChannel != null) {
      print('FCM: Message also contained a notification: ${notification.title}');

      _flutterLocalNotificationsPlugin!.show(
        notification.hashCode, // ID único para la notificación
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _androidNotificationChannel!.id,
            _androidNotificationChannel!.name,
            channelDescription: _androidNotificationChannel!.description,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            // color: Color(0xFFE67E22), // Puedes definir un color aquí también
            // largeIcon: ..., // Si quieres un icono grande
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: json.encode(message.data), // Pasar los datos de FCM como payload
      );
    }
  });

  // 2. Cuando la app está en segundo plano y el usuario toca la notificación
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('FCM: A new onMessageOpenedApp event was published!');
    print('FCM: Message data: ${message.data}');
    if (message.notification != null) {
      print('FCM: Message from onMessageOpenedApp also contained a notification: ${message.notification!.title}');
    }
    _handleMessageNavigation(message.data, "Notification Tap (Background)");
  });

  // 3. Cuando la app está terminada y se abre desde una notificación
  RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
  if (initialMessage != null) {
    print('FCM: App opened from terminated state via notification:');
    print('FCM: Initial message data: ${initialMessage.data}');
    if (initialMessage.notification != null) {
      print('FCM: Initial message also contained a notification: ${initialMessage.notification!.title}');
    }
    // Esperar un poco para que el widget tree se construya si es necesario antes de navegar
    Future.delayed(Duration(milliseconds: 500), () { // Reducido el delay
      _handleMessageNavigation(initialMessage.data, "Notification Tap (Terminated)");
    });
  }
}

void _handleMessageNavigation(Map<String, dynamic> data, String source) {
  print("Source: $source - Attempting to navigate with data: $data");
  // Aquí implementas tu lógica de navegación.
  // Por ejemplo, si envías un dato como {'screen_to_open': '/detalle_articulo', 'item_id': '123'}
  final String? screenRoute = data['screen_to_open'] as String?;
  final String? itemId = data['item_id'] as String?;

  if (screenRoute != null) {
    print("Navigating to $screenRoute with itemId: $itemId");
    // DESCOMENTA Y USA TU navigatorKey si lo tienes configurado en MaterialApp
    // Y asegúrate de que `navigatorKey` está asignado en `MaterialApp`.
    // if (navigatorKey.currentState != null) {
    //   if (itemId != null) {
    //     navigatorKey.currentState!.pushNamed(screenRoute, arguments: {'id': itemId});
    //   } else {
    //     navigatorKey.currentState!.pushNamed(screenRoute);
    //   }
    // } else {
    //   print("NavigatorKey is null, cannot navigate.");
    // }
    // Por ahora, solo imprimiremos un mensaje
    // En una app real, aquí iría tu código de `Navigator.pushNamed` o GoRouter, etc.
  } else {
    print("No 'screen_to_open' data found in notification payload for navigation.");
  }
}

Future<void> _getAndPrintFCMToken() async {
  String? token = await _firebaseMessaging.getToken();
  print("FirebaseMessaging Token: $token");

  // Escuchar cambios en el token (raro, pero puede ocurrir)
  _firebaseMessaging.onTokenRefresh.listen((newToken) {
    print("New FCM Token refreshed: $newToken");
    // Aquí deberías enviar el nuevo token a tu servidor si lo estás almacenando
    // await saveTokenToDatabase(newToken);
  });
}
// --- FIN: Funciones Auxiliares para Notificaciones ---

class LegadoApp extends StatelessWidget {
  const LegadoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // navigatorKey: navigatorKey, // Descomenta si usas la GlobalKey para navegación desde los callbacks
      title: 'Legado',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        primaryColor: Color(0xFFE67E22), // Naranja mexicano más vibrante
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFFE67E22),
          secondary: Color(0xFF8B4513), // Marrón tierra
          surface: Color(0xFFFFF8DC), // Beige suave
        ),
        fontFamily: 'Georgia',
        textTheme: TextTheme(
          headlineMedium: TextStyle(
            fontSize: 24,
            fontFamily: 'Georgia',
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B4513),
          ),
          bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF5D4037)),
          bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF6D4C41)),
        ),
        cardTheme: CardThemeData(
          elevation: 8,
          shadowColor: Colors.black26,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFE67E22),
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: Colors.black26,
          ),
        ),
      ),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [
        const Locale('en', ''),
        const Locale('es', ''),
        const Locale('es', 'MX'),
      ],
      home: WelcomeScreen(),
      // Define tus rutas aquí si vas a usar navegación por nombre desde las notificaciones
      // routes: {
      //   '/home': (context) => HomeScreen(),
      //   '/detalle_articulo': (context) => DetalleArticuloScreen(), // Asumiendo que tienes esta pantalla
      //   // ... otras rutas
      // },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: double.infinity,
                    child: Image.asset(
                      'assets/fondo_mexicano.jpg',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      isAntiAlias: true,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).primaryColor,
                                Theme.of(context).colorScheme.secondary,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(color: Colors.black.withOpacity(0.3)),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          height: 80,
                          width: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/legado.jpg',
                                height: 64,
                                width: 64,
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                                isAntiAlias: true,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.temple_hindu,
                                    size: 35,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Descubre el alma de México',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontFamily: 'Georgia',
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Experiencias Auténticas', style: Theme.of(context).textTheme.headlineMedium),
                  SizedBox(height: 15),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildExperienceCard(
                          context,
                          title: 'Taller de Barro Negro',
                          location: 'San Bartolo Coyotepec, Oaxaca',
                          price: 350,
                          image: 'assets/barro_negro.jpg',
                          isVerified: true,
                        ),
                        _buildExperienceCard(
                          context,
                          title: 'Cocina de Mole en Cazuela',
                          location: 'Puebla, Puebla',
                          price: 420,
                          image: 'assets/mole_poblano.jpg',
                        ),
                        _buildExperienceCard(
                          context,
                          title: 'Tejido de Sarapes',
                          location: 'Teotitlán del Valle, Oaxaca',
                          price: 380,
                          image: 'assets/sarapes.jpg',
                          isVerified: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rutas del Patrimonio', style: Theme.of(context).textTheme.headlineMedium),
                  SizedBox(height: 15),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(color: Colors.grey.withOpacity(0.3), blurRadius: 10)
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: Stack(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: double.infinity,
                            child: Image.asset(
                              'assets/mapa_cultural.jpg',
                              fit: BoxFit.cover,
                              filterQuality: FilterQuality.high,
                              isAntiAlias: true,
                              cacheWidth: 1000,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Theme.of(context).primaryColor,
                                        Theme.of(context).colorScheme.secondary,
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.map, size: 48, color: Colors.white70),
                                        SizedBox(height: 8),
                                        Text(
                                          'Mapa Cultural Interactivo',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Positioned(
                            bottom: 10,
                            left: 10,
                            child: Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 18,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Ruta del Mezcal Artesanal',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF5D4037),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              margin: EdgeInsets.all(20),
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFFF8DC),
                    Color(0xFFF5E6D3),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 15,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tu Huella Cultural',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Color(0xFF5D4037),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                '128',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Artesanos apoyados',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF6D4C41),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Text(
                                '\$42,380',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF388E3C),
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Al fondo comunitario',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF6D4C41),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: 0.65,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                          minHeight: 12,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Escuela de Artes Tradicionales',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6D4C41),
                              ),
                            ),
                            Text(
                              '65% completado',
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).primaryColor, width: 2)),
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
                icon: Icon(Icons.explore),
                label: 'Descubrir'
            ),
            BottomNavigationBarItem(
                icon: Icon(Icons.map),
                label: 'Rutas'
            ),
            BottomNavigationBarItem(
                icon: Icon(Icons.people),
                label: 'Comunidad'
            ),
            BottomNavigationBarItem(
                icon: Icon(Icons.bookmark),
                label: 'Mi Legado'
            ),
          ],
          selectedItemColor: Theme.of(context).primaryColor,
        ),
      ),
    );
  }

  Widget _buildExperienceCard(BuildContext context, {
    required String title,
    required String location,
    required int price,
    required String image,
    bool isVerified = false
  }) {
    return Container(
      width: 280,
      margin: EdgeInsets.only(right: 20),
      child: Card(
        elevation: 12,
        shadowColor: Colors.black26,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  child: SizedBox(
                    height: 180,
                    width: double.infinity,
                    child: Image.asset(
                      image,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      isAntiAlias: true,
                      cacheWidth: 800,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).primaryColor.withOpacity(0.8),
                                Theme.of(context).colorScheme.secondary.withOpacity(0.8),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image_outlined, size: 48, color: Colors.white70),
                                SizedBox(height: 8),
                                Text(
                                  'Imagen en alta calidad\npronto disponible',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white70, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                if (isVerified)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified, size: 16, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                              'Auténtico',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              )
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5D4037),
                      )
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 18, color: Color(0xFF8D6E63)),
                      SizedBox(width: 6),
                      Expanded(
                          child: Text(
                              location,
                              style: TextStyle(
                                color: Color(0xFF8D6E63),
                                fontSize: 14,
                              )
                          )
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  RichText(
                    text: TextSpan(
                      style: DefaultTextStyle.of(context).style.copyWith(fontSize: 14),
                      children: [
                        TextSpan(
                          text: '\$$price MXN',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor
                          ),
                        ),
                        TextSpan(
                          text: '\n(incluye \$${(price*0.05).round()} para la comunidad)',
                          style: TextStyle(fontSize: 12, color: Color(0xFF388E3C)),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('¡Reservando experiencia: $title!'),
                            backgroundColor: Theme.of(context).primaryColor,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        elevation: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_today, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Reservar experiencia',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

