import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:play_music_along/utils/Midi.dart';

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
            color: note is Rest ? Colors.transparent : MidiPitch(midiNumber).pitchColor,
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
