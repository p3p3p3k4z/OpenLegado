# 🇲🇽 Legado - Experiencias Culturales Mexicanas

Una aplicación Flutter moderna que combina la rica herencia cultural mexicana con un diseño contemporáneo y experiencia de usuario intuitiva.

### Notas sobre la actualizacion
- Desmenuzado de codigo
- Actualizacion de dependencias
- Mejora en Sistema de tickets
- Mejora en el panel de administracion 
- Mejora en el profile
- Integracion de bd en users,experiencies,bookings,review
- Integracion de reviews en experiencia
- Implementacion de modelos estables de experiencies,booking,user,reviews
- Posible ultima version para "experience_details"; Sistema de tickets, isualizacion correcta, feedback
- Buscador simple
- Nuevos componestes, rol, img para "profile"

### Correciones y mejoras
- Revisar los componenetes agregados en la rama beta para implementar
- Panel de experiencia y subir experiencia para un usuario creador(artesano,artista,residente,etc)
- Panel de experiencia y revision (darle el visto bueno a una experiencia, para decir que es real) para ,moderador
- Panel de administrador, los anteriores paneles + adminsitracion de user, etc. Control total

### Cambios futuros
- Sistema crud (Ya lo habia hecho pero lo rompi D:), revisar rama beta
- DISEÑO (Aun no terminamos de decidirnos)
- Implemetacion de temas

## 🎨 Características

- **Diseño Híbrido**: Combina elementos culturales mexicanos auténticos con patrones UX modernos
- **Experiencias Culturales**: Descubre talleres de artesanías, gastronomía tradicional y arte mexicano
- **Onboarding Intuitivo**: Flujo de bienvenida con registro/login y selección de intereses
- **Navegación Fluida**: Sistema de navegación por pestañas con exploración, experiencias y perfil
- **Filtros Inteligentes**: Filtra experiencias por categorías (Gastronomía, Artesanías, Arte, Música)
- **Detalles Completos**: Vistas detalladas con imágenes, reseñas, horarios y reservas

## 🚀 Tecnologías

- **Flutter 3.32.5** - Framework multiplataforma
- **Dart 3.8.1** - Lenguaje de programación
- **Material Design** - Sistema de diseño con tema cultural mexicano
- **Google Maps** - Integración de mapas (configurado)
- **HTTP** - Comunicación con APIs
- **Location** - Servicios de geolocalización

## 🎯 Estructura del Proyecto

```
lib/
├── main.dart                    # Punto de entrada de la aplicación
├── models/
│   └── experience.dart          # Modelos
│   └── user.dart
│   └── booking.dart
│   └── review.dart          
└── screens/
    ├── welcome_screen.dart      # Pantalla de bienvenida
    ├── login_screen.dart        # Pantalla de inicio de sesión
    ├── register_screen.dart     # Pantalla de registro
    ├── interests_screen.dart    # Selección de intereses
    ├── main_navigation.dart     # Navegación principal
    ├── explore_screen.dart      # Exploración de experiencias
    ├── experiences_screen.dart  # Lista de experiencias
    ├── profile_screen.dart      # Perfil de usuario
    └── experience_detail_screen.dart # Detalles de experiencia
```

## 🛠️ Instalación

### Prerrequisitos

- Flutter 3.32.5 o superior
- Dart 3.8.1 o superior
- Java JDK 8 (OpenJDK RedHat configurado)

#### Firebase
```bash
npm install -g firebase-tools
firebase login
dart pub global activate flutterfire_cli
flutterfire configure
```

### Configuración

1. Clona el repositorio:
```bash
git clone https://github.com/jorgechacon559/legado.git
cd legado
```

2. Instala las dependencias:
```bash
flutter pub get
```

3. Ejecuta la aplicación:
```bash
flutter run
```

## 📱 Plataformas Soportadas

- ✅ Windows (nativo)
- ✅ Web (PWA)
- ✅ Android
- 🔄 iOS (configuración inestable)
- 🔄 Linux (En espera que firebase de soporte)
- 
### IMPORTANTE
- Actualmente la bd de firebase no se puede actualizar por tema de documentacion/pagos,
por lo cual se dejan estan reglas para la seccion storage que deberan de ser aplicadas en un futuro

```code
rules_version = '2';
service firebase.storage {
match /b/{bucket}/o {
// Cualquier usuario autenticado puede leer cualquier archivo.
// Esto es necesario para que las fotos de perfil sean públicas.
match /{allPaths=**} {
allow read: if request.auth != null;
}

    // Reglas específicas para la carpeta de imágenes de perfil.
    match /profile_images/{userId}/{fileName} {
      // Un usuario solo puede CREAR un archivo en su propia carpeta (userId).
      // 'request.resource.size' se usa para limitar el tamaño del archivo.
      allow create: if request.auth != null && request.auth.uid == userId
                    && request.resource.size < 5 * 1024 * 1024 // Limite de 5MB
                    && request.resource.contentType.matches('image/.*');
      
      // Permitir borrar archivos si eres el dueño.
      allow delete: if request.auth != null && request.auth.uid == userId;
      
      // Permitir a todos los usuarios leer las imágenes.
      allow read;
    }
}
}
```
