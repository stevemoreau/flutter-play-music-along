import 'dart:io';
import 'dart:math';

import 'package:dart_midi/dart_midi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_midi/flutter_midi.dart';
import 'package:tonic/tonic.dart';

import 'Log.dart';

enum Instrument { PIANO }

class Measure {
  int ticksPerBeat = 0;

  int timeSignatureNumerator = 4;
  int timeSignatureDenominator = 4;
  int microSecondsPerBeat = 0;

  double get tickDurationInMicroSeconds => microSecondsPerBeat / ticksPerBeat;
}

class Note {
  double absoluteStartOffsetInTicks;
  double durationInTicks;
  String type = 'NOTE';
  int midiNumber;

  Note(this.absoluteStartOffsetInTicks,
      {this.durationInTicks, this.midiNumber});

  Pitch get pitch => Pitch.fromMidiNumber(midiNumber);

  @override
  String toString() {
    return '$type[duration=$durationInTicks, start=$absoluteStartOffsetInTicks]';
  }
}

class Rest extends Note {
  Rest(double absoluteStartOffsetInTicks, {int midiNumber})
      : super(absoluteStartOffsetInTicks, midiNumber: midiNumber) {
    type = 'REST';
  }
}

class MidiFileInfo {
  Measure measure = Measure();
  var restsAndNotesByMidiNumber = {};
  var midiNumberRange = {'min': 0, 'max': 127};
  double overallDurationInTicks = 0;
  double averageNoteDuration = 200;

  double getViewDimension({double durationInTicks}) =>
      100 * durationInTicks / averageNoteDuration;

  double getTicks({double viewDimension}) =>
      viewDimension * averageNoteDuration / 100;

  double get overallHeight =>
      getViewDimension(durationInTicks: overallDurationInTicks);
}

class Midi {
  static final Midi _instance = Midi._privateConstructor();

  Midi._privateConstructor();

  factory Midi() {
    return _instance;
  }

  static Instrument _getInstrument(InstrumentNameEvent event) {
    Instrument instrument;
    String instrumentName = event.text;
    if ('Piano' == instrumentName) {
      instrument = Instrument.PIANO;
    } else {
      Log.e(LogTag.MIDI,
          'Instrument $instrumentName not supported at the moment');
    }
    return instrument;
  }

