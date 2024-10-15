import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseManager {
  final DatabaseReference _database;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;

  DatabaseManager(String databaseURL) : _database = FirebaseDatabase(databaseURL: databaseURL).reference() {
    _user = _auth.currentUser;
  }

  Future<String?> getVehicleNumber() async {
    if (_user == null) return null;
    DatabaseEvent generalEvent = await _database.child('general').orderByChild('email').equalTo(_user!.email).once();
    DatabaseEvent emergencyEvent = await _database.child('emergency').orderByChild('email').equalTo(_user!.email).once();

    if (generalEvent.snapshot.value != null) {
      Map<dynamic, dynamic> generalData = generalEvent.snapshot.value as Map<dynamic, dynamic>;
      return generalData.keys.first;
    } else if (emergencyEvent.snapshot.value != null) {
      Map<dynamic, dynamic> emergencyData = emergencyEvent.snapshot.value as Map<dynamic, dynamic>;
      return emergencyData.keys.first;
    }
    return null;
  }

  Future<String?> getUserType(String vehicleNumber) async {
    DatabaseEvent generalEvent = await _database.child('general').child(vehicleNumber).once();
    if (generalEvent.snapshot.value != null) {
      return 'general';
    }
    DatabaseEvent emergencyEvent = await _database.child('emergency').child(vehicleNumber).once();
    if (emergencyEvent.snapshot.value != null) {
      return 'emergency';
    }
    return null;
  }

  DatabaseReference getDatabaseRef() {
    return _database;
  }

  void listenForTextUpdates(String vehicleNumber, String userType, bool isVoiceGuideEnabled, Function(String) onTextUpdate) {
    _database.child(userType).child(vehicleNumber).child('problem').onValue.listen((event) {
      DataSnapshot dataSnapshot = event.snapshot;
      if (dataSnapshot.value != null) {
        Map<dynamic, dynamic> values = dataSnapshot.value as Map<dynamic, dynamic>;
        String combinedText = '';

        if (isVoiceGuideEnabled) {
          if (userType == 'general') {
            if (values['myText'] != null && values['myText'].toString().trim().isNotEmpty) {
              combinedText += '${values['myText']} ';
            }
            if (values['rxText'] != null && values['rxText'].toString().trim().isNotEmpty) {
              combinedText += '${values['rxText']} ';
            }
            if (values['txText'] != null && values['txText'].toString().trim().isNotEmpty) {
              combinedText += '${values['txText']} ';
            }
            if (values['nmText'] != null && values['nmText'].toString().trim().isNotEmpty) {
              combinedText += '${values['nmText']} ';
            }
          } else if (userType == 'emergency') {
            if (values['egText'] != null && values['egText'].toString().trim().isNotEmpty) {
              combinedText += '${values['egText']} ';
            }
          }

          if (combinedText.trim().isNotEmpty) {
            onTextUpdate(combinedText.trim());
          }
        }
      } else {
        print("No data in snapshot");
      }
    });
  }

  void listenForCallUpdates(String vehicleNumber, Function(String) onCallUpdate) {
    _database.child('general').child(vehicleNumber).child('report').onValue.listen((event) {
      DataSnapshot dataSnapshot = event.snapshot;
      if (dataSnapshot.value != null) {
        Map<dynamic, dynamic> values = dataSnapshot.value as Map<dynamic, dynamic>;
        if (values['112'] == 1) onCallUpdate('112');
        if (values['119'] == 1) onCallUpdate('119');
        if (values['0800482000'] == 1) onCallUpdate('0800482000');
      } else {
        print("No data in snapshot");
      }
    });
  }

  void listenForNavigationUpdates(String vehicleNumber, Function(String, double, double) onNavigationUpdate) {
    _database.child('general').child(vehicleNumber).child('Service').onValue.listen((event) {
      DataSnapshot dataSnapshot = event.snapshot;
      if (dataSnapshot.value != null) {
        Map<dynamic, dynamic> values = dataSnapshot.value as Map<dynamic, dynamic>;
        if (values['chargeStation'] != null) {
          var chargeStation = values['chargeStation'];
          if (chargeStation['location']['lat'] != null && chargeStation['location']['long'] != null) {
            double lat = chargeStation['location']['lat'].toDouble();
            double long = chargeStation['location']['long'].toDouble();
            String name = chargeStation['name'];
            if (lat != 0.0 && long != 0.0) {
              print('Navigating to charge station: $name, lat: $lat, long: $long');
              onNavigationUpdate(name, lat, long);
            } else {
              print('Invalid charge station coordinates.');
            }
          }
        }
        if (values['gasStation'] != null) {
          var gasStation = values['gasStation'];
          if (gasStation['location']['lat'] != null && gasStation['location']['long'] != null) {
            double lat = gasStation['location']['lat'].toDouble();
            double long = gasStation['location']['long'].toDouble();
            String name = gasStation['name'];
            if (lat != 0.0 && long != 0.0) {
              print('Navigating to gas station: $name, lat: $lat, long: $long');
              onNavigationUpdate(name, lat, long);
            } else {
              print('Invalid gas station coordinates.');
            }
          }
        }
        if (values['restArea'] != null) {
          var restArea = values['restArea'];
          if (restArea['location']['lat'] != null && restArea['location']['long'] != null) {
            double lat = restArea['location']['lat'].toDouble();
            double long = restArea['location']['long'].toDouble();
            String name = restArea['name'];
            if (lat != 0.0 && long != 0.0) {
              print('Navigating to rest area: $name, lat: $lat, long: $long');
              onNavigationUpdate(name, lat, long);
            } else {
              print('Invalid rest area coordinates.');
            }
          }
        }
      } else {
        print("No data in snapshot");
      }
    });
  }
}
