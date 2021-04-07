import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import './runSession.dart';
import './main.dart';

class ProgressPage extends StatefulWidget {
  ProgressPage({Key key, this.app}) : super(key: key);
  final FirebaseApp app;
  @override
  _ProgressPageState createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  Query _sessionQuery;
  Query _distanceQuery;

  List<RunSession> _sessionList;
  StreamSubscription<Event> _onSessionAdded;
  StreamSubscription<Event> _onSessionChanged;
  StreamSubscription<Event> _onDistanceChanged;

  double _totalDistance;

  @override
  void initState() {
    super.initState();
    _sessionList = [];

    _sessionQuery = _database.reference().child('Session');
    _distanceQuery = _database.reference().child('totalDistance');

    _distanceQuery.once().then((DataSnapshot snapshot) {
      try {
        setState(() {
          _totalDistance = snapshot.value['totalDistanceAll'];
        });
      } catch (e) {
        setState(() {
          _totalDistance = 0.0;
        });
      }
    });

    _onSessionAdded = _sessionQuery.onChildAdded.listen(onEntryAdded);
    _onSessionChanged = _sessionQuery.onChildChanged.listen(onEntryChanged);

    _onDistanceChanged = _distanceQuery.onChildChanged.listen(onDistChanged);
  }

  @override
  void dispose() {
    _onSessionAdded.cancel();
    _onSessionChanged.cancel();
    _onDistanceChanged.cancel();
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

  onDistChanged(Event event) {
    setState(() {
      _totalDistance = event.snapshot.value.toDouble();
    });
  }

  deleteSession(RunSession session, int index, sessionList) {
    if (session != null) {
      double _newTotalDistance = _totalDistance - sessionList[index].distance;
      _database
          .reference()
          .child('totalDistance')
          .update({'totalDistanceAll': _newTotalDistance});

      _database
          .reference()
          .child('Session')
          .child(session.key)
          .remove()
          .then((_) {
        setState(() {
          sessionList.removeAt(index);
        });
      });
    }
  }

  showAlertDialog(
      BuildContext context, RunSession session, int index, sessionList) {
    // set up the buttons
    Widget cancelButton = FlatButton(
      child: Text("Nah brah"),
      onPressed: () {
        Navigator.pop(context);
      },
    );
    Widget continueButton = FlatButton(
      child: Text("Hell ye"),
      onPressed: () {
        Navigator.pop(context);
        deleteSession(session, index, sessionList);
      },
    );

    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text("You srs?"),
      content: Text("You gon delete your hard work??"),
      actions: [
        cancelButton,
        continueButton,
      ],
    );

    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  checkInProgress(RunSession session) {
    if (session.isStarted != 'Ended') {
      return new Text('Calculating...');
    } else {
      return new Icon(
        Icons.done_outline,
        color: Colors.green[300],
        size: 30.0,
      );
    }
  }

  Widget showSessionList(sessionList) {
    if (sessionList.length > 0) {
      return ListView.builder(
          shrinkWrap: true,
          itemCount: sessionList.length,
          itemBuilder: (BuildContext context, int index) {
            int reverseIndex = sessionList.length - 1 - index;
            String name = sessionList[reverseIndex].name;
            String desc = sessionList[reverseIndex].desc;
            double distance = sessionList[reverseIndex].distance;
            int timerCounter = sessionList[reverseIndex].timerCounter;
            String hoursStr = ((timerCounter / (60 * 60)) % 60)
                .floor()
                .toString()
                .padLeft(2, '0');
            String minutesStr =
                ((timerCounter / 60) % 60).floor().toString().padLeft(2, '0');
            String secondsStr =
                (timerCounter % 60).floor().toString().padLeft(2, '0');
            String date = sessionList[reverseIndex].date;
            String time = sessionList[reverseIndex].time;
            return Dismissible(
              key: Key(name),
              background: Container(color: Colors.red),
              child: ListTile(
                title: Text(
                  name != null ? name : 'Null',
                  style: TextStyle(fontSize: 20.0),
                ),
                subtitle: Text(
                    'Description: $desc\nDistance: ${distance != null ? distance > 1000 ? (distance / 1000).toStringAsFixed(2) : distance.toStringAsFixed(2) : 0} ${distance != null ? distance > 1000 ? 'KM' : 'meters' : 0}\nTime: $hoursStr:$minutesStr:$secondsStr\n\nDate: $date\nTime: $time'),
                onLongPress: () {
                  showAlertDialog(context, sessionList[reverseIndex],
                      reverseIndex, sessionList);
                },
                trailing: checkInProgress(sessionList[reverseIndex]),
              ),
            );
          });
    } else {
      return Container(
          alignment: Alignment.center,
          padding: EdgeInsets.all(10),
          child: Text(
            "Go for a run, you lazy ass.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20.0),
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    double totalDistanceAll = _totalDistance;
    return Scaffold(
        appBar: AppBar(
          leading: IconButton(
              icon: Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () {
                int count = 0;
                Navigator.popUntil(context, (route) {
                  return count++ == 2;
                });
              }),
          title: Text('Progress'),
        ),
        body: Padding(
          padding: EdgeInsets.all(16.0),
          child: Column(
            children: <Widget>[
              showSessionList(_sessionList),
              Padding(padding: EdgeInsets.all(20.0)),
              Text(
                  'You have ran a total of ${totalDistanceAll != null ? totalDistanceAll > 1000 ? (totalDistanceAll / 1000).toStringAsFixed(2) : totalDistanceAll.toStringAsFixed(2) : 0} ${totalDistanceAll != null ? totalDistanceAll > 1000 ? 'KM' : 'meters' : 0}'),
            ],
          ),
        ));
  }
}

// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_database/firebase_database.dart';

// import './runSession.dart';

// class ProgressPage extends StatefulWidget {
//   final List<RunSession> oriSessionList;

//   ProgressPage({Key key, this.app, @required this.oriSessionList})
//       : super(key: key);
//   final FirebaseApp app;
//   @override
//   _ProgressPageState createState() => _ProgressPageState();
// }

// class _ProgressPageState extends State<ProgressPage> {
//   final FirebaseDatabase _database = FirebaseDatabase.instance;

//   deleteSession(RunSession session, int index, sessionList) {
//     if (session != null) {
//       _database
//           .reference()
//           .child('Session')
//           .child(session.key)
//           .remove()
//           .then((_) {
//         setState(() {
//           sessionList.removeAt(index);
//         });
//       });
//     }
//   }

//   showAlertDialog(
//       BuildContext context, RunSession session, int index, sessionList) {
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
//         deleteSession(session, index, sessionList);
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

//   checkInProgress(RunSession session) {
//     if (session.isStarted != 'Ended') {
//       return new Text('Calculating...');
//     } else {
//       return new Icon(
//         Icons.done_outline,
//         color: Colors.green[300],
//         size: 30.0,
//       );
//     }
//   }

//   Widget showSessionList(sessionList) {
//     if (sessionList.length > 0) {
//       return ListView.builder(
//           shrinkWrap: true,
//           itemCount: sessionList.length,
//           itemBuilder: (BuildContext context, int index) {
//             int reverseIndex = sessionList.length - 1 - index;
//             String name = sessionList[reverseIndex].name;
//             String desc = sessionList[reverseIndex].desc;
//             double distance = sessionList[reverseIndex].distance;
//             int timerCounter = sessionList[reverseIndex].timerCounter;
//             String hoursStr = ((timerCounter / (60 * 60)) % 60)
//                 .floor()
//                 .toString()
//                 .padLeft(2, '0');
//             String minutesStr =
//                 ((timerCounter / 60) % 60).floor().toString().padLeft(2, '0');
//             String secondsStr =
//                 (timerCounter % 60).floor().toString().padLeft(2, '0');
//             return Dismissible(
//               key: Key(name),
//               background: Container(color: Colors.red),
//               child: ListTile(
//                 title: Text(
//                   name != null ? name : 'Null',
//                   style: TextStyle(fontSize: 20.0),
//                 ),
//                 subtitle: sessionList[reverseIndex].isStarted == 'Ended'
//                     ? Text(
//                         'Description: $desc\nDistance: ${distance != null ? distance > 1000 ? (distance / 1000).toStringAsFixed(2) : distance.toStringAsFixed(2) : 0} ${distance != null ? distance > 1000 ? 'KM' : 'meters' : 0}\nTime: $hoursStr:$minutesStr:$secondsStr')
//                     : Text('Description: $desc'),
//                 onLongPress: () {
//                   showAlertDialog(context, sessionList[reverseIndex],
//                       reverseIndex, sessionList);
//                 },
//                 trailing: checkInProgress(sessionList[reverseIndex]),
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
//     List<RunSession> sessionList = widget.oriSessionList;
//     double totalDistanceAll = 0;
//     sessionList.forEach((e) {
//       if (e.distance != null) {
//         totalDistanceAll += e.distance.toDouble();
//       }
//     });
//     return Scaffold(
//         appBar: AppBar(
//           leading: IconButton(
//             icon: Icon(Icons.arrow_back, color: Colors.black),
//             onPressed: () => Navigator.of(context).pop(),
//           ),
//           title: Text('Progress'),
//         ),
//         body: Padding(
//           padding: EdgeInsets.all(16.0),
//           child: Column(
//             children: <Widget>[
//               showSessionList(sessionList),
//               Padding(padding: EdgeInsets.all(20.0)),
//               Text(
//                   'You have ran a total of ${totalDistanceAll != null ? totalDistanceAll > 1000 ? (totalDistanceAll / 1000).toStringAsFixed(2) : totalDistanceAll.toStringAsFixed(2) : 0} ${totalDistanceAll != null ? totalDistanceAll > 1000 ? 'KM' : 'meters' : 0}'),
//             ],
//           ),
//         ));
//   }
// }
// }
