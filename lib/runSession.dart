import 'package:firebase_database/firebase_database.dart';

class RunSession {
  String key;
  String date;
  String time;
  String name;
  String desc;
  double distance;
  String isStarted;
  int timerCounter;

  RunSession(this.name, this.desc, this.date, this.time)
      : isStarted = 'notStarted',
        distance = 0.0,
        timerCounter = 0;

  RunSession.fromSnapshot(DataSnapshot snapshot)
      : key = snapshot.key,
        date = snapshot.value['date'],
        time = snapshot.value['time'],
        name = snapshot.value['name'],
        desc = snapshot.value['desc'],
        distance = snapshot.value['distance'].toDouble(),
        isStarted = snapshot.value['isStarted'],
        timerCounter = snapshot.value['timerCounter'].toInt();

  toJson() {
    return {
      'date': date,
      'time': time,
      'name': name,
      'desc': desc,
      'distance': distance,
      'isStarted': isStarted,
      'timerCounter': timerCounter,
    };
  }
}
