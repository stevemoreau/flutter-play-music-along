import 'dart:io';
import 'dart:math';

import 'package:dart_midi/dart_midi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_midi/flutter_midi.dart';
import 'package:play_music_along/model/AudioFile.dart';
import 'package:play_music_along/utils/Log.dart';
import 'package:play_music_along/view/widget/SliverHeader.dart';

class PlayAlongScreen extends StatefulWidget {
  final AudioFile audioFile;

  const PlayAlongScreen({Key key, this.audioFile}) : super(key: key);

  @override
  _PlayAlongScreenState createState() => _PlayAlongScreenState();
}

enum Instrument { PIANO }

class Measure {
  int ticksPerBeat = 0;

  int timeSignatureNumerator = 4;
  int timeSignatureDenominator = 4;
  int microSecondsPerBeat = 0;

  int durationInMicroSeconds() {
    return 0;
  }
}

// FIXME smoreau: add music atom

class Note {
  double absoluteStartOffsetInTicks;
  double durationInTicks;
  String type = 'NOTE';

  Note(this.absoluteStartOffsetInTicks, {this.durationInTicks});

  @override
  String toString() {
    return '$type[duration=$durationInTicks, start=$absoluteStartOffsetInTicks]';
  }
}

class Rest extends Note {
  Rest(double absoluteStartOffsetInTicks) : super(absoluteStartOffsetInTicks) {
    type = 'REST';
  }
}

// FIXME smoreau: add Track with instrument + min/max midi number + notes

class _PlayAlongScreenState extends State<PlayAlongScreen> {
  var _restsAndNotesByMidiNumber = {};
  var _midiNumberRange = {'min': 0, 'max': 127};
  double _overallDurationInTicks = 0;
  double _averageNoteDuration = 200;

  @override
  void initState() {
    play('assets/sf2/UprightPianoKW-20190703.sf2');
    loadMidi(File(widget.audioFile.path));
    super.initState();
  }

  Instrument _getInstrument(InstrumentNameEvent event) {
    Instrument instrument;
    String instrumentName = event.text;
    if ('Piano' == instrumentName) {
      instrument = Instrument.PIANO;
    } else {
      Log.v(LogTag.MIDI,
          'Instrument $instrumentName not supported at the moment');
    }
    return instrument;
  }

  void loadMidi(File midiFile) {
    Log.v(LogTag.MIDI, 'Parsing MIDI file ${midiFile.path}');
    var parser = MidiParser();
    MidiFile parsedMidi = parser.parseMidiFromFile(midiFile);
    var tracksCount = parsedMidi.tracks.length;
    Log.v(LogTag.MIDI, 'Processing $tracksCount tracks');

    Measure currentMeasureInfo = Measure();
    currentMeasureInfo.ticksPerBeat = parsedMidi.header.ticksPerBeat;

    var range = {'min': 127, 'max': 0};
    List<double> notesDurations = [];

    // FIXME smoreau: time slots merging, see mid=64 in 2 tracks
    for (var track in parsedMidi.tracks) {
      Instrument instrument;
      double currentOffsetInTicks = 0;
      for (var event in track) {
        currentOffsetInTicks += event.deltaTime;
        if (event is SetTempoEvent) {
          Log.v(LogTag.MIDI, 'Event SetTempoEvent');
          currentMeasureInfo.microSecondsPerBeat = event.microsecondsPerBeat;
        } else if (event is TimeSignatureEvent) {
          Log.v(LogTag.MIDI, 'Event TimeSignatureEvent');
          currentMeasureInfo.timeSignatureNumerator = event.numerator;
          currentMeasureInfo.timeSignatureDenominator = event.denominator;
        } else if (event is ProgramChangeMidiEvent) {
          Log.v(LogTag.MIDI, 'Event ProgramChangeMidiEvent');
        } else if (event is InstrumentNameEvent) {
          instrument = _getInstrument(event);
          Log.v(LogTag.MIDI, 'Event InstrumentNameEvent: $instrument detected');
        } else if (event is NoteOnEvent) {
          int noteNumber = event.noteNumber;

          Log.v(LogTag.MIDI, 'Starting note $noteNumber at $currentOffsetInTicks', midiNumber: noteNumber);

          range['min'] = min(noteNumber, range['min']);
          range['max'] = max(noteNumber, range['max']);

          var notesAndRestsList = _restsAndNotesByMidiNumber[noteNumber];
          if (notesAndRestsList == null) {
            notesAndRestsList = <Note>[].toList();
            _restsAndNotesByMidiNumber[noteNumber] = notesAndRestsList;
            if (currentOffsetInTicks > 0) {
              Log.v(LogTag.MIDI, 'Initial rest for note $noteNumber', midiNumber: noteNumber);
              notesAndRestsList.add(Rest(0)..durationInTicks = currentOffsetInTicks);
            }
          }

          if (notesAndRestsList != null) {
            if (notesAndRestsList.length > 0) {
              Note lastNoteOrRest = notesAndRestsList.last;
              lastNoteOrRest.durationInTicks = currentOffsetInTicks - lastNoteOrRest.absoluteStartOffsetInTicks;
              Log.v(LogTag.MIDI, 'Setting duration of previous rest for note $noteNumber $lastNoteOrRest', midiNumber: noteNumber);
            }

            notesAndRestsList.add(Note(currentOffsetInTicks));
          }
        } else if (event is NoteOffEvent) {
          int noteNumber = event.noteNumber;
          Log.v(LogTag.MIDI, 'Stopping note $noteNumber at $currentOffsetInTicks', midiNumber: noteNumber);

          var notesAndRestsList = _restsAndNotesByMidiNumber[noteNumber];
          if (notesAndRestsList != null) {
            Note lastNoteOrRest = notesAndRestsList.last;
            var noteDuration = currentOffsetInTicks - lastNoteOrRest.absoluteStartOffsetInTicks;
            lastNoteOrRest.durationInTicks = noteDuration;
            Log.v(LogTag.MIDI, 'Setting duration of previous note for note $noteNumber $lastNoteOrRest', midiNumber: noteNumber);

            if (noteDuration > 0) {
              notesDurations.add(noteDuration);
            }
            notesAndRestsList.add(Rest(currentOffsetInTicks));
          }
        }
      }

      _overallDurationInTicks =
          max(currentOffsetInTicks, _overallDurationInTicks);
    }

    _averageNoteDuration = notesDurations.reduce((a, b) => a + b)/notesDurations.length;
    _midiNumberRange = range;

    Log.v(
        LogTag.MIDI,
        'MIDI parsing done, range=$_midiNumberRange, '
        'duration=$_overallDurationInTicks, '
        '_averageNoteDuration=$_averageNoteDuration');
  }

