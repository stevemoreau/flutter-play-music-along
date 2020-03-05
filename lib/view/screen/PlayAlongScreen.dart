import 'dart:io';
import 'dart:math';

import 'package:dart_midi/dart_midi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_midi/flutter_midi.dart';
import 'package:play_music_along/model/AudioFile.dart';
import 'package:play_music_along/utils/Log.dart';
import 'package:play_music_along/view/widget/PianoVisualizer.dart';
import 'package:play_music_along/view/widget/SliverHeader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import "package:intl/intl.dart";
import 'package:tonic/tonic.dart';

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

  double get tickDurationInMicroSeconds => microSecondsPerBeat / ticksPerBeat;
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
  Measure _currentMeasureInfo = Measure();
  double _tempoFactor = 0.2;

  ScrollController _scrollController = ScrollController();
  bool scroll = false;
  int speedFactor = 50;

  @override
  void initState() {
    super.initState();
    loadSoundBank('assets/sf2/UprightPianoKW-20190703.sf2');

    if (widget.audioFile.path == null) {
      importMidAssetFile().then((midiFileExample) {
        widget.audioFile.path = midiFileExample;
        loadMidi(File(widget.audioFile.path)).then((value) => setState(() {}));
        FlutterMidi.loadMidiFile(path: widget.audioFile.path);
      });
    } else {
      loadMidi(File(widget.audioFile.path)).then((value) => setState(() {}));
    }
  }

  double getViewDimension({double durationInTicks}) =>
      100 * durationInTicks / _averageNoteDuration;

  double getTicks({double viewDimension}) =>
      viewDimension * _averageNoteDuration / 100;

  String getHumanReadableDuration({int durationInMicroSeconds}) {
    final date = DateTime.fromMicrosecondsSinceEpoch(durationInMicroSeconds);
    final humanReadableFormat = DateFormat("m''''s\"");
    return '${durationInMicroSeconds}us (${humanReadableFormat.format(date)}.${date.millisecond}${date.microsecond})';
  }

  double get overallHeight =>
      getViewDimension(durationInTicks: _overallDurationInTicks);

  _scroll() {
    double remainingExtend = _scrollController.offset;
    int scrollDuration = (getTicks(viewDimension: remainingExtend) *
            _currentMeasureInfo.tickDurationInMicroSeconds /
            _tempoFactor)
        .round();

    Log.v(LogTag.MIDI,
        'Scrolling to origin extend=$remainingExtend in ${getHumanReadableDuration(durationInMicroSeconds: scrollDuration)}');
    _scrollController
        .animateTo(0,
            duration: Duration(microseconds: scrollDuration),
            curve: Curves.linear)
        .then((value) {
      // FIXME: loop or stop
    });
  }

  _goToStart() {
    var maxExtend = _scrollController.position.maxScrollExtent;
    Log.v(LogTag.MIDI,
        'Scrolling to song start (full bottom, ie position = $maxExtend');
    _scrollController.jumpTo(maxExtend);
  }

  _goToEnd() {
    _scrollController.jumpTo(0);
  }

  Future play() {
    Log.v(LogTag.MIDI, 'Start playing');
    _goToStart();
    _scroll();

    final midiFile = widget.audioFile.path;
    Log.v(LogTag.MIDI, 'Playing MIDI file $midiFile');
    return FlutterMidi.playCurrentMidiFile(tempoFactor: _tempoFactor);
  }

  _toggleScrolling() {
    setState(() {
      scroll = !scroll;
    });

    Log.v(LogTag.MIDI, '--------------- SCROLLING');

    //if (_scrollController.hasClients) {
    if (scroll) {
      _scroll();
    } else {
      _scrollController.animateTo(_scrollController.offset,
          duration: Duration(seconds: 1), curve: Curves.linear);
    }
    //}
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

  Future<String> importMidAssetFile() async {
    Directory directory = await getApplicationDocumentsDirectory();
    var file = join(directory.path, "file.mid");

    // copy file from Assets folder to Documents folder (only if not already there...)
    if (FileSystemEntity.typeSync(file) == FileSystemEntityType.notFound) {
      ByteData data = await rootBundle.load("assets/midi/test.mid");
      writeToFile(data, file);
    }

    return file;
  }

  void writeToFile(ByteData data, String path) {
    final buffer = data.buffer;
    return new File(path).writeAsBytesSync(
        buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  }

  Future loadMidi(File midiFile) {
    return Future.sync(() {
      Log.v(LogTag.MIDI, 'Parsing MIDI file ${midiFile.path}');
      var parser = MidiParser();
      MidiFile parsedMidi = parser.parseMidiFromFile(midiFile);
      var tracksCount = parsedMidi.tracks.length;
      Log.v(LogTag.MIDI, 'Processing $tracksCount tracks');

      _currentMeasureInfo.ticksPerBeat = parsedMidi.header.ticksPerBeat;

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
            _currentMeasureInfo.microSecondsPerBeat = event.microsecondsPerBeat;
          } else if (event is TimeSignatureEvent) {
            Log.v(LogTag.MIDI, 'Event TimeSignatureEvent');
            _currentMeasureInfo.timeSignatureNumerator = event.numerator;
            _currentMeasureInfo.timeSignatureDenominator = event.denominator;
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

            var notesAndRestsList = _restsAndNotesByMidiNumber[noteNumber];
            if (notesAndRestsList == null) {
              notesAndRestsList = <Note>[].toList();
              _restsAndNotesByMidiNumber[noteNumber] = notesAndRestsList;
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

              notesAndRestsList.add(Note(currentOffsetInTicks));
            }
          } else if (event is NoteOffEvent) {
            int noteNumber = event.noteNumber;
            Log.v(LogTag.MIDI,
                'Stopping note $noteNumber at $currentOffsetInTicks',
                midiNumber: noteNumber);

            var notesAndRestsList = _restsAndNotesByMidiNumber[noteNumber];
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

            _overallDurationInTicks =
                max(currentOffsetInTicks, _overallDurationInTicks);
          }
        }
      }

      _averageNoteDuration =
          notesDurations.reduce((a, b) => a + b) / notesDurations.length;
      _midiNumberRange = range;

      Log.v(
          LogTag.MIDI,
          'MIDI parsing done, range=$_midiNumberRange, '
          'duration=$_overallDurationInTicks, '
          '_averageNoteDuration=$_averageNoteDuration');
    });
  }

  loadSoundBank(String soundBank) async {
    FlutterMidi.unmute(); // Optionally Unmute
    ByteData _byte = await rootBundle.load(soundBank);
    //FlutterMidi.prepare(sf2: _byte);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (overallHeight > 0) {
        Log.v(LogTag.MIDI, 'Build done, playing file');
        //play();
      }
    });

    Log.v(LogTag.MIDI, 'Entering build(), OVERALL HEIGHT = $overallHeight');
    return Scaffold(
      resizeToAvoidBottomPadding: false,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: <Widget>[
          SliverHeader(title: 'Playing file ${widget.audioFile.path}'),
          SliverToBoxAdapter(
              child: Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).size.height),
            height: overallHeight,
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
      bottomNavigationBar: Container(
        height: 120,
        child: PianoVisualizer(keyWidth: 20),
      ),
    );
  }

  Widget getMidiNumberColumn(int midiNumber) {
    final List<Note> columnRestsAndNotes =
        _restsAndNotesByMidiNumber[midiNumber];
    List<Widget> columnNotes;

    if (columnRestsAndNotes != null) {
      columnNotes = columnRestsAndNotes.map<Widget>((noteOrRest) {
        return noteOrRest is Rest ? null : _getNote(midiNumber, noteOrRest);
      }).where((element) => element != null).toList();
      //columnNotes.clear();
    } else {
      columnNotes = <Widget>[
        _getNote(
            midiNumber,
            Rest(0)
              ..durationInTicks =
                  100 * _overallDurationInTicks / _averageNoteDuration)
      ];
    }
    final pitch = Pitch.fromMidiNumber(midiNumber);

    return SizedBox(
      height: overallHeight,
      width: _getNoteWidth(pitch),
      child: Stack(
        children: columnNotes,
      ),
    );
  }

  Color _getNoteColor(int midiNumber) {
    final Map colors = {
      'C': Colors.red,
      'D': Colors.yellow,
      'E': Colors.deepPurple,
      'F': Colors.blueAccent,
      'G': Colors.teal,
      'A': Colors.green,
      'B': Colors.orange,
    };
    String noteNameWithoutAccidental = Pitch.fromMidiNumber(midiNumber).letterName[0];
    return colors[noteNameWithoutAccidental];
  }

  double _getNoteWidth(Pitch pitch) {
    double width = 24;
    if (pitch.accidentalSemitones > 0) {
      width = 10;
    } else if (pitch.midiNumber % 12 == 2 || pitch.midiNumber % 12 == 7 || pitch.midiNumber % 12 == 9) {
      width = 15;
    }
    return width;
  }

  Widget _getNote(int midiNumber, Note noteOrRest) {
    Color color =
        noteOrRest is Rest ? Colors.transparent : _getNoteColor(midiNumber);
    double duration = noteOrRest.durationInTicks ?? 100;
    var height = getViewDimension(durationInTicks: duration);
    final pitch = Pitch.fromMidiNumber(midiNumber);
    BorderRadiusGeometry borderRadius = const BorderRadius.all(Radius.circular(2.0));

    return Positioned(
      bottom: getViewDimension(
          durationInTicks: noteOrRest.absoluteStartOffsetInTicks),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: Container(
            height: height,
            padding: EdgeInsets.only(bottom: 5),
            color: color,
            width: _getNoteWidth(pitch),
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
