import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:open_route_service/open_route_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late LatLng myPoint;
  bool isLoading = false;
  StreamSubscription<Position>? positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    myPoint = defaultPoint;
    _initializeMap();
  }

  final defaultPoint = const LatLng(28.6139, 77.2090);

  List listOfPoints = [];
  List<LatLng> points = [];
  List<Marker> markers = [];

  Future<void> getCoordinates(LatLng lat1, LatLng lat2) async {
    setState(() {
      isLoading = true;
    });

    try {
      final OpenRouteService client = OpenRouteService(
          apiKey: '5b3ce3597851110001cf62482bd3a07bc53e4c8093859e4ed8615017'
      );

      final List<ORSCoordinate> routeCoordinates = await client.directionsRouteCoordsGet(
          startCoordinate: ORSCoordinate(latitude: lat1.latitude, longitude: lat1.longitude),
          endCoordinate: ORSCoordinate(latitude: lat2.latitude, longitude: lat2.longitude),
          profileOverride: ORSProfile.drivingCar
      );

      final List<LatLng> routePoints = routeCoordinates
          .map((coordinate) => LatLng(coordinate.latitude, coordinate.longitude))
          .toList();

      setState(() {
        points = routePoints;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });

      if (e is FormatException) {
        print('Error: Invalid response format. Check API key or endpoint.');
      } else {
        print('Error fetching route: $e');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch route. Please check API settings.')),
      );
    }
  }

  Future<LatLng> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    return LatLng(position.latitude, position.longitude);
  }

  void _initializeMap() async {
    try {
      final LatLng currentLocation = await _getCurrentLocation();
      setState(() {
        myPoint = currentLocation;
      });
    } catch (e) {
      print('Error fetching location: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to fetch current location.')),
      );
    }
  }

  final MapController mapController = MapController();

  void _handleTap(LatLng latLng) {
    setState(() {
      if (markers.length < 2) {
        markers.add(
          Marker(
            point: latLng,
            width: 80,
            height: 80,
            child: Draggable(
              feedback: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.location_on),
                color: Colors.black,
                iconSize: 45,
              ),
              onDragEnd: (details) {
                setState(() {
                  print("Latitude: ${latLng.latitude}, Longitude: ${latLng.longitude}");
                });
              },
              child: IconButton(
                onPressed: () {},
                icon: const Icon(Icons.location_on),
                color: Colors.black,
                iconSize: 45,
              ),
            ),
          ),
        );
      }

      if (markers.length == 1) {
        double zoomLevel = 16.5;
        mapController.move(latLng, zoomLevel);
      }

      if (markers.length == 2) {
        Future.delayed(const Duration(milliseconds: 500), () {
          setState(() {
            isLoading = true;
          });
        });

        getCoordinates(markers[0].point, markers[1].point);

        LatLngBounds bounds = LatLngBounds.fromPoints(
            markers.map((marker) => marker.point).toList());
        mapController.fitBounds(bounds);
      }
    });
  }

  @override
  void dispose() {
    positionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: mapController,
            options: MapOptions(
              initialZoom: 16,
              initialCenter: myPoint,
              onTap: (tapPosition, latLng) => _handleTap(latLng),
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.example.flutter_map_draw_route',
              ),
              MarkerLayer(
                markers: markers,
              ),
              PolylineLayer(
                polylineCulling: false,
                polylines: [
                  Polyline(
                    points: points,
                    color: Colors.black,
                    strokeWidth: 5,
                  ),
                ],
              ),
            ],
          ),
          Visibility(
            visible: isLoading,
            child: Container(
              color: Colors.black.withOpacity(0.5),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 20.0,
            left: MediaQuery.of(context).size.width / 2 - 110,
            child: Align(
              child: TextButton(
                onPressed: () {
                  if (markers.isEmpty) {
                    print('Mark points on the map');
                  } else {
                    setState(() {
                      markers = [];
                      points = [];
                    });
                  }
                },
                child: Container(
                  width: 200,
                  height: 50,
                  decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10)),
                  child: Center(
                    child: Text(
                      markers.isEmpty ? "Mark route on the map" : "Clear route",
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SizedBox(height: 10),
          FloatingActionButton(
            backgroundColor: Colors.black,
            onPressed: () async {
              try {
                final LatLng currentLocation = await _getCurrentLocation();
                mapController.move(currentLocation, 16);
              } catch (e) {
                print('Error: $e');
              }
            },
            child: const Icon(
              Icons.my_location,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            backgroundColor: Colors.black,
            onPressed: () {
              mapController.move(mapController.center, mapController.zoom + 1);
            },
            child: const Icon(
              Icons.add,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            backgroundColor: Colors.black,
            onPressed: () {
              mapController.move(mapController.center, mapController.zoom - 1);
            },
            child: const Icon(
              Icons.remove,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