  void play(String asset) async {
    FlutterMidi.unmute(); // Optionally Unmute
    ByteData _byte = await rootBundle.load(asset);
    FlutterMidi.prepare(sf2: _byte);
    //FlutterMidi.playMidiNote(midi: 60);
  }

  @override
  Widget build(BuildContext context) {
    var overallExpectedHeight = 100*_overallDurationInTicks/_averageNoteDuration;
    Log.v(LogTag.MIDI, 'OVERALL HEIGHT = $overallExpectedHeight');
    return Scaffold(
      resizeToAvoidBottomPadding: false,
      body: CustomScrollView(
        slivers: <Widget>[
          SliverHeader(title: 'Playing file ${widget.audioFile.path}'),
          SliverToBoxAdapter(
              child: Container(
            height: overallExpectedHeight,
            color: Colors.yellow[50],
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _midiNumberRange['max'] - _midiNumberRange['min'],
              itemBuilder: (BuildContext context, int index) {
                return getMidiNumberColumn(_midiNumberRange['min'] + index);
              },
              separatorBuilder: (BuildContext context, int index) {
                return Container(width: 3);
              },
            ),
          ))
        ],
      ),
    );
  }

  Widget getMidiNumberColumn(int midiNumber) {
    final List<Note> columnRestsAndNotes =
        _restsAndNotesByMidiNumber[midiNumber];
    List<Widget> columnNotes;

    if (columnRestsAndNotes != null) {
      columnNotes = columnRestsAndNotes.map<Widget>((noteOrRest) {
        return getNote(midiNumber, noteOrRest);
      }).toList();
    } else {
      columnNotes = <Widget>[
        getNote(midiNumber, Rest(0)..durationInTicks = 100*_overallDurationInTicks/_averageNoteDuration)
      ];
    }

    return Column(
      children: columnNotes,
    );
  }

  static double totalHeight = 0;

  Widget getNote(int midiNumber, Note noteOrRest) {
    Color color = noteOrRest is Rest ? Colors.transparent : Colors.red;
    double duration = noteOrRest.durationInTicks ?? 100;
    var height = 100*duration/_averageNoteDuration;

    if (midiNumber == 64) {
      totalHeight += height;
    }

    Log.v(LogTag.MIDI, 'Setting height $midiNumber $duration $_averageNoteDuration -> $height, $totalHeight');
    return Container(
        color: color,
        height: height > 0 ? height : 10,
        width: 20,
        child: Text(midiNumber.toString()));
  }
}
