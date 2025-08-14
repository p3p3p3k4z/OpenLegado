import 'dart:async'; // Para Timer
import 'dart:convert'; // Para jsonDecode
import 'package:flutter/foundation.dart'; // Para kIsWeb
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geocoding; // Para evitar conflicto de nombres
import 'package:http/http.dart' as http; // Para llamadas HTTP

class MapPickerScreen extends StatefulWidget {
  final LatLng initialPosition;
  final String? initialAddress;

  const MapPickerScreen({
    super.key,
    required this.initialPosition,
    this.initialAddress,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  Marker? _selectedMarker;
  String _currentAddress = 'Mueve el mapa o el marcador para seleccionar...';
  bool _isGeocoding = false;
  Timer? _debounce;

  final TextEditingController _searchController = TextEditingController();

  static const String _googleMapsApiKey = 'AIzaSyD1YcUJ8VLdD3gS9Ke2cTGPBvN2mUpi5MM'; // <--- ¡¡REEMPLAZA ESTA CADENA CON TU API KEY!!
  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialPosition;
    // En el setup inicial, si ya tenemos una dirección, la usamos.
    // La geocodificación se hará solo si no hay dirección inicial o si el usuario mueve el mapa.
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _currentAddress = widget.initialAddress!;
      _updateMarkerVisuals(widget.initialPosition, widget.initialAddress!);
    } else {
      // Si no hay dirección inicial, intentamos obtenerla, pero con debounce.
      _updateMarkerVisuals(widget.initialPosition, 'Obteniendo dirección...');
      _handleLocationChange(widget.initialPosition, isInitialSetup: true);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // Si no teníamos dirección inicial y ahora el mapa está listo, intentamos geocodificar la posición inicial
    if (widget.initialAddress == null || widget.initialAddress!.isEmpty) {
      _handleLocationChange(widget.initialPosition, isInitialSetup: true);
    }
  }

  // Actualiza solo la parte visual del marcador y la dirección mostrada
  void _updateMarkerVisuals(LatLng position, String addressDisplay) {
    if (!mounted) return;
    setState(() {
      _selectedLocation = position;
      _currentAddress = addressDisplay;
      _selectedMarker = Marker(
        markerId: const MarkerId('selectedLocation'),
        position: position,
        draggable: true,
        onDragEnd: _onMarkerDragEnd,
        infoWindow: InfoWindow(title: 'Ubicación Seleccionada', snippet: addressDisplay),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );
    });
  }


  Future<void> _onTap(LatLng position) async {
    _mapController?.animateCamera(CameraUpdate.newLatLng(position)); // Centra el mapa en el tap
    _handleLocationChange(position);
  }

  Future<void> _onMarkerDragEnd(LatLng newPosition) async {
    _handleLocationChange(newPosition);
  }

  void _handleLocationChange(LatLng position, {bool isInitialSetup = false}) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    // Actualiza la UI del marcador inmediatamente con "Obteniendo..."
    _updateMarkerVisuals(position, isInitialSetup && (widget.initialAddress?.isNotEmpty ?? false) ? widget.initialAddress! : 'Obteniendo dirección...');
    if (mounted) setState(() => _isGeocoding = true );


    _debounce = Timer(const Duration(milliseconds: 750), () { // Ajusta la duración
      _performGeocoding(position, isInitialSetup: isInitialSetup);
    });
  }

