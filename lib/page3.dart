import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import 'package:progress_timeline/progress_timeline.dart';

import './runSession.dart';
import './main.dart';

class RewardsPage extends StatefulWidget {
  RewardsPage({Key key, this.app}) : super(key: key);
  final FirebaseApp app;
  @override
  _RewardsPageState createState() => _RewardsPageState();
}

class _RewardsPageState extends State<RewardsPage> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  Query _distanceQuery;

  StreamSubscription<Event> _onDistanceChanged;

  double _totalDistance;

  ProgressTimeline progressTimeline;

  @override
  void initState() {
    super.initState();
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

    _onDistanceChanged = _distanceQuery.onChildChanged.listen(onDistChanged);

    List<SingleState> allStages = [
      SingleState(stateTitle: 'Ewobb'),
      SingleState(stateTitle: 'Noob'),
      SingleState(stateTitle: 'Uhh'),
      SingleState(stateTitle: 'Okay...'),
      SingleState(stateTitle: 'I see you'),
      SingleState(stateTitle: 'Dayum'),
      SingleState(stateTitle: 'WOAH'),
      SingleState(stateTitle: 'Have my babies!'),
      SingleState(stateTitle: 'TEst'),
      SingleState(stateTitle: 'tEsfw'),
    ];
    progressTimeline = new ProgressTimeline(
      states: allStages,
      connectorLength: 100,
      connectorWidth: 20,
      connectorColor: Colors.amber[700],
      iconSize: 35,
    );
  }

  @override
  void dispose() {
    _onDistanceChanged.cancel();
    super.dispose();
  }

  calcReward(double increment, double totalDistance) {
    if (totalDistance != null) {
      int loops = (totalDistance ~/ increment);
      for (int i = 0; i < loops; i++) {
        progressTimeline.gotoNextStage();
      }
    }
  }

  onDistChanged(Event event) {
    setState(() {
      _totalDistance = event.snapshot.value.toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    double totalDistanceRewards = _totalDistance;
    calcReward(1000.0, totalDistanceRewards);
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
          title: Text('Rewards'),
        ),
        body: Padding(
            padding: EdgeInsets.all(40.0),
            child: Column(children: <Widget>[
              Text('$totalDistanceRewards'),
              progressTimeline,
            ])));
  }
}
