import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_midi/flutter_midi.dart';
import "package:intl/intl.dart";
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:play_music_along/model/AudioFile.dart';
import 'package:play_music_along/utils/Log.dart';
import 'package:play_music_along/utils/Midi.dart';
import 'package:play_music_along/view/widget/SliverHeader.dart';
import 'package:play_music_along/view/widget/TearingNote.dart';
import 'package:play_music_along/view/widget/visualizer/PianoVisualizer.dart';
import 'package:tonic/tonic.dart';

class PlayAlongScreen extends StatefulWidget {
  final AudioFile audioFile;

  const PlayAlongScreen({Key key, this.audioFile}) : super(key: key);

  @override
  _PlayAlongScreenState createState() => _PlayAlongScreenState();
}

// FIXME smoreau: add Track with instrument + min/max midi number + notes

class _PlayAlongScreenState extends State<PlayAlongScreen> {
  double _tempoFactor = 0.2;
  MidiFileInfo _midiFileInfo = MidiFileInfo();
  ScrollController _scrollController = ScrollController();
  bool scroll = false;
  int speedFactor = 50;

  @override
  void initState() {
    super.initState();
    Midi.loadSoundBank('assets/sf2/UprightPianoKW-20190703.sf2');

    if (widget.audioFile.path == null) {
      importMidAssetFile().then((midiFileExample) {
        widget.audioFile.path = midiFileExample;
        Midi.loadMidi(File(widget.audioFile.path)).then((MidiFileInfo midiFileInfo) => setState(() {
          _midiFileInfo = midiFileInfo;
        }));
        FlutterMidi.loadMidiFile(path: widget.audioFile.path);
      });
    } else {
      Midi.loadMidi(File(widget.audioFile.path)).then((value) => setState(() {}));
    }
  }



  String getHumanReadableDuration({int durationInMicroSeconds}) {
    final date = DateTime.fromMicrosecondsSinceEpoch(durationInMicroSeconds);
    final humanReadableFormat = DateFormat("m''''s\"");
    return '${durationInMicroSeconds}us (${humanReadableFormat.format(date)}.${date.millisecond}${date.microsecond})';
  }

  _scroll() {
    double remainingExtend = _scrollController.offset;
    int scrollDuration = (_midiFileInfo.getTicks(viewDimension: remainingExtend) *
            _midiFileInfo.measure.tickDurationInMicroSeconds /
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

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_midiFileInfo.overallHeight > 0) {
        Log.v(LogTag.MIDI, 'Build done, playing file');
        _goToStart();
        play();
      }
    });

    Log.v(LogTag.MIDI, 'Entering build(), OVERALL HEIGHT = ${_midiFileInfo.overallHeight}');
    return Scaffold(
      resizeToAvoidBottomPadding: false,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: <Widget>[
          SliverHeader(title: 'Playing file ${widget.audioFile.path}'),
          SliverToBoxAdapter(
              child: Container(
            padding: EdgeInsets.only(top: MediaQuery.of(context).size.height),
            height: _midiFileInfo.overallHeight,
            color: Colors.yellow[50],
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _midiFileInfo.midiNumberRange['max'] - _midiFileInfo.midiNumberRange['min'],
              itemBuilder: (BuildContext context, int index) {
                return getMidiNumberColumn(_midiFileInfo.midiNumberRange['min'] + index);
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
        _midiFileInfo.restsAndNotesByMidiNumber[midiNumber];
    List<Widget> columnNotes;

    if (columnRestsAndNotes != null) {
      columnNotes = columnRestsAndNotes.map<Widget>((noteOrRest) {
        return noteOrRest is Rest ? null : _getNote(noteOrRest);
      }).where((element) => element != null).toList();
      //columnNotes.clear();
    } else {
      columnNotes = <Widget>[
        _getNote(
            Rest(0, midiNumber: midiNumber)
              ..durationInTicks =
                  100 * _midiFileInfo.overallDurationInTicks / _midiFileInfo.averageNoteDuration)
      ];
    }
    final pitch = Pitch.fromMidiNumber(midiNumber);

    return SizedBox(
      height: _midiFileInfo.overallHeight,
      width: _getNoteWidth(pitch),
      child: Stack(
        children: columnNotes,
      ),
    );
  }

  double _getNoteWidth(Pitch pitch) {
    double width = 24;
    bool isBlackKey = pitch.accidentalSemitones > 0;
    bool isWhiteKeyBetweenTwoBlackKeys = ['D', 'G', 'A'].contains(MidiPitch(midiNumber: pitch.midiNumber).pitchBaseName);
    if (isBlackKey) {
      width = width*1/4;
    } else if (isWhiteKeyBetweenTwoBlackKeys) {
      width = width*3/4;
    } else {
      width = width*(3/4 + 1/8);
    }
    return width;
  }

  Widget _getNote(Note noteOrRest) {
    return TearingNote(
      width: _getNoteWidth(noteOrRest.pitch),
      note: noteOrRest,
      midiFileInfo: _midiFileInfo,
    );
  }
}
