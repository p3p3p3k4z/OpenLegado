# 🇲🇽 Legado - Experiencias Culturales Mexicanas

Una aplicación Flutter moderna que combina la rica herencia cultural mexicana con un diseño contemporáneo y experiencia de usuario intuitiva.

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
│   └── experience.dart          # Modelo de datos para experiencias
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
- Visual Studio 2022 (para Windows)

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
- 🔄 Android (configuración pendiente)
- 🔄 iOS (configuración pendiente)

## 🎨 Tema Visual

### Paleta de Colores Mexicana
- **Naranja Principal**: `#E67E22` - Inspirado en el sol y especias
- **Marrón Tierra**: `#8B4513` - Tierra mexicana y barro
- **Gradientes Culturales**: Degradados que reflejan sarapes y textiles

### Assets Culturales
- `legado.jpg` - Logo principal
- `barro_negro.jpg` - Artesanía de Oaxaca
- `mole_poblano.jpg` - Gastronomía tradicional
- `sarapes.jpg` - Textiles mexicanos
- `fondo_mexicano.jpg` - Elementos decorativos

## 🔄 Próximas Características

- [ ] **Integración Google Maps**: Mapa interactivo con marcadores de experiencias
- [ ] **Backend Firebase**: Autenticación y base de datos en tiempo real
- [ ] **Sistema de Favoritos**: Guardar experiencias preferidas
- [ ] **Historial de Reservas**: Seguimiento de experiencias reservadas
- [ ] **Reseñas de Usuarios**: Sistema de calificaciones y comentarios
- [ ] **Pagos Integrados**: Procesamiento de reservas y pagos

## 🤝 Contribución

1. Fork el proyecto
2. Crea una rama para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la rama (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo [LICENSE](LICENSE) para más detalles.

## 👨‍💻 Desarrolladores

- **Jorge Chacón** - *Desarrollo Principal* - [@jorgechacon559](https://github.com/jorgechacon559)

---

*Desarrollado con ❤️ para preservar y compartir la rica cultura mexicana* 🇲🇽

## Estado Actual

✅ **La aplicación ya funciona sin errores**
- Todos los errores de sintaxis han sido corregidos
- Las dependencias están instaladas
- La aplicación se puede ejecutar con `flutter run`

## Assets Pendientes

Para completar la experiencia visual, necesitas agregar los siguientes archivos:

### Imágenes (en la carpeta `assets/`)
- `fondo_mexicano.jpg` - Imagen de fondo para el header
- `logo_legado.svg` - Logo de la aplicación en formato SVG
- `barro_negro.jpg` - Imagen para la experiencia de barro negro
- `mole_poblano.jpg` - Imagen para la experiencia de mole poblano
- `sarapes.jpg` - Imagen para la experiencia de sarapes
- `mapa_cultural.jpg` - Imagen para el mapa cultural

### Fuentes (en la carpeta `fonts/`)
- `Nunito-Regular.ttf`
- `Nunito-Bold.ttf`
- `DancingScript-Regular.ttf`
- `DancingScript-Bold.ttf`

## Cómo agregar los assets

1. **Para imágenes:**
   - Coloca las imágenes en la carpeta `assets/`
   - Descomenta las líneas en `pubspec.yaml` bajo la sección assets
   - Descomenta las referencias a las imágenes en `main.dart`

2. **Para fuentes:**
   - Coloca los archivos de fuente en la carpeta `fonts/`
   - Descomenta la sección fonts en `pubspec.yaml`
   - Descomenta las referencias a las fuentes en `main.dart`

3. **Ejecuta después de agregar assets:**
   ```bash
   flutter pub get
   flutter run
   ```

## Ejecutar la aplicación

```bash
cd legado_app
flutter run
```

## Características implementadas

- ✅ Diseño responsive con tema mexicano
- ✅ AppBar expandible con espacio para logo
- ✅ Sección de experiencias auténticas con tarjetas deslizables
- ✅ Mapa cultural interactivo
- ✅ Sección de impacto comunitario
- ✅ Navegación inferior con 4 secciones
- ✅ Colores temáticos (naranja barro cocido y azul talavera)
- ✅ Gradientes temporales mientras agregas las imágenes

## Próximos pasos

1. Agregar las imágenes y fuentes mencionadas arriba
2. Implementar la navegación entre pantallas
3. Agregar funcionalidad a los botones
4. Conectar con backend/base de datos
