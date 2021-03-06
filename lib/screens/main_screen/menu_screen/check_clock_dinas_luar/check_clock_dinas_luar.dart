import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hello_world_app/utils/LoginPreferences.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hello_world_app/screens/main_screen/menu_screen/check_clock/shift2.dart';
import 'package:dio/dio.dart';
import 'package:hello_world_app/globals/ApiEndpoints.dart';
import 'package:modal_progress_hud/modal_progress_hud.dart';

class CheckClockDinasLuar extends StatefulWidget {
  const CheckClockDinasLuar({Key key}) : super(key: key);

  @override
  _CheckClockDinasLuarState createState() => _CheckClockDinasLuarState();
}

class _CheckClockDinasLuarState extends State<CheckClockDinasLuar> {
  String _timeString, _selectedType;
  int _ccType = 1;
  List _checkClockTypes;
  Timer _timer;
  bool _isProcessingRequest = false;

  // map
  final double zoomClose = 17.0;
  Position _currentPosition;
  bool serviceEnabled;
  List<Shift2> lshift = new List();
  LocationPermission permission;
  final MapController _mapController = MapController();
  final LatLng _jakarta = LatLng(-6.1275785, 106.8356448);

  // listen location changes
  StreamSubscription<Position> _positionStreamSubscription;

