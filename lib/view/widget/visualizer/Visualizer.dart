import 'dart:typed_data';

import 'package:dart_midi/dart_midi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_midi/flutter_midi.dart';
import 'package:play_music_along/utils/Log.dart';
import 'package:play_music_along/utils/Midi.dart';
import 'package:tonic/tonic.dart';

abstract class Visualizer extends StatefulWidget {
  const Visualizer({Key key}) : super(key: key);
}

abstract class VisualizerState<T extends Visualizer> extends State<T> {
  @protected final Set activeNotes = Set<String>();

  @override
  void initState() {
    super.initState();

    FlutterMidi.setMethodCallbacks(onNoteEvent: (Uint8List event) {
      Log.v(LogTag.MIDI, '------- Event received $event');
      List<int> bytes = event.toList();

      // FIXME smoreau: raw events are raised from native code, but
      // dart_midi parser needs more information to parse properly
      // It is probably not a good idea to rely on parseTrack as it is
      // Would need to dig midi parsing or to adapt the dart_midi lib to parse
      // atom events
      // Example: NoteOn from native Android: 3-byte Uint8List [0x91, 0x40, 0x5F]
      try {
        MidiEvent midiEvent = Midi.midiParser.parseTrack([0]..addAll(bytes))[0];
        if (midiEvent is NoteOnEvent) {
          String pitchName = Pitch.fromMidiNumber(midiEvent.noteNumber).toString();

          setState(() {
            activeNotes.add(pitchName);
          });
        } else if (midiEvent is NoteOffEvent) {
          String pitchName = Pitch.fromMidiNumber(midiEvent.noteNumber).toString();

          setState(() {
            activeNotes.remove(pitchName);
          });
        }
      } catch (_) {}
    });
  }
}