  Future<void> _performGeocoding(LatLng position, {bool isInitialSetup = false}) async {
    if (!mounted) return;

    // Si es el setup inicial y ya teníamos una dirección del widget, no volvemos a geocodificar
    if (isInitialSetup && widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _updateMarkerVisuals(position, widget.initialAddress!);
      if (mounted) setState(() => _isGeocoding = false);
      return;
    }

    // Aseguramos que _isGeocoding esté en true antes de la llamada async
    if (mounted) {
      setState(() {
        _isGeocoding = true;
        // No cambiamos _currentAddress aquí para evitar el flash si ya tenía "Obteniendo..."
      });
    }


    String fetchedAddress = 'No se pudo obtener la dirección.';

    try {
      if (kIsWeb) {
        // --- Implementación para WEB usando API HTTP de Google ---
        if (_googleMapsApiKey == 'TU_API_KEY_DE_GOOGLE_MAPS_PARA_WEB' || _googleMapsApiKey.isEmpty) {
          print("ALERTA: La API Key de Google Maps para Web no está configurada.");
          fetchedAddress = 'Error: API Key no configurada.';
        } else {
          final url = Uri.parse(
              'https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$_googleMapsApiKey&language=es-MX');

          print("Web Geocoding URL: $url"); // Para depuración

          final response = await http.get(url).timeout(const Duration(seconds: 10)); // Timeout
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
              fetchedAddress = data['results'][0]['formatted_address'];
            } else {
              print('Error Geocodificación Web: ${data['status']} - ${data['error_message']}');
              fetchedAddress = 'Dirección no encontrada (Web). Estado: ${data['status']}';
            }
          } else {
            print('Error de red Geocodificación Web: ${response.statusCode}');
            fetchedAddress = 'Error de red (${response.statusCode}) al obtener dirección (Web).';
          }
        }
      } else {
        // --- Implementación existente para Móvil usando el plugin geocoding ---
        List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(
          position.latitude,
          position.longitude,
          localeIdentifier: "es_MX", // El plugin maneja esto internamente
        ).timeout(const Duration(seconds: 10)); // Timeout

        if (placemarks.isNotEmpty) {
          final geocoding.Placemark place = placemarks.first;
          fetchedAddress = _formatPlacemark(place);
        } else {
          fetchedAddress = 'No se pudo obtener la dirección para este punto (Móvil).';
        }
      }