  // listen position at first and check permissions
  Future<Position> _determinePosition(BuildContext context) async {
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showGpsAlert(context);
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permantly denied, we cannot request permissions.');
    }

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return Future.error(
            'Location permissions are denied (actual value: $permission).');
      }
    }

    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        forceAndroidLocationManager: true);
  }

  //get last location
  void _getLastKnownLocation() {
    try {
      Geolocator.getLastKnownPosition().then((value) {
        if (value == null) {
          // jika lokasi null maka ambil lokasi lagi
          _getLastKnownLocation();
          return;
        }

        setState(() {
          _currentPosition = value;
        });

        _mapController.move(
            LatLng(_currentPosition.latitude, _currentPosition.longitude),
            zoomClose);

        print("getLastknownLocation: " + value.latitude.toString());
      }).catchError(
          (error) => print(error.toString() + " null pada lastKnown"));
    } catch (e) {
      print("Error pada get current position " + e.toString());
    }
  }

  Future<String> _getShift() async {
    Dio _dio = new Dio();
    Response response;
    _dio.options.connectTimeout = 20000;
    _dio.options.receiveTimeout = 3000;

    try {
      response = await _dio.get(ApiEndpoints.GET_SHIFT +
          "group_id=" +
          LoginPreferences.prefs
              .getInt(LoginPreferences.EMPLOYEE_GROUP_ID)
              .toString() +
          "&tipe=2");

      List<Shift2> lshiftTemp = List();
      if (response.statusCode == 200) {
        print("berhasil mengambil");
        for (var i = 0; i < response.data.length - 1; i++) {
          lshiftTemp.add(Shift2.fromJson(response.data[i.toString()]));
        }
        setState(() {
          lshift = lshiftTemp;
          _selectedType = lshift[0].nama;
          _ccType = lshift[0].id;
        });
        return "Load data sukses";
      }
    } on DioError catch (e) {
      // if error on sending request
      switch (e.type) {
        case DioErrorType.CONNECT_TIMEOUT:
          // _responseText = "Connection time out";
          return "Connection time out pada data ketidakhadiran";
          break;
        case DioErrorType.DEFAULT:
          // _responseText = "Terjadi error. Harap coba beberapa saat lagi";
          return "Terjadi error. Harap coba beberapa saat lagi";
          break;
        case DioErrorType.CANCEL:
          // _responseText = "Request canceled";
          return "Request canceled";
          break;
        default:
          // _responseText = "another error occured";
          return "another error occured";
      }
      switch (e.response.statusCode) {
        case 401:
          // _responseText = "Data tidak ditemukan";
          return "Data tidak ditemukan";
          break;
        case 500:
          // _responseText = "Server Error. Harap coba beberapa saat lagi";
          return "Server Error. Harap coba beberapa saat lagi";
          break;
        default:
          // _responseText = "Terjadi Error. Harap coba beberapa saat lagi";
          return '"Terjadi Error. Harap coba beberapa saat lagi"';
      }
    } catch (e) {
      print(e);
    }
  }

  // to show alert gps not active
  void _showGpsAlert(BuildContext context) {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
              title: Text("GPS"),
              content: Text("GPS not detected. Please activate it."),
              actions: [
                TextButton(
                  child: Text('Go to settings'),
                  onPressed: () {
                    Geolocator.openLocationSettings();
                  },
                ),
              ],
            ));
  }

  void _showSuccessAlert(BuildContext context) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text("Success"),
              content: Text(
                  "Berhasil melakukan presensi ($_selectedType) at $_timeString"),
              actions: [
                TextButton(
                  child: Text('Ok'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ));
  }

  // listening on location changes
  void _toggleListening() {
    if (_positionStreamSubscription == null) {
      final positionStream = Geolocator.getPositionStream();
      _positionStreamSubscription = positionStream.handleError((error) {
        _positionStreamSubscription.cancel();
        _positionStreamSubscription = null;
      }).listen((position) {
        setState(() => _currentPosition = position);
        _mapController.move(
            LatLng(_currentPosition.latitude, _currentPosition.longitude),
            zoomClose);
      });
      _positionStreamSubscription.pause();
    }

    setState(() {
      if (_positionStreamSubscription.isPaused) {
        _positionStreamSubscription.resume();
      } else {
        _positionStreamSubscription.pause();
      }
    });
  }

  @override
  void initState() {
    print('start pos: ' + _currentPosition.toString());
    // run listen location first, and changes
    _getShift();
    _getLastKnownLocation();
    _toggleListening();

    _determinePosition(context).then((position) {
      print(position.toString());
      setState(() {
        _currentPosition = position;
        _mapController.move(
            new LatLng(position.latitude, position.longitude), zoomClose);
        print(_currentPosition);
      });

      // _toggleListening();
    }).catchError((error) => print(error));

    // if (LoginPreferences.prefs.getInt(LoginPreferences.EMPLOYEE_GROUP_ID) ==
    //     2) {
    //   _checkClockTypes = [
    //     'WFH Shift 1 Masuk',
    //     'WFH Shift 1 Pulang',
    //     'WFH Shift 2 Masuk',
    //     'WFH Shift 2 Pulang',
    //     'WFH Shift 3 Masuk',
    //     'WFH Shift 3 Pulang',
    //   ];
    // } else if (LoginPreferences.prefs
    //         .getInt(LoginPreferences.EMPLOYEE_GROUP_ID) ==
    //     5) {
    //   _checkClockTypes = [
    //     'WFH Shift 1 Masuk',
    //     'WFH Shift 1 Pulang',
    //     'WFH Shift 3 Masuk',
    //     'WFH Shift 3 Pulang',
    //   ];
    // } else {
    //   _checkClockTypes = [
    //     'WFH Non Shift Masuk',
    //     'WFH Non Shift Pulang',
    //   ];
    // }
    // _checkClockTypes.add('Dinas Luar In');
    // _checkClockTypes.add('Dinas Luar Out');

    // _selectedType = _checkClockTypes[0];
    _timeString = _formatDateTime(DateTime.now());
    _timer = Timer.periodic(Duration(seconds: 1), (Timer t) => _getTime());
    super.initState();
  }

  @override
  void dispose() {
    // dispose location listen on widget dispose
    if (_positionStreamSubscription != null) {
      _positionStreamSubscription.cancel();
      _positionStreamSubscription = null;
    }
    // cancel timer on dispose
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModalProgressHUD(
      inAsyncCall: _isProcessingRequest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Card(
              elevation: 10.0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0, bottom: 4.0),
                    child: Text(
                      _timeString,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Divider(thickness: 0.5, color: Colors.black87),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        top: 4.0, left: 16.0, right: 16.0, bottom: 4.0),
                    child: Text(
                      'NIP: ${LoginPreferences.prefs.getString(LoginPreferences.EMPLOYEE_NIP)}',
                      textAlign: TextAlign.left,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Divider(thickness: 0.5, color: Colors.black87),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        top: 4.0, left: 16.0, right: 16.0, bottom: 4.0),
                    child: Text(
                      'NAMA: ${LoginPreferences.prefs.getString(LoginPreferences.PERSON_NAME)}',
                      textAlign: TextAlign.left,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Divider(thickness: 0.5, color: Colors.black87),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 16.0, right: 16.0, bottom: 10.0),
                    child: DropdownButton(
                      isExpanded: true,
                      value: _selectedType,
                      items: lshift.map((value) {
                        return DropdownMenuItem(
                          child: Text(value.nama),
                          value: value.nama,
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          for (var i = 0; i < lshift.length; i++) {
                            if (lshift[i].nama == value) {
                              _ccType = lshift[i].id;
                              print(_ccType);
                            }
                          }
                          _selectedType = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: new MapOptions(
                    center: _currentPosition == null
                        ? _jakarta
                        : new LatLng(_currentPosition.latitude,
                            _currentPosition.longitude),
                    zoom: zoomClose,
                    interactive: false,
                  ),
                  layers: [
                    new TileLayerOptions(
                        urlTemplate:
                            "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                        subdomains: ['a', 'b', 'c']),
                    new MarkerLayerOptions(
                      markers: [
                        new Marker(
                          width: 80.0,
                          height: 80.0,
                          point: _currentPosition == null
                              ? _jakarta
                              : new LatLng(_currentPosition.latitude,
                                  _currentPosition.longitude),
                          builder: (ctx) => new Container(
                            child: Icon(
                              Icons.person_pin_circle,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(10.0),
                      child: ElevatedButton(
                        onPressed: () {
                          // jika lokasi tidak ditemukan
                          if (_currentPosition == null) {
                            Scaffold.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  "Lokasi tidak akurat. Harap periksa koneksi dan GPS anda"),
                            ));
                            return;
                          }

                          _postOutsidePresence(
                              context,
                              _ccType,
                              LoginPreferences.prefs
                                  .getInt(LoginPreferences.EMPLOYEE_ID),
                              _currentPosition.latitude.toString(),
                              _currentPosition.longitude.toString());
                        },
                        child: Text('Submit Presensi'),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _getTime() {
    final DateTime now = DateTime.now();
    final String formattedDateTime = _formatDateTime(now);
    if (this.mounted) {
      setState(() {
        _timeString = formattedDateTime;
      });
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy hh:mm:ss').format(dateTime);
  }

  void _postOutsidePresence(BuildContext context, int ccType, int employeeId,
      String lat, String lng) async {
    Dio _dio = new Dio();
    Response response;
    _dio.options.connectTimeout = 8000;
    _dio.options.receiveTimeout = 3000;

    setState(() {
      _isProcessingRequest = true;
    });

    try {
      response = await _dio.post(ApiEndpoints.POST_PRESENCE, data: {
        'cc_type': ccType,
        'employee_id': employeeId,
        'lat': lat,
        'lng': lng
      });

      setState(() {
        _isProcessingRequest = false;
      });

      if (response.statusCode == 200) {
        _showSuccessAlert(context);
      }
    } on DioError catch (e) {
      setState(() {
        _isProcessingRequest = false;
      });

      // if error on sending request
      switch (e.type) {
        case DioErrorType.CONNECT_TIMEOUT:
          Scaffold.of(context).showSnackBar(SnackBar(
            content: Text("Connection time out. Harap periksa koneksi anda"),
          ));
          print('connection time out');
          return;
          break;
        case DioErrorType.DEFAULT:
          Scaffold.of(context).showSnackBar(SnackBar(
            content: Text("Tidak ada koneksi. Harap periksa internet anda"),
          ));
          print('default error');
          return;
          break;
        case DioErrorType.CANCEL:
          Scaffold.of(context).showSnackBar(SnackBar(
            content: Text("Request canceled"),
          ));
          print('canceled');
          return;
          break;
        default:
          print('another error occured');
      }

      // if error on status code
      switch (e.response.statusCode) {
        case 400:
          Scaffold.of(context).showSnackBar(SnackBar(
            content: Text("Gagal submit presensi. Harap coba kembali"),
          ));
          return;
          break;
        case 500:
          Scaffold.of(context).showSnackBar(SnackBar(
            content: Text("Server Error. Harap coba beberapa saat lagi"),
          ));
          return;
          break;
        default:
          Scaffold.of(context).showSnackBar(SnackBar(
            content: Text("Terjadi Error. Harap coba beberapa saat lagi"),
          ));
          return;
      }
    }
  }
}
