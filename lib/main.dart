import 'dart:async';

import 'package:firebase_database/ui/firebase_animated_list.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:running_app/main.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import './page2.dart';
import './page3.dart';
import './runSession.dart';

void main() {
  runApp(MainApp());
}

class MainApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Main',
      theme: ThemeData(
        primarySwatch: Colors.amber,
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  HomePage({this.app});
  final FirebaseApp app;
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  //--------------------
  //FIREBASE VARIABLES
  //--------------------

  final FirebaseDatabase _database = FirebaseDatabase.instance;
  Query _sessionQuery;

  //--------------------
  //POSITION VARIABLES
  //--------------------

  Position _currentPosition;
  Position _previousPosition;
  StreamSubscription<Position> _positionStream;
  List<Position> _locations = [];
  var _totalDistance;

  //--------------------
  //SESSION VARIABLES
  //--------------------

  List<RunSession> _sessionList;
  RunSession _currentSession;
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  StreamSubscription<Event> _onSessionAdded;
  StreamSubscription<Event> _onSessionChanged;
  var totalDistanceExist;
  var totalDistanceAll;

  //--------------------
  //STOPWATCH VARIABLES
  //--------------------

  Stream<int> timerStream;
  StreamSubscription<int> timerSubscription;
  String hoursStr = '00';
  String minutesStr = '00';
  String secondsStr = '00';

  Future calculateDistance(FirebaseDatabase db, RunSession session) async {
    db
        .reference()
        .child('Session')
        .child(session.key)
        .once()
        .then((DataSnapshot snapshot) {
      _totalDistance = snapshot.value['distance'];
    });
    db.reference().child('totalDistance').once().then((DataSnapshot snapshot) {
      totalDistanceAll = snapshot.value['totalDistanceAll'];
    });

    _positionStream = Geolocator.getPositionStream(
            distanceFilter: 10, desiredAccuracy: LocationAccuracy.best)
        .listen((Position position) async {
      if ((await Geolocator.isLocationServiceEnabled())) {
        Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best)
            .then((Position position) {
          setState(() {
            _currentPosition = position;
            _locations.add(_currentPosition);

            if (_locations.length > 1) {
              _previousPosition = _locations.elementAt(_locations.length - 2);

              var _distanceBetweenLastTwoLocations = Geolocator.distanceBetween(
                _previousPosition.latitude,
                _previousPosition.longitude,
                _currentPosition.latitude,
                _currentPosition.longitude,
              );
              _totalDistance += _distanceBetweenLastTwoLocations;
              totalDistanceAll += _distanceBetweenLastTwoLocations;
              db
                  .reference()
                  .child('Session')
                  .child(session.key)
                  .update({'distance': _totalDistance});
              db
                  .reference()
                  .child('totalDistance')
                  .update({'totalDistanceAll': totalDistanceAll});
              print('Total Distance: $_totalDistance');
            }
          });
        }).catchError((err) {
          print(err);
        });
      } else {
        print("GPS is off.");
        showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                content: const Text('Make sure your GPS is on in Settings !'),
                actions: <Widget>[
                  FlatButton(
                      child: Text('OK'),
                      onPressed: () {
                        Navigator.of(context, rootNavigator: true).pop();
                      })
                ],
              );
            });
      }
    });
  }

  Stream<int> stopWatchStream(RunSession session) {
    StreamController<int> streamController;
    Timer timer;
    Duration timerInterval = Duration(seconds: 1);
    int counter;

    void stopTimer() {
      if (timer != null) {
        timer.cancel();
        timer = null;
      }
    }

    void endTimer() {
      if (timer != null) {
        timer.cancel();
        timer = null;
        streamController.close();
      }
    }

    void tick(_) {
      counter++;
      _database
          .reference()
          .child('Session')
          .child(session.key)
          .update({'timerCounter': counter});
      streamController.add(counter);
    }

    void startTimer() {
      _database
          .reference()
          .child('Session')
          .child(session.key)
          .once()
          .then((DataSnapshot snapshot) {
        counter = snapshot.value['timerCounter'];
      });
      timer = Timer.periodic(timerInterval, tick);
    }

    streamController = StreamController<int>(
      onListen: startTimer,
      onCancel: endTimer,
      onResume: startTimer,
      onPause: stopTimer,
    );

    return streamController.stream;
  }

  @override
  void initState() {
    super.initState();
    _sessionList = [];

    _sessionQuery = _database.reference().child('Session');

    _onSessionAdded = _sessionQuery.onChildAdded.listen(onEntryAdded);
    _onSessionChanged = _sessionQuery.onChildChanged.listen(onEntryChanged);

    _database
        .reference()
        .child('totalDistance')
        .once()
        .then((DataSnapshot snapshotExist) {
      try {
        totalDistanceExist = snapshotExist.value['totalDistanceAll'];
      } catch (e) {
        totalDistanceExist = null;
      }
    });
  }

  @override
  void dispose() {
    _positionStream.cancel();
    _onSessionAdded.cancel();
    _onSessionChanged.cancel();
    timerSubscription.cancel();
    super.dispose();
  }

  onEntryAdded(Event event) {
    setState(() {
      _sessionList.add(RunSession.fromSnapshot(event.snapshot));
    });
  }

  onEntryChanged(Event event) {
    var oldEntry = _sessionList.singleWhere((entry) {
      return entry.key == event.snapshot.key;
    });

    setState(() {
      _sessionList[_sessionList.indexOf(oldEntry)] =
          RunSession.fromSnapshot(event.snapshot);
    });
  }

  addNewSession(String name, String desc, String date, String time) {
    RunSession runSession = new RunSession(name, desc, date, time);
    _database
        .reference()
        .child('totalDistance')
        .once()
        .then((DataSnapshot snapshotExist) {
      try {
        totalDistanceExist = snapshotExist.value['totalDistanceAll'];
      } catch (e) {
        totalDistanceExist = null;
      }
    });
    if (totalDistanceExist != null) {
      _database.reference().child('Session').push().set(runSession.toJson());
      _currentSession = runSession;
    } else {
      _database.reference().child('totalDistance').set({'totalDistanceAll': 0});
      _database.reference().child('Session').push().set(runSession.toJson());
      _currentSession = runSession;
    }
  }

  startCalculating(RunSession session) {
    if (session != null) {
      print('Calculating');
      calculateDistance(_database, session);
      setState(() => session.isStarted = 'Started');
      _database
          .reference()
          .child('Session')
          .child(session.key)
          .update({'isStarted': 'Started'});

      timerStream = stopWatchStream(session);
      timerSubscription = timerStream.listen((int newTick) {
        setState(() {
          hoursStr =
              ((newTick / (60 * 60)) % 60).floor().toString().padLeft(2, '0');
          minutesStr = ((newTick / 60) % 60).floor().toString().padLeft(2, '0');
          secondsStr = (newTick % 60).floor().toString().padLeft(2, '0');
        });
      });
    }
  }

  pauseCalculating(RunSession session) {
    if (session != null && session.isStarted == 'Started') {
      print('Paused');
      _positionStream.pause();

      timerSubscription.pause();
      setState(() {
        session.isStarted = 'isPaused';
      });
      _database
          .reference()
          .child('Session')
          .child(session.key)
          .update({'isStarted': 'isPaused'});
    }
  }

  resumeCalculating(RunSession session) {
    if (session != null) {
      print('Resumed');
      setState(() {
        print('Started again');
        session.isStarted = 'Started';
        _currentPosition = null;
        _previousPosition = null;
        _locations = [];
        _positionStream.resume();
        timerSubscription.resume();
      });
      _database
          .reference()
          .child('Session')
          .child(session.key)
          .update({'isStarted': 'Started'});
    }
  }

  endCalculating(RunSession session) {
    if (session != null) {
      print('Stopped');
      _positionStream.cancel();
      timerSubscription.cancel();
      setState(() => session.isStarted = 'Ended');
      _database
          .reference()
          .child('Session')
          .child(session.key)
          .update({'isStarted': 'Ended'});
    }
    _currentSession = null;
  }

  showAddSessionDialog(BuildContext context) async {
    _nameController.clear();
    _descController.clear();
    await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            content: new Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                new Flexible(
                  child: new TextField(
                    controller: _nameController,
                    autofocus: true,
                    decoration: new InputDecoration(
                      labelText: 'Name pls',
                    ),
                  ),
                ),
                new Flexible(
                  child: new TextField(
                    controller: _descController,
                    decoration: new InputDecoration(labelText: 'describe pls'),
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              new FlatButton(
                child: const Text('Cancel'),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              new FlatButton(
                  child: const Text('Start'),
                  onPressed: () {
                    Navigator.pop(context);
                    var _dateNow = DateTime.now().toString();
                    List<String> _listDate = _dateNow.split(' ');
                    _listDate.last = _listDate.last
                        .substring(0, _listDate.last.indexOf('.'));
                    addNewSession(
                        _nameController.text.toString(),
                        _descController.text.toString(),
                        _listDate.first,
                        _listDate.last);
                    setState(() {
                      hoursStr = '00';
                      minutesStr = '00';
                      secondsStr = '00';
                    });
                  })
            ],
          );
        });
  }

  Widget _buildButton(session) {
    if (session.isStarted == 'notStarted') {
      return new Container(
          alignment: Alignment.center,
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                IconButton(
                    icon: Icon(
                      Icons.not_started,
                      color: Colors.blue[300],
                    ),
                    iconSize: 60.0,
                    onPressed: () {
                      startCalculating(session);
                    }),
                Text('Click to Start', style: TextStyle(fontSize: 30)),
              ]));
    } else if (session.isStarted == 'Started') {
      return new Container(
          alignment: Alignment.center,
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                IconButton(
                    icon: Icon(
                      Icons.pause_circle_filled,
                      color: Colors.amber[500],
                    ),
                    iconSize: 60.0,
                    onPressed: () {
                      pauseCalculating(session);
                    }),
                Text('Click to Pause', style: TextStyle(fontSize: 30)),
              ]));
    } else if (session.isStarted == 'isPaused') {
      return new Container(
          alignment: Alignment.center,
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                IconButton(
                    icon: Icon(
                      Icons.not_started,
                      color: Colors.blue[300],
                    ),
                    iconSize: 60.0,
                    onPressed: () {
                      resumeCalculating(session);
                    }),
                Text('Click to resume', style: TextStyle(fontSize: 30)),
              ]));
    } else {
      return new Container(
          alignment: Alignment.center,
          child: Column(children: <Widget>[
            Icon(
              Icons.done_outline,
              color: Colors.green[300],
              size: 60.0,
            ),
            Text('Done', style: TextStyle(fontSize: 30)),
          ]));
    }
  }

  Widget _checkExistSession(session, sessionList) {
    if (session != null && sessionList.length > 0) {
      return new Column(
        children: <Widget>[
          Text('Current Session: ${sessionList.last.name}',
              style: TextStyle(fontSize: 30)),
          Text(
              'Distance: ${sessionList.last.distance != null ? sessionList.last.distance > 1000 ? (sessionList.last.distance / 1000).toStringAsFixed(2) : sessionList.last.distance.toStringAsFixed(2) : 0} ${sessionList.last.distance != null ? sessionList.last.distance > 1000 ? 'KM' : 'meters' : 0}',
              style: TextStyle(fontSize: 30)),
          _buildButton(sessionList.last),
          Text(
            '$hoursStr:$minutesStr:$secondsStr',
            style: TextStyle(
              fontSize: 20.0,
            ),
          ),
        ],
      );
    } else {
      return new Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text('START RUNNING, LAZY ASS', style: TextStyle(fontSize: 20)),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: new AppBar(
        title: Text('Run'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              child: Text('Navigate',
                  style: TextStyle(fontSize: 40, color: Colors.white)),
              decoration: BoxDecoration(
                color: Colors.blue,
              ),
            ),
            ListTile(
              title: Text('All Sessions'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ProgressPage()),
                );
              },
            ),
            ListTile(
              title: Text('Rewards'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RewardsPage()),
                );
              },
            ),
          ],
        ),
      ),
      body: new Container(
        alignment: Alignment.center,
        margin: EdgeInsets.all(20),
        child: _checkExistSession(_currentSession, _sessionList),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        child: Container(
            height: 150.0,
            child: Container(
                alignment: Alignment.center,
                child: ElevatedButton(
                  child: Text(
                    'End Session',
                    style: TextStyle(fontSize: 20),
                  ),
                  style: _currentSession != null && _sessionList.length >= 1
                      ? _sessionList.last.isStarted != 'notStarted'
                          ? ButtonStyle(
                              backgroundColor:
                                  MaterialStateProperty.resolveWith<Color>(
                                (Set<MaterialState> states) {
                                  if (states.contains(MaterialState.pressed))
                                    return Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.5);
                                  return null; // Use the component's default.
                                },
                              ),
                            )
                          : ButtonStyle(
                              backgroundColor:
                                  MaterialStateProperty.all(Colors.grey[300]),
                            )
                      : ButtonStyle(
                          backgroundColor:
                              MaterialStateProperty.all(Colors.grey[300]),
                        ),
                  onPressed: () {
                    _currentSession != null &&
                            _sessionList.last.isStarted != 'notStarted'
                        ? endCalculating(_sessionList.last)
                        // ignore: unnecessary_statements
                        : null;
                  },
                ))),
      ),
      floatingActionButton: _currentSession == null
          ? FloatingActionButton(
              onPressed: () {
                showAddSessionDialog(context);
              },
              tooltip: 'Increment Counter',
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 40,
              ))
          : FloatingActionButton(
              onPressed: () {},
              tooltip: 'Increment Counter',
              child: const Icon(
                Icons.add,
                color: Colors.white,
                size: 40,
              ),
              backgroundColor: Colors.grey[300],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
// import 'dart:async';

// import 'package:firebase_database/ui/firebase_animated_list.dart';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:running_app/main.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_database/firebase_database.dart';

// import './page2.dart';
// import './runSession.dart';

// void main() {
//   runApp(MainApp());
// }

// class MainApp extends StatelessWidget {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Main Page',
//       theme: ThemeData(
//         primarySwatch: Colors.amber,
//       ),
//       home: HomePage(),
//     );
//   }
// }

// //HomePage class
// class HomePage extends StatefulWidget {
//   HomePage({this.app});
//   final FirebaseApp app;
//   @override
//   _HomePageState createState() => _HomePageState();
// }

// class _HomePageState extends State<HomePage> {
//   Position _currentPosition;
//   Position _previousPosition;
//   StreamSubscription<Position> _positionStream;

//   List<RunSession> _sessionList;
//   RunSession currentSession;

//   final FirebaseDatabase _database = FirebaseDatabase.instance;

//   final _nameController = TextEditingController();
//   final _descController = TextEditingController();
//   StreamSubscription<Event> _onSessionAdded;
//   StreamSubscription<Event> _onSessionChanged;

//   Query _sessionQuery;

//   List<Position> locations = [];

//   var _totalDistance;

//   Future calculateDistance(FirebaseDatabase db, RunSession session) async {
//     db
//         .reference()
//         .child('Session')
//         .child(session.key)
//         .once()
//         .then((DataSnapshot snapshot) {
//       _totalDistance = snapshot.value['distance'];
//     });
//     _positionStream = Geolocator.getPositionStream(
//             distanceFilter: 10, desiredAccuracy: LocationAccuracy.best)
//         .listen((Position position) async {
//       if ((await Geolocator.isLocationServiceEnabled())) {
//         Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best)
//             .then((Position position) {
//           setState(() {
//             _currentPosition = position;
//             locations.add(_currentPosition);

//             if (locations.length > 1) {
//               _previousPosition = locations.elementAt(locations.length - 2);

//               var _distanceBetweenLastTwoLocations = Geolocator.distanceBetween(
//                 _previousPosition.latitude,
//                 _previousPosition.longitude,
//                 _currentPosition.latitude,
//                 _currentPosition.longitude,
//               );
//               _totalDistance += _distanceBetweenLastTwoLocations;
//               db
//                   .reference()
//                   .child('Session')
//                   .child(session.key)
//                   .update({'distance': _totalDistance});
//               print('Total Distance: $_totalDistance');
//             }
//           });
//         }).catchError((err) {
//           print(err);
//         });
//       } else {
//         print("GPS is off.");
//         showDialog(
//             context: context,
//             builder: (BuildContext context) {
//               return AlertDialog(
//                 content: const Text('Make sure your GPS is on in Settings !'),
//                 actions: <Widget>[
//                   FlatButton(
//                       child: Text('OK'),
//                       onPressed: () {
//                         Navigator.of(context, rootNavigator: true).pop();
//                       })
//                 ],
//               );
//             });
//       }
//     });
//   }

//   @override
//   void initState() {
//     super.initState();

//     _sessionList = new List();

//     _sessionQuery = _database.reference().child('Session');

//     _onSessionAdded = _sessionQuery.onChildAdded.listen(onEntryAdded);
//     _onSessionChanged = _sessionQuery.onChildChanged.listen(onEntryChanged);
//   }

//   @override
//   void dispose() {
//     _onSessionAdded.cancel();
//     _onSessionChanged.cancel();
//     _positionStream.cancel();
//     super.dispose();
//   }

//   onEntryAdded(Event event) {
//     setState(() {
//       _sessionList.add(RunSession.fromSnapshot(event.snapshot));
//     });
//   }

//   onEntryChanged(Event event) {
//     var oldEntry = _sessionList.singleWhere((entry) {
//       return entry.key == event.snapshot.key;
//     });

//     setState(() {
//       _sessionList[_sessionList.indexOf(oldEntry)] =
//           RunSession.fromSnapshot(event.snapshot);
//     });
//   }

//   addNewSession(String name, String desc) {
//     RunSession runSession = new RunSession(name, desc);
//     _database.reference().child('Session').push().set(runSession.toJson());
//     currentSession = runSession;
//   }

//   updateSession(RunSession session) {
//     if (session != null) {
//       print('Calculating');
//       calculateDistance(_database, session);
//     }
//   }

//   deleteSession(RunSession session, int index) {
//     if (session != null) {
//       _database
//           .reference()
//           .child('Session')
//           .child(session.key)
//           .remove()
//           .then((_) {
//         setState(() {
//           _sessionList.removeAt(index);
//         });
//       });
//     }
//   }

//   showAddSessionDialog(BuildContext context) async {
//     _nameController.clear();
//     _descController.clear();
//     await showDialog<String>(
//         context: context,
//         builder: (BuildContext context) {
//           return AlertDialog(
//             content: new Column(
//               mainAxisSize: MainAxisSize.min,
//               children: <Widget>[
//                 new Flexible(
//                   child: new TextField(
//                     controller: _nameController,
//                     autofocus: true,
//                     decoration: new InputDecoration(
//                       labelText: 'Name pls',
//                     ),
//                   ),
//                 ),
//                 new Flexible(
//                   child: new TextField(
//                     controller: _descController,
//                     decoration: new InputDecoration(labelText: 'describe pls'),
//                   ),
//                 ),
//               ],
//             ),
//             actions: <Widget>[
//               new FlatButton(
//                 child: const Text('Cancel'),
//                 onPressed: () {
//                   Navigator.pop(context);
//                 },
//               ),
//               new FlatButton(
//                   child: const Text('Start'),
//                   onPressed: () {
//                     Navigator.pop(context);
//                     addNewSession(_nameController.text.toString(),
//                         _descController.text.toString());
//                   })
//             ],
//           );
//         });
//   }

//   showAlertDialog(BuildContext context, RunSession session, int index) {
//     // set up the buttons
//     Widget cancelButton = FlatButton(
//       child: Text("Nah brah"),
//       onPressed: () {
//         Navigator.pop(context);
//       },
//     );
//     Widget continueButton = FlatButton(
//       child: Text("Hell ye"),
//       onPressed: () {
//         Navigator.pop(context);
//         deleteSession(_sessionList[index], index);
//       },
//     );

//     // set up the AlertDialog
//     AlertDialog alert = AlertDialog(
//       title: Text("You srs?"),
//       content: Text("You gon delete your hard work??"),
//       actions: [
//         cancelButton,
//         continueButton,
//       ],
//     );

//     // show the dialog
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return alert;
//       },
//     );
//   }

//   //Button States
// Widget _buildButton(state, index) {
//   if (state == 'notStarted') {
//     return new IconButton(
//         icon: Icon(
//           Icons.not_started,
//           color: Colors.blue[300],
//           size: 20.0,
//         ),
//         onPressed: () {
//           updateSession(_sessionList[index]);
//           setState(() => _sessionList[index].isStarted = 'Started');
//           _database
//               .reference()
//               .child('Session')
//               .child(_sessionList[index].key)
//               .update({'isStarted': 'Started'});
//         });
//   } else if (state == 'Started') {
//     return new IconButton(
//         icon: Icon(
//           Icons.stop_circle,
//           color: Colors.red,
//           size: 20.0,
//         ),
//         onPressed: () {
//           _positionStream.cancel();
//           setState(() => _sessionList[index].isStarted = 'notStarted');
//           _database
//               .reference()
//               .child('Session')
//               .child(_sessionList[index].key)
//               .update({'isStarted': 'notStarted'});
//         });
//   }
// }

//   Widget showSessionList() {
//     if (_sessionList.length > 0) {
//       return ListView.builder(
//           shrinkWrap: true,
//           itemCount: _sessionList.length,
//           itemBuilder: (BuildContext context, int index) {
//             String name = _sessionList[index].name;
//             String desc = _sessionList[index].desc;
//             double distance = _sessionList[index].distance;
//             return Dismissible(
//               key: Key(name),
//               background: Container(color: Colors.red),
//               child: ListTile(
//                 title: Text(
//                   name != null ? name : 'Null',
//                   style: TextStyle(fontSize: 20.0),
//                 ),
//                 subtitle: Text(
//                     'Description: $desc, Distance: ${distance != null ? distance > 1000 ? (distance / 1000).toStringAsFixed(2) : distance.toStringAsFixed(2) : 0} ${distance != null ? distance > 1000 ? 'KM' : 'meters' : 0}'),
//                 trailing: _buildButton(_sessionList[index].isStarted, index),
//                 onLongPress: () {
//                   showAlertDialog(context, _sessionList[index], index);
//                 },
//               ),
//             );
//           });
//     } else {
//       return Container(
//           alignment: Alignment.center,
//           padding: EdgeInsets.all(10),
//           child: Text(
//             "Go for a run, you lazy ass.",
//             textAlign: TextAlign.center,
//             style: TextStyle(fontSize: 20.0),
//           ));
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: new AppBar(
//         title: Text('Home'),
//       ),
//       body: showSessionList(),
//       bottomNavigationBar: BottomAppBar(
//         shape: const CircularNotchedRectangle(),
//         child: Container(
//             height: 150.0,
//             child: Container(
//                 alignment: Alignment.center,
//                 child: ElevatedButton(
//                   child: Text(
//                     'End Session',
//                     style: TextStyle(fontSize: 20),
//                   ),
//                   style: ButtonStyle(
//                     backgroundColor: MaterialStateProperty.resolveWith<Color>(
//                       (Set<MaterialState> states) {
//                         if (states.contains(MaterialState.pressed))
//                           return Theme.of(context)
//                               .colorScheme
//                               .primary
//                               .withOpacity(0.5);
//                         return null; // Use the component's default.
//                       },
//                     ),
//                   ),
//                   onPressed: () {
//                     setState(() => _positionStream.cancel());
//                   },
//                 ))),
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () {
//           showAddSessionDialog(context);
//         },
//         tooltip: 'Increment Counter',
//         child: const Icon(
//           Icons.add,
//           color: Colors.white,
//           size: 40,
//         ),
//       ),
//       floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
//     );
//   }
// }
