import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:play_music_along/utils/Log.dart';
import 'package:play_music_along/view/widget/CustomScaffoldBody.dart';
import 'package:play_music_along/view/widget/SliverHeader.dart';
import 'package:sprintf/sprintf.dart';
import 'package:flutter_midi/flutter_midi.dart';
import 'package:flutter/services.dart';
import 'package:dart_midi/dart_midi.dart';


class Dummy extends StatefulWidget {
  @override
  _DummyState createState() => _DummyState();
}

class _DummyState extends State<Dummy> {
  final _scaffoldContext = ScaffoldContext();
  final _scrollController = ScrollController();
  final notes = <String>[];



  @override
  void initState() {
    super.initState();
    addNote('initState');

    dumpMidi(File('/data/user/0/com.example.play_music_along/app_flutter/midi/test.mid'));

    var soundBank = 'assets/sf2/UprightPianoKW-20190703.sf2';
    play(soundBank);
  }

  void dumpMidi(File midiFile) {
    Log.v(LogTag.MIDI, 'Parsing MIDI file ${midiFile.path}');
    var parser = MidiParser();
    MidiFile parsedMidi = parser.parseMidiFromFile(midiFile);
    var tracksCount = parsedMidi.tracks.length;
    Log.v(LogTag.MIDI, 'Processing $tracksCount tracks');

    // FIXME smoreau: time slots merging, see mid=64 in 2 tracks
    for (var track in parsedMidi.tracks) {
      for (var event in track) {
        if (event is SetTempoEvent) {
          Log.v(LogTag.MIDI, 'Event SetTempoEvent');
        } else if (event is TimeSignatureEvent) {
          Log.v(LogTag.MIDI, 'Event TimeSignatureEvent');
        } else if (event is ProgramChangeMidiEvent) {
          Log.v(LogTag.MIDI, 'Event ProgramChangeMidiEvent');
        } else if (event is InstrumentNameEvent) {
          Log.v(LogTag.MIDI, 'Event InstrumentNameEvent: ${event.text} detected');
        }
      }
    }
  }


  Future play(String soundBank) async {
    FlutterMidi.unmute(); // Optionally Unmute
    ByteData _byte = await rootBundle.load(soundBank);
    //FlutterMidi.prepare(sf2: _byte);
    FlutterMidi.playMidiFile(path: '/data/user/0/com.example.play_music_along/app_flutter/midi/test.mid');
  }

  void addNote(String prefix) {
    String time = getCurrentTime();
    notes.add('$prefix @ $time');
  }

  String getCurrentTime() {
    var now = DateTime.now();
    return sprintf('%d.%03d%03d', [now.second, now.millisecond, now.microsecond]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomPadding: false,
      body: CustomScaffoldBody(
          scaffoldContext: _scaffoldContext,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: <Widget>[
              SliverHeader(
                  title:
                  'List of audio files'
              ),
              SliverPadding(
                padding: const EdgeInsets.only(
                    left: 25.0, top: 30.0, right: 25.0),
                sliver: SliverFixedExtentList(
                  itemExtent: 30,
                  delegate: SliverChildBuilderDelegate(
                        (BuildContext context, int index) {
                      return ListTile(
                        leading: Text(
                          '${notes[index]}',
                          style: TextStyle(fontSize: 12.0),
                        ),
                        dense: true,
                      );
                    },
                    childCount: notes.length,
                  )
                )
              )
            ])
          )
    );
  }
}
