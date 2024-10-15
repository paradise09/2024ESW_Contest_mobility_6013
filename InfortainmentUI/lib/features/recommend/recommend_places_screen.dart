// lib/screens/recommend_places_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class RecommendPlacesScreen extends StatefulWidget {
  @override
  _RecommendPlacesScreenState createState() => _RecommendPlacesScreenState();
}

class _RecommendPlacesScreenState extends State<RecommendPlacesScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase(
    databaseURL:
        'https://ai-connectcar-default-rtdb.asia-southeast1.firebasedatabase.app/',
  ).reference();

  // 데이터 구조: Date -> Timestamp -> Place
  Map<String, Map<String, Map<String, String>>> recommendPlaces = {};
  String vehicleNumber = '';
  String vehicleType = ''; // 'general' 또는 'emergency'
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchVehicleNumberAndPlaces();
  }

  Future<void> _fetchVehicleNumberAndPlaces() async {
    User? user = _auth.currentUser;
    if (user != null) {
      print('사용자 이메일: ${user.email}');
      print('사용자 UID: ${user.uid}');

      DatabaseEvent generalEvent = await _database
          .child('general')
          .orderByChild('email')
          .equalTo(user.email)
          .once();
      DatabaseEvent emergencyEvent = await _database
          .child('emergency')
          .orderByChild('email')
          .equalTo(user.email)
          .once();

      // 'general' 섹션에서 데이터가 존재하는지 확인
      if (generalEvent.snapshot.value != null) {
        Map<dynamic, dynamic> generalData =
            generalEvent.snapshot.value as Map<dynamic, dynamic>;
        print('generalData: $generalData');

        // 차량 번호 추출
        String fetchedVehicleNumber = generalData.keys.first;
        print('Fetched vehicleNumber from general: $fetchedVehicleNumber');
        setState(() {
          vehicleNumber = fetchedVehicleNumber;
          vehicleType = 'general';
        });
        await _fetchRecommendPlaces(fetchedVehicleNumber, vehicleType);
      } else {
        print('차량 번호를 찾을 수 없습니다.');
        setState(() {
          vehicleNumber = '';
          vehicleType = '';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchRecommendPlaces(
      String vehicleNumber, String vehicleType) async {
    print(
        'Fetching recommend places for vehicle number: $vehicleNumber from $vehicleType');
    try {
      DatabaseReference lbsRef =
          _database.child(vehicleType).child(vehicleNumber).child('LBS');
      print('Accessing LBS path: ${lbsRef.path}');
      DataSnapshot lbsSnapshot = await lbsRef.get();

      if (lbsSnapshot.exists) {
        dynamic lbsValue = lbsSnapshot.value;
        print('LBS Data: $lbsValue');

        if (lbsValue is Map<dynamic, dynamic>) {
          Map<String, Map<String, Map<String, String>>> tempData = {};

          lbsValue.forEach((date, timestamps) {
            if (timestamps is Map<dynamic, dynamic>) {
              Map<String, Map<String, String>> timestampData = {};
              timestamps.forEach((timestamp, places) {
                if (places is List<dynamic>) {
                  // LBS 데이터가 리스트로 되어있는 경우
                  Map<String, String> placeList = {};
                  for (var i = 1; i < places.length; i++) {
                    // 인덱스 0은 null
                    var placeMap = places[i];
                    if (placeMap is Map<dynamic, dynamic>) {
                      placeMap.forEach((hotelName, link) {
                        if (hotelName is String && link is String) {
                          placeList[hotelName] = link;
                        }
                      });
                    }
                  }
                  timestampData[timestamp.toString()] = placeList;
                }
              });
              tempData[date.toString()] = timestampData;
            }
          });

          setState(() {
            recommendPlaces = tempData;
            isLoading = false;
          });
          print('recommendPlaces: $recommendPlaces');
        } else {
          print('LBS 데이터 형식이 올바르지 않습니다.');
          setState(() {
            recommendPlaces = {};
            isLoading = false;
          });
        }
      } else {
        print('추천 받은 장소가 없습니다.');
        setState(() {
          recommendPlaces = {};
          isLoading = false;
        });
      }
    } catch (e) {
      if (e is FirebaseException) {
        print('FirebaseException Code: ${e.code}');
        print('FirebaseException Message: ${e.message}');
      } else {
        print('Unexpected error: $e');
      }
      setState(() {
        recommendPlaces = {};
        isLoading = false;
      });
    }
  }

  void _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('링크를 열 수 없습니다: $url')),
      );
    }
  }

  String _formatDate(String date) {
    if (date.length != 8) return date;
    String year = date.substring(0, 4);
    String month = date.substring(4, 6);
    String day = date.substring(6, 8);
    return '$year년 $month월 $day일';
  }

  String _formatTime(String time) {
    if (time.length != 6) return time;
    String hour = time.substring(0, 2);
    String minute = time.substring(2, 4);
    String second = time.substring(4, 6);
    return '$hour:$minute:$second';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('추천 받은 장소'),
        ),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('추천 받은 장소'),
      ),
      body: vehicleNumber.isEmpty
          ? Center(
              child: Text('차량 번호를 찾을 수 없습니다.'),
            )
          : recommendPlaces.isEmpty
              ? Center(
                  child: Text('추천 받은 장소가 없습니다.'),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(12.0),
                  itemCount: recommendPlaces.keys.length,
                  itemBuilder: (context, index) {
                    String date = recommendPlaces.keys.elementAt(index);
                    Map<String, Map<String, String>> timestamps =
                        recommendPlaces[date]!;

                    return Card(
                      elevation: 2,
                      margin: EdgeInsets.symmetric(vertical: 8.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      child: ExpansionTile(
                        leading: Icon(Icons.calendar_today),
                        title: Text(
                          _formatDate(date),
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        children: timestamps.keys.map((timestamp) {
                          Map<String, String> places = timestamps[timestamp]!;

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.access_time, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      _formatTime(timestamp),
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemCount: places.keys.length,
                                  itemBuilder: (context, placeIndex) {
                                    String placeName =
                                        places.keys.elementAt(placeIndex);
                                    String placeLink =
                                        places.values.elementAt(placeIndex);

                                    return ListTile(
                                      contentPadding:
                                          EdgeInsets.symmetric(horizontal: 0),
                                      leading: Icon(Icons.location_on),
                                      title: Text(
                                        placeName,
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      trailing: ElevatedButton.icon(
                                        icon: Icon(Icons.directions),
                                        label: Text('바로가기', style: TextStyle(color: Colors.white),),
                                        style: ElevatedButton.styleFrom(
                                          foregroundColor: Colors.white,
                                          backgroundColor: Colors.deepPurpleAccent,
                                        ),
                                        onPressed: () => _launchURL(placeLink),
                                      ),
                                    );
                                  },
                                ),
                                Divider(),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
    );
  }
}
