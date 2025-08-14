import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geocoding; // Para evitar conflicto de nombres si lo hubiera

class MapPickerScreen extends StatefulWidget {
  final LatLng initialPosition;
  final String? initialAddress; // Opcional: para mostrar la dirección actual si se edita

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

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialPosition;
    _updateMarkerAndAddress(widget.initialPosition, isInitialSetup: true);
    if (widget.initialAddress != null && widget.initialAddress!.isNotEmpty) {
      _currentAddress = widget.initialAddress!;
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  Future<void> _onTap(LatLng position) async {
    _updateMarkerAndAddress(position);
  }

  Future<void> _onMarkerDragEnd(LatLng newPosition) async {
    _updateMarkerAndAddress(newPosition);
  }

  Future<void> _updateMarkerAndAddress(LatLng position, {bool isInitialSetup = false}) async {
    if (!mounted) return;
    setState(() {
      _selectedLocation = position;
      _selectedMarker = Marker(
        markerId: const MarkerId('selectedLocation'),
        position: position,
        draggable: true,
        onDragEnd: _onMarkerDragEnd,
        infoWindow: InfoWindow(title: 'Ubicación Seleccionada', snippet: _currentAddress),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      );
      if (!isInitialSetup) { // No hacer geocodificación en el setup inicial si ya tenemos una dirección
        _currentAddress = 'Obteniendo dirección...';
      }
      _isGeocoding = true;
    });

    try {
      List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(
        position.latitude,
        position.longitude,
        localeIdentifier: "es_MX",
      );
      if (placemarks.isNotEmpty) {
        final geocoding.Placemark place = placemarks.first;
        setState(() {
          _currentAddress = _formatPlacemark(place);
          _selectedMarker = _selectedMarker?.copyWith(
            infoWindowParam: InfoWindow(title: 'Ubicación Seleccionada', snippet: _currentAddress),
          );
        });
      } else {
        setState(() {
          _currentAddress = 'No se pudo obtener la dirección para este punto.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentAddress = 'Error al obtener dirección.';
        });
      }
      print("Error en geocodificación inversa: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isGeocoding = false;
        });
      }
    }
  }

  String _formatPlacemark(geocoding.Placemark place) {
    List<String> parts = [];
    if (place.street != null && place.street!.isNotEmpty) parts.add(place.street!);
    if (place.subLocality != null && place.subLocality!.isNotEmpty) parts.add(place.subLocality!);
    if (place.locality != null && place.locality!.isNotEmpty) parts.add(place.locality!); // Ciudad
    if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) parts.add(place.administrativeArea!); // Estado
    if (place.postalCode != null && place.postalCode!.isNotEmpty) parts.add(place.postalCode!);
    if (place.country != null && place.country!.isNotEmpty) parts.add(place.country!);
    return parts.join(', ');
  }

  Future<void> _searchAndGo() async {
    if (_searchController.text.isEmpty) return;
    setState(() { _isGeocoding = true; });
    try {
      List<geocoding.Location> locations = await geocoding.locationFromAddress(_searchController.text, localeIdentifier: "es_MX");
      if (locations.isNotEmpty) {
        final target = LatLng(locations.first.latitude, locations.first.longitude);
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 16.0));
        _updateMarkerAndAddress(target);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dirección no encontrada.'), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al buscar: $e'), backgroundColor: Colors.redAccent));
      print("Error en geocodificación (búsqueda): $e");
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
          if (_selectedLocation != null)
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Confirmar ubicación',
              onPressed: () {
                Navigator.pop(context, {'location': _selectedLocation!, 'address': _currentAddress});
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
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            mapType: MapType.normal,
            padding: EdgeInsets.only(bottom: _selectedLocation != null ? 140 : 80), // Espacio para el panel inferior y FAB
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
                        onPressed: _searchAndGo,
                      )
                  ),
                  onSubmitted: (_) => _searchAndGo(),
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
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _currentAddress,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (_isGeocoding)
                            const Padding(
                              padding: EdgeInsets.only(left: 8.0),
                              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Confirmar esta Ubicación'),
                          onPressed: () {
                            Navigator.pop(context, {'location': _selectedLocation!, 'address': _currentAddress});
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
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
