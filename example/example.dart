import 'package:flutter/material.dart';
import 'package:google_maps_flutter_search/google_maps_flutter_search.dart';

class GoogleMapsFlutterSearchDemo extends StatefulWidget {
  const GoogleMapsFlutterSearchDemo({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => GoogleMapsFlutterSearchDemoState();
}

class GoogleMapsFlutterSearchDemoState extends State<GoogleMapsFlutterSearchDemo> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Picker Example')),
      body: Center(
        child: TextButton(
          child: const Text("Pick Delivery location"),
          onPressed: () => showGoogleMapsFlutterSearch(),
        ),
      ),
    );
  }

  void showGoogleMapsFlutterSearch() async {
    LocationResult? result = await Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => GoogleMapsFlutterSearch("YOUR API KEY")));

    // Handle the result in your way
    // print(result);
  }
}