      if (mounted) {
        _updateMarkerVisuals(position, fetchedAddress);
      }

    } catch (e, stackTrace) {
      print("Error en geocodificación (_performGeocoding): $e");
      print("Stack trace: $stackTrace");
      if (mounted) {
        String errorMsg = 'Error al obtener dirección.';
        if (e is TimeoutException) {
          errorMsg = 'Tiempo de espera agotado al obtener dirección.';
        }
        _updateMarkerVisuals(position, errorMsg);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeocoding = false;
        });
      }
    }
  }


  String _formatPlacemark(geocoding.Placemark place) {
    // Igual que antes, pero puedes mejorar el filtrado de partes vacías
    return [
      place.street,
      place.subLocality,
      place.locality,
      place.administrativeArea,
      place.postalCode,
      place.country,
    ].where((s) => s != null && s.isNotEmpty).join(', ');
  }

  Future<void> _searchAndGo() async {
    if (_searchController.text.isEmpty) return;
    if (!mounted) return;

    setState(() { _isGeocoding = true; });

    LatLng? target;
    String errorMessage = 'Dirección no encontrada.';

    try {
      if (kIsWeb) {
        if (_googleMapsApiKey == 'TU_API_KEY_DE_GOOGLE_MAPS_PARA_WEB' || _googleMapsApiKey.isEmpty) {
          errorMessage = 'Error: API Key no configurada para búsqueda.';
          print("ALERTA: API Key de Google Maps para Web no está configurada (búsqueda).");
        } else {
          final url = Uri.parse(
              'https://maps.googleapis.com/maps/api/geocode/json?address=${Uri.encodeComponent(_searchController.text)}&key=$_googleMapsApiKey&language=es-MX');
          print("Web Search URL: $url"); // Para depuración
          final response = await http.get(url).timeout(const Duration(seconds: 10));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['status'] == 'OK' && data['results'] != null && data['results'].isNotEmpty) {
              final location = data['results'][0]['geometry']['location'];
              target = LatLng(location['lat'], location['lng']);
            } else {
              errorMessage = 'Dirección no encontrada (Web). Estado: ${data['status']}';
              print('Error Geocodificación Web (búsqueda): ${data['status']} - ${data['error_message']}');
            }
          } else {
            errorMessage = 'Error de red (${response.statusCode}) al buscar (Web).';
            print('Error de red Geocodificación Web (búsqueda): ${response.statusCode}');
          }
        }
      } else {
        // Móvil
        List<geocoding.Location> locations = await geocoding.locationFromAddress(
          _searchController.text,
          localeIdentifier: "es_MX",
        ).timeout(const Duration(seconds: 10));
        if (locations.isNotEmpty) {
          target = LatLng(locations.first.latitude, locations.first.longitude);
        }
      }

      if (target != null) {
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16.0));
        _handleLocationChange(target); // Esto iniciará la geocodificación inversa para la nueva ubicación
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.orange));
      }

    } catch (e, stackTrace) {
      String errorMsg = 'Error al buscar.';
      if (e is TimeoutException) {
        errorMsg = 'Tiempo de espera agotado al buscar dirección.';
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMsg), backgroundColor: Colors.redAccent));
      print("Error en geocodificación (búsqueda): $e");
      print("Stack trace (búsqueda): $stackTrace");
    } finally {
      if (mounted) setState(() { _isGeocoding = false; });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecciona Ubicación'),
        actions: [
          if (_selectedLocation != null && !_currentAddress.toLowerCase().contains("error") && _currentAddress != 'Obteniendo dirección...' && _currentAddress != 'Mueve el mapa o el marcador para seleccionar...' )
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Confirmar ubicación',
              onPressed: (_isGeocoding || _currentAddress.toLowerCase().contains("error") || _currentAddress == 'Obteniendo dirección...' )
                  ? null // Deshabilita si está geocodificando o hay error
                  : () {
                if (_selectedLocation != null && !_currentAddress.toLowerCase().contains("error") && _currentAddress != 'Obteniendo dirección...') {
                  Navigator.pop(context, {'location': _selectedLocation!, 'address': _currentAddress});
                }
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: widget.initialPosition,
              zoom: 15.0,
            ),
            onTap: _onTap,
            markers: _selectedMarker != null ? {_selectedMarker!} : {},
            myLocationEnabled: true, // Considera pedir permiso si es necesario
            myLocationButtonEnabled: true,
            mapType: MapType.normal,
            // Ajusta el padding para que el panel inferior no tape el logo de Google o controles
            padding: EdgeInsets.only(bottom: _selectedLocation != null ? 150 : 80, top: 60),
          ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                      hintText: 'Buscar dirección o lugar...',
                      border: InputBorder.none,
                      icon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.send),
                        tooltip: 'Buscar',
                        onPressed: _isGeocoding ? null : _searchAndGo, // Deshabilita si está geocodificando
                      )
                  ),
                  onSubmitted: _isGeocoding ? null : (_) => _searchAndGo(),
                ),
              ),
            ),
          ),
          if (_selectedLocation != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Material(
                elevation: 8.0,
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        )
                      ]
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch, // Para que el botón ocupe todo el ancho
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              _currentAddress,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: _currentAddress.toLowerCase().contains("error") ? Colors.red : null
                              ),
                              maxLines: 3, // Permite más líneas para direcciones largas
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_isGeocoding)
                            const Padding(
                              padding: EdgeInsets.only(left: 12.0, top: 4.0),
                              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5)),
                            )
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Confirmar esta Ubicación'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          // backgroundColor: Theme.of(context).primaryColor, // Opcional: para darle color primario
                          // foregroundColor: Colors.white, // Opcional: si cambias el color de fondo
                        ),
                        onPressed: (_isGeocoding || _currentAddress.toLowerCase().contains("error") || _currentAddress == 'Obteniendo dirección...' || _currentAddress == 'Mueve el mapa o el marcador para seleccionar...')
                            ? null // Deshabilita si está geocodificando o hay un error o no se ha movido
                            : () {
                          if (_selectedLocation != null && !_currentAddress.toLowerCase().contains("error") && _currentAddress != 'Obteniendo dirección...' ) {
                            Navigator.pop(context, {'location': _selectedLocation!, 'address': _currentAddress});
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
