import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:play_music_along/utils/Midi.dart';
import 'package:play_music_along/view/widget/visualizer/Visualizer.dart';
import 'package:tonic/tonic.dart';

class PianoVisualizer extends Visualizer {
  final double keyWidth;
  final ScrollController scrollController;
  final Function onHorizontalScrolling;

  const PianoVisualizer(
      {Key key,
      @required this.keyWidth,
      this.scrollController,
      this.onHorizontalScrolling})
      : super(key: key);

  @override
  PianoVisualizerState createState() => PianoVisualizerState();
}

class PianoVisualizerState extends VisualizerState<PianoVisualizer> {
  final BorderRadiusGeometry _borderRadius = const BorderRadius.only(
      bottomLeft: Radius.circular(3.0), bottomRight: Radius.circular(3.0));
  final bool _showLabels = true;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<UserScrollNotification>(
      onNotification: (UserScrollNotification notification) =>
          widget.onHorizontalScrolling(notification, visualizerOrigin: true),
      child: ListView.builder(
        itemCount: 7,
        controller: widget.scrollController,
        scrollDirection: Axis.horizontal,
        itemBuilder: (BuildContext context, int index) {
          final int octave = index + 1;
          return SafeArea(
            child: Stack(children: <Widget>[
              Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                _buildKey('C', octave),
                _buildKey('D', octave),
                _buildKey('E', octave),
                _buildKey('F', octave),
                _buildKey('G', octave),
                _buildKey('A', octave),
                _buildKey('B', octave),
              ]),
              Positioned(
                  left: 0.0,
                  right: 0.0,
                  bottom: 50,
                  top: 0.0,
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(width: widget.keyWidth * .5),
                        _buildKey('C♯', octave),
                        _buildKey('D♯', octave),
                        Container(width: widget.keyWidth),
                        _buildKey('F♯', octave),
                        _buildKey('G♯', octave),
                        _buildKey('A♯', octave),
                        Container(width: widget.keyWidth * .5),
                      ])),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildKey(String noteName, int octave) {
    var pitch = Pitch.parse(noteName + octave.toString());
    final pitchName = pitch.toString();
    final accidental = pitch.accidentalSemitones > 0;

    final keyColor = accidental ? Colors.black : Colors.white;

    final pianoKey = Stack(
      children: <Widget>[
        Semantics(
            button: true,
            hint: pitchName,
            child: Material(
                borderRadius: _borderRadius,
                color: activeNotes.contains(pitchName)
                    ? MidiPitch(pitch: pitch).pitchColor
                    : keyColor,
                child: InkWell(
                  borderRadius: _borderRadius,
                  highlightColor: Colors.grey,
                ))),
        Positioned(
            left: 0.0,
            right: 0.0,
            bottom: 20.0,
            child: _showLabels
                ? Text(pitchName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 8,
                        color: !accidental ? Colors.black : Colors.white))
                : Container()),
      ],
    );
    if (accidental) {
      return Container(
          width: widget.keyWidth,
          margin: EdgeInsets.symmetric(horizontal: 2.0),
          padding: EdgeInsets.symmetric(horizontal: widget.keyWidth * .1),
          child: Material(
              elevation: 4.0,
              borderRadius: _borderRadius,
              shadowColor: Color(0x802196F3),
              child: pianoKey));
    }
    return Container(
      width: widget.keyWidth,
      child: pianoKey,
      margin: EdgeInsets.symmetric(horizontal: 2.0),
    );
  }
}