  static Future<MidiFileInfo> loadMidi(File midiFile) {
    return Future.sync(() {
      MidiFileInfo midiFileInfo = MidiFileInfo();
      Log.v(LogTag.MIDI, 'Parsing MIDI file ${midiFile.path}');
      var parser = MidiParser();
      MidiFile parsedMidi = parser.parseMidiFromFile(midiFile);
      var tracksCount = parsedMidi.tracks.length;
      Log.v(LogTag.MIDI, 'Processing $tracksCount tracks');

      midiFileInfo.measure.ticksPerBeat = parsedMidi.header.ticksPerBeat;

      var range = {'min': 127, 'max': 0};
      List<double> notesDurations = [];

      for (var track in parsedMidi.tracks) {
        Instrument instrument;
        double currentOffsetInTicks = 0;
        for (var event in track) {
          currentOffsetInTicks += event.deltaTime;
          if (event is SetTempoEvent) {
            Log.v(LogTag.MIDI, 'Event SetTempoEvent');
            midiFileInfo.measure.microSecondsPerBeat =
                event.microsecondsPerBeat;
          } else if (event is TimeSignatureEvent) {
            Log.v(LogTag.MIDI, 'Event TimeSignatureEvent');
            midiFileInfo.measure.timeSignatureNumerator = event.numerator;
            midiFileInfo.measure.timeSignatureDenominator = event.denominator;
          } else if (event is ProgramChangeMidiEvent) {
            Log.v(LogTag.MIDI, 'Event ProgramChangeMidiEvent');
          } else if (event is InstrumentNameEvent) {
            instrument = _getInstrument(event);
            Log.v(
                LogTag.MIDI, 'Event InstrumentNameEvent: $instrument detected');
          } else if (event is NoteOnEvent) {
            int noteNumber = event.noteNumber;

            Log.v(LogTag.MIDI,
                'Starting note $noteNumber at $currentOffsetInTicks',
                midiNumber: noteNumber);

            range['min'] = min(noteNumber, range['min']);
            range['max'] = max(noteNumber, range['max']);

            var notesAndRestsList =
                midiFileInfo.restsAndNotesByMidiNumber[noteNumber];
            if (notesAndRestsList == null) {
              notesAndRestsList = <Note>[].toList();
              midiFileInfo.restsAndNotesByMidiNumber[noteNumber] =
                  notesAndRestsList;
              if (currentOffsetInTicks > 0) {
                Log.v(LogTag.MIDI, 'Initial rest for note $noteNumber',
                    midiNumber: noteNumber);
                notesAndRestsList
                    .add(Rest(0)..durationInTicks = currentOffsetInTicks);
              }
            }

            if (notesAndRestsList != null) {
              if (notesAndRestsList.length > 0) {
                Note lastNoteOrRest = notesAndRestsList.last;
                lastNoteOrRest.durationInTicks = currentOffsetInTicks -
                    lastNoteOrRest.absoluteStartOffsetInTicks;
                Log.v(LogTag.MIDI,
                    'Setting duration of previous rest for note $noteNumber $lastNoteOrRest',
                    midiNumber: noteNumber);
              }

              notesAndRestsList
                  .add(Note(currentOffsetInTicks, midiNumber: noteNumber));
            }
          } else if (event is NoteOffEvent) {
            int noteNumber = event.noteNumber;
            Log.v(LogTag.MIDI,
                'Stopping note $noteNumber at $currentOffsetInTicks',
                midiNumber: noteNumber);

            var notesAndRestsList =
                midiFileInfo.restsAndNotesByMidiNumber[noteNumber];
            if (notesAndRestsList != null) {
              Note lastNoteOrRest = notesAndRestsList.last;
              var noteDuration = currentOffsetInTicks -
                  lastNoteOrRest.absoluteStartOffsetInTicks;
              lastNoteOrRest.durationInTicks = noteDuration;
              Log.v(LogTag.MIDI,
                  'Setting duration of previous note for note $noteNumber $lastNoteOrRest',
                  midiNumber: noteNumber);

              if (noteDuration > 0) {
                notesDurations.add(noteDuration);
              }
              notesAndRestsList.add(Rest(currentOffsetInTicks));
            }

            midiFileInfo.overallDurationInTicks =
                max(currentOffsetInTicks, midiFileInfo.overallDurationInTicks);
          }
        }
      }

      midiFileInfo.averageNoteDuration =
          notesDurations.reduce((a, b) => a + b) / notesDurations.length;
      midiFileInfo.midiNumberRange = range;

      Log.v(
          LogTag.MIDI,
          'MIDI parsing done, range=${midiFileInfo.midiNumberRange}, '
          'duration=${midiFileInfo.overallDurationInTicks}, '
          'midiFileInfo.averageNoteDuration=${midiFileInfo.averageNoteDuration}');

      return midiFileInfo;
    });
  }

  static loadSoundBank(String soundBank) async {
    FlutterMidi.unmute(); // Optionally Unmute
    ByteData _byte = await rootBundle.load(soundBank);
    //FlutterMidi.prepare(sf2: _byte);
  }
}

class MidiPitch {
  final int midiNumber;
  Pitch pitch;

  MidiPitch(this.midiNumber) {
    this.pitch = Pitch.fromMidiNumber(midiNumber);
  }

  /// Note name without accidental (among 7 main notes A..G)
  String get pitchBaseName => pitch.letterName[0];

  Color get pitchColor {
    final Map colors = {
      'C': Colors.red,
      'D': Colors.yellow,
      'E': Colors.deepPurple,
      'F': Colors.blueAccent,
      'G': Colors.pinkAccent,
      'A': Colors.green,
      'B': Colors.orange,
    };
    return colors[pitchBaseName];
  }
}
