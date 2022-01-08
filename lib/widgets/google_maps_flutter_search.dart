import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter_search/entities/entities.dart';
import 'package:google_maps_flutter_search/entities/localization_item.dart';
import 'package:google_maps_flutter_search/widgets/widgets.dart';
import 'package:http/http.dart' as http;

import '../uuid.dart';

class GoogleMapsFlutterSearch extends StatefulWidget {
  final String apiKey;
  LatLng? displayLocation;
  Messages? messages;

  GoogleMapsFlutterSearch(this.apiKey,
      {Key? key, this.displayLocation, this.messages})
      : super(key: key) {
    messages ??= Messages();
    displayLocation ??= const LatLng(15.369445, 44.191006);
  }

  @override
  State<StatefulWidget> createState() => GoogleMapsFlutterSearchState();
}

/// Place picker state
class GoogleMapsFlutterSearchState extends State<GoogleMapsFlutterSearch> {
  /// Indicator for the selected location
  final Set<Marker> markers = {};

  /// Result returned after user completes selection
  LocationResult? locationResult;

  /// Overlay to display autocomplete suggestions
  OverlayEntry? overlayEntry;

  List<NearbyPlace> nearbyPlaces = [];

  /// Session token required for autocomplete API call
  String sessionToken = Uuid().generateV4();

  GlobalKey appBarKey = GlobalKey();

  bool hasSearchTerm = false;
  bool isMove = false;

  String previousSearchTerm = '';

  CameraPosition initCameraPosition() => CameraPosition(
        target: widget.displayLocation ?? const LatLng(15.369445, 44.191006),
        zoom: 6,
      );

  // constructor
  GoogleMapsFlutterSearchState();

  final Completer<GoogleMapController> mapController = Completer();
  late GoogleMapController newGooGleMapController;

  void onMapCreated(GoogleMapController controller) {
    mapController.complete(controller);
    newGooGleMapController = controller;

    // moveToCurrentUserLocation();
  }

  @override
  void setState(fn) {
    if (mounted) {
      super.setState(fn);
    }
  }

  @override
  void initState() {
    super.initState();
    _buildMarkerFromAssets();
  }

  @override
  void dispose() {
    overlayEntry?.remove();
    super.dispose();
  }

  BitmapDescriptor? _locationIcon;

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  _buildMarkerFromAssets() async {
    final Uint8List markerIcon = await getBytesFromAsset('assets/images/marker.png', 100);
    _locationIcon =  BitmapDescriptor.fromBytes(markerIcon);
    setState(() {});

    markers.add(Marker(
      position: widget.displayLocation!,
      markerId: const MarkerId("selected-location"),
      icon: _locationIcon!,
    ));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        key: appBarKey,
        preferredSize: const Size.fromHeight(52),
        child: SearchInput(searchPlace, messages: widget.messages!,),
      ),

