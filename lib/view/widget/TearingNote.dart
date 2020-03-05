import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:play_music_along/utils/Midi.dart';
import 'package:tonic/tonic.dart';

Color getNoteColor(int midiNumber) {
  final Map colors = {
    'C': Colors.red,
    'D': Colors.yellow,
    'E': Colors.deepPurple,
    'F': Colors.blueAccent,
    'G': Colors.pinkAccent,
    'A': Colors.green,
    'B': Colors.orange,
  };
  String noteNameWithoutAccidental =
      Pitch.fromMidiNumber(midiNumber).letterName[0];
  return colors[noteNameWithoutAccidental];
}

class TearingNote extends StatelessWidget {
  final double width;
  final Note note;
  final MidiFileInfo midiFileInfo;

  const TearingNote({
    Key key,
    @required this.width,
    @required this.note,
    @required this.midiFileInfo,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double duration = note.durationInTicks ?? 100;
    final double height =
        midiFileInfo.getViewDimension(durationInTicks: duration);
    final int midiNumber = note.midiNumber;
    final pitch = note.pitch;
    BorderRadiusGeometry borderRadius =
        const BorderRadius.all(Radius.circular(2.0));

    return Positioned(
      bottom: midiFileInfo.getViewDimension(
          durationInTicks: note.absoluteStartOffsetInTicks),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Container(
            height: height,
            padding: EdgeInsets.only(bottom: 5),
            color: note is Rest ? Colors.transparent : getNoteColor(midiNumber),
            width: width,
            child: Align(
                alignment: FractionalOffset.bottomCenter,
                child: Text(
                  pitch.toString(),
                  style: TextStyle(fontSize: 8, color: Colors.white),
                  textAlign: TextAlign.center,
                ))),
      ),
    );
  }
}