      // AppBar(
      //   backgroundColor: Colors.grey,
      //   key: appBarKey,
      //   // actions: [],
      //   // leading: SizedBox(height: 0, width: 0,),
      //   title: SearchInput(searchPlace),
      //   centerTitle: true,
      //   automaticallyImplyLeading: false,
      // ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 2,
            child: Stack(
              alignment: Alignment.center,
              children: [
                GoogleMap(
                  initialCameraPosition: initCameraPosition(),
                  myLocationButtonEnabled: true,
                  myLocationEnabled: true,
                  onMapCreated: onMapCreated,
                  onTap: (latLng) {
                    clearOverlay();
                    moveToLocation(latLng);
                  },
                  onCameraMove: (position) {
                    widget.displayLocation = LatLng(
                        position.target.latitude, position.target.longitude);
                    setState(() => isMove = true);
                  },
                  onCameraIdle: () async {
                    await Future.delayed(const Duration(milliseconds: 300))
                        .then((value) {
                      setState(() => isMove = false);
                      // clearOverlay();
                      moveToLocation(widget.displayLocation!, false);
                    });
                  },
                  markers: markers,
                ),
                // Align(
                //   alignment: const Alignment(0, -0.05),
                //   child: !isMove
                //         ?  Image.asset('assets/images/marker.gif', width: 50, height: 50,)
                //       : SizedBox(
                //     width: 50,
                //     height: 50,
                //     child: Column(
                //       mainAxisAlignment: MainAxisAlignment.end,
                //       children: [
                //         Container(
                //           width: 5,
                //           height: 10,
                //           decoration: BoxDecoration(
                //               color: Theme.of(context).colorScheme.primary,
                //               shape: BoxShape.circle),
                //         )
                //       ],
                //     ),
                //   ),
                // ),
                // Align(
                //   alignment: const Alignment(-0.9, 0.9),
                //   child: FloatingActionButton.small(
                //     onPressed: () {},
                //     backgroundColor: Theme.of(context).colorScheme.surface,
                //     foregroundColor:
                //         Theme.of(context).colorScheme.secondaryVariant,
                //     child: const Icon(Icons.gps_fixed),
                //   ),
                // ),
              ],
            ),
          ),
          if (!hasSearchTerm)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SelectPlaceAction(
                      getLocationName(),
                      () => Navigator.of(context).pop(locationResult),
                      widget.messages!.tapToSelectLocation),
                  const Divider(height: 1),
                  Padding(
                    child: Text(widget.messages!.nearBy,
                        style: const TextStyle(fontSize: 16)),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  ),
                  Expanded(
                    child: ListView(
                      children: nearbyPlaces
                          .map((it) => NearbyPlaceItem(
                          it, () => moveToLocation(it.latLng!)))
                          .toList(),
                    ),
                  )

                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Hides the autocomplete overlay
  void clearOverlay() {
    if (overlayEntry != null) {
      overlayEntry!.remove();
      overlayEntry = null;
    }
  }

  /// Begins the search process by displaying a "wait" overlay then
  /// proceeds to fetch the autocomplete list. The bottom "dialog"
  /// is hidden so as to give more room and better experience for the
  /// autocomplete list overlay.
  void searchPlace(String place) {
    // on keyboard dismissal, the search was being triggered again
    // this is to cap that.
    if (place == previousSearchTerm) {
      return;
    }

    previousSearchTerm = place;

    if (context == null) {
      return;
    }

    clearOverlay();

    setState(() => hasSearchTerm = place.isNotEmpty);

    if (place.isEmpty) {
      return;
    }

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    final RenderBox? appBarBox =
        appBarKey.currentContext!.findRenderObject() as RenderBox?;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: appBarBox!.size.height,
        width: size.width,
        child: Material(
          elevation: 1,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              children: <Widget>[
                const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 3)),
                const SizedBox(width: 24),
                Expanded(
                    child: Text(widget.messages!.findingPlace,
                        style: const TextStyle(fontSize: 16)))
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context)!.insert(overlayEntry!);

    autoCompleteSearch(place);
  }

  /// Fetches the place autocomplete list with the query [place].
  void autoCompleteSearch(String place) async {
    try {
      place = place.replaceAll(" ", "+");

      var endpoint =
          "https://maps.googleapis.com/maps/api/place/autocomplete/json?"
          "key=${widget.apiKey}&"
          "language=${widget.messages!.languageCode}&"
          "input={$place}&sessiontoken=$sessionToken";

      if (locationResult != null) {
        endpoint += "&location=${locationResult!.latLng!.latitude},"
            "${locationResult!.latLng!.longitude}";
      }

      final response = await http.get(Uri.parse(endpoint));

      if (response.statusCode != 200) {
        throw Error();
      }

      final responseJson = jsonDecode(response.body);

      if (responseJson['predictions'] == null) {
        throw Error();
      }

      List<dynamic> predictions = responseJson['predictions'];

      List<RichSuggestion> suggestions = [];

      if (predictions.isEmpty) {
        AutoCompleteItem aci = AutoCompleteItem();
        aci.text = widget.messages!.noResultsFound;
        aci.offset = 0;
        aci.length = 0;

        suggestions.add(RichSuggestion(aci, () {}));
      } else {
        for (dynamic t in predictions) {
          final aci = AutoCompleteItem()
            ..id = t['place_id']
            ..text = t['description']
            ..offset = t['matched_substrings'][0]['offset']
            ..length = t['matched_substrings'][0]['length'];
          suggestions.add(RichSuggestion(aci, () {
            FocusScope.of(context).requestFocus(FocusNode());
            decodeAndSelectPlace(aci.id);
          }));
        }
      }

      displayAutoCompleteSuggestions(suggestions);
    } catch (_) {}
  }

  /// To navigate to the selected place from the autocomplete list to the map,
  /// the lat,lng is required. This method fetches the lat,lng of the place and
  /// proceeds to moving the map to that location.
  void decodeAndSelectPlace(String? placeId) async {
    clearOverlay();

    try {
      final url = Uri.parse(
          "https://maps.googleapis.com/maps/api/place/details/json?key=${widget.apiKey}&"
          "language=${widget.messages!.languageCode}&"
          "placeid=$placeId");

      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Error();
      }

      final responseJson = jsonDecode(response.body);

      if (responseJson['result'] == null) {
        throw Error();
      }

      final location = responseJson['result']['geometry']['location'];

      moveToLocation(LatLng(location['lat'], location['lng']));
    } catch (e) {
      // print(e);
    }
  }

  /// Display autocomplete suggestions with the overlay.
  void displayAutoCompleteSuggestions(List<RichSuggestion> suggestions) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    Size size = renderBox.size;

    final RenderBox? appBarBox =
        appBarKey.currentContext!.findRenderObject() as RenderBox?;

    clearOverlay();

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        top: appBarBox!.size.height,
        child: Material(elevation: 1, child: Column(children: suggestions)),
      ),
    );

    Overlay.of(context)!.insert(overlayEntry!);
  }

  /// Utility function to get clean readable name of a location. First checks
  /// for a human-readable name from the nearby list. This helps in the cases
  /// that the user selects from the nearby list (and expects to see that as a
  /// result, instead of road name). If no name is found from the nearby list,
  /// then the road name returned is used instead.
  String getLocationName() {
    if (locationResult == null) {
      return widget.messages!.unnamedLocation;
    }

    for (NearbyPlace np in nearbyPlaces) {
      if (np.latLng == locationResult!.latLng &&
          np.name != locationResult!.locality) {
        locationResult!.name = np.name;
        return "${np.name}, ${locationResult!.locality}";
      }
    }

    return "${locationResult!.name}, ${locationResult!.locality}";
  }

  /// Moves the marker to the indicated lat,lng
  void setMarker(LatLng latLng) {
    // markers.clear();
    setState(() {
      markers.clear();
      markers.add(
        Marker(
          markerId: const MarkerId("selected-location"),
          position: latLng,
          icon: _locationIcon!,
        ),
      );
    });
  }

  /// Fetches and updates the nearby places to the provided lat,lng
  void getNearbyPlaces(LatLng latLng) async {
    try {
      final url = Uri.parse(
          "https://maps.googleapis.com/maps/api/place/nearbysearch/json?"
          "key=${widget.apiKey}&location=${latLng.latitude},${latLng.longitude}"
          "&radius=150&language=${widget.messages!.languageCode}");

      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Error();
      }

      final responseJson = jsonDecode(response.body);

      if (responseJson['results'] == null) {
        throw Error();
      }

      nearbyPlaces.clear();

      for (Map<String, dynamic> item in responseJson['results']) {
        final nearbyPlace = NearbyPlace()
          ..name = item['name']
          ..icon = item['icon']
          ..latLng = LatLng(item['geometry']['location']['lat'],
              item['geometry']['location']['lng']);

        nearbyPlaces.add(nearbyPlace);
      }

      // to update the nearby places
      setState(() {
        // this is to require the result to show
        hasSearchTerm = false;
      });
    } catch (e) {
      //
    }
  }

  /// This method gets the human readable name of the location. Mostly appears
  /// to be the road name and the locality.
  void reverseGeocodeLatLng(LatLng latLng) async {
    try {
      final url = Uri.parse("https://maps.googleapis.com/maps/api/geocode/json?"
          "latlng=${latLng.latitude},${latLng.longitude}&"
          "language=${widget.messages!.languageCode}&"
          "key=${widget.apiKey}");

      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Error();
      }

      final responseJson = jsonDecode(response.body);

      if (responseJson['results'] == null) {
        throw Error();
      }

      final result = responseJson['results'][0];

      setState(() {
        String? name,
            locality,
            postalCode,
            country,
            administrativeAreaLevel1,
            administrativeAreaLevel2,
            city,
            subLocalityLevel1,
            subLocalityLevel2;
        bool isOnStreet = false;

        if (result['address_components'] is List<dynamic> &&
            result['address_components'].length != null &&
            result['address_components'].length > 0) {
          for (var i = 0; i < result['address_components'].length; i++) {
            var tmp = result['address_components'][i];
            var types = tmp["types"] as List<dynamic>?;
            var shortName = tmp['short_name'];
            if (types == null) {
              continue;
            }
            if (i == 0) {
              // [street_number]
              name = shortName;
              isOnStreet = types.contains('street_number');
              // other index 0 types
              // [establishment, point_of_interest, subway_station, transit_station]
              // [premise]
              // [route]
            } else if (i == 1 && isOnStreet) {
              if (types.contains('route')) {
                name = (name ?? "") + ", $shortName";
              }
            } else {
              if (types.contains("sublocality_level_1")) {
                subLocalityLevel1 = shortName;
              } else if (types.contains("sublocality_level_2")) {
                subLocalityLevel2 = shortName;
              } else if (types.contains("locality")) {
                locality = shortName;
              } else if (types.contains("administrative_area_level_2")) {
                administrativeAreaLevel2 = shortName;
              } else if (types.contains("administrative_area_level_1")) {
                administrativeAreaLevel1 = shortName;
              } else if (types.contains("country")) {
                country = shortName;
              } else if (types.contains('postal_code')) {
                postalCode = shortName;
              }
            }
          }
        }
        locality = locality ?? administrativeAreaLevel1;
        city = locality;
        locationResult = LocationResult()
          ..name = name
          ..locality = locality
          ..latLng = latLng
          ..formattedAddress = result['formatted_address']
          ..placeId = result['place_id']
          ..postalCode = postalCode
          ..country = AddressComponent(name: country, shortName: country)
          ..administrativeAreaLevel1 = AddressComponent(
              name: administrativeAreaLevel1,
              shortName: administrativeAreaLevel1)
          ..administrativeAreaLevel2 = AddressComponent(
              name: administrativeAreaLevel2,
              shortName: administrativeAreaLevel2)
          ..city = AddressComponent(name: city, shortName: city)
          ..subLocalityLevel1 = AddressComponent(
              name: subLocalityLevel1, shortName: subLocalityLevel1)
          ..subLocalityLevel2 = AddressComponent(
              name: subLocalityLevel2, shortName: subLocalityLevel2);
      });
    } catch (e) {
      // print(e);
    }
  }

  /// Moves the camera to the provided location and updates other UI features to
  /// match the location.
  void moveToLocation(LatLng latLng, [bool isAnimateCamera = true]) {

    if(isAnimateCamera) {

      mapController.future.then((controller) {
        controller.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target:latLng, zoom: 15.0),
            ));
      });

      reverseGeocodeLatLng(latLng);

    }


    setMarker(latLng);
    getNearbyPlaces(latLng);









  }

// void moveToCurrentUserLocation() {
//   if (widget.displayLocation != null) {
//     moveToLocation(widget.displayLocation!);
//     return;
//   }
//
//   Location().getLocation().then((locationData) {
//     LatLng target = LatLng(locationData.latitude!, locationData.longitude!);
//     moveToLocation(target);
//   }).catchError((_) {
//     // TODO: Handle the exception here
//     // print(error);
//   });
// }
}
