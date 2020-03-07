import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_midi/flutter_midi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:play_music_along/model/AudioFile.dart';
import 'package:play_music_along/notifier/PlaybackNotifier.dart';
import 'package:play_music_along/utils/Log.dart';
import 'package:play_music_along/utils/Midi.dart';
import 'package:play_music_along/values/dimens.dart';
import 'package:play_music_along/view/widget/AudioControls.dart';
import 'package:play_music_along/view/widget/TearingNote.dart';
import 'package:play_music_along/view/widget/visualizer/PianoVisualizer.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:tonic/tonic.dart';
import 'package:provider/provider.dart';

class PlayAlongScreen extends StatefulWidget {
  final AudioFile audioFile;

  const PlayAlongScreen({Key key, this.audioFile}) : super(key: key);

  @override
  _PlayAlongScreenState createState() => _PlayAlongScreenState();
}

// FIXME smoreau: add Track with instrument + min/max midi number + notes

class _PlayAlongScreenState extends State<PlayAlongScreen> {
  MidiFileInfo _midiFileInfo = MidiFileInfo();
  ScrollController _verticalScrollController = ScrollController();
  ScrollController _tearingNotesHorizontalScrollController = ScrollController();
  ScrollController _visualizerHorizontalScrollController = ScrollController();
  PanelController _panelController = new PanelController();

  @override
  void initState() {
    super.initState();

    Future.wait([
      widget.audioFile.path != null
          ? Future.value(widget.audioFile.path)
          : importMidAssetFile("assets/midi/demo.mid", "input.mid"),
      importMidAssetFile(
          "assets/sf2/UprightPianoKW-20190703.sf2", "soundbank.sf2")
    ]).then((values) {
      widget.audioFile.path = values[0];
      Midi.parseMidiForTearingNotes(File(widget.audioFile.path))
          .then((MidiFileInfo midiFileInfo) => setState(() {
                _midiFileInfo = midiFileInfo;
              }));
      FlutterMidi.loadMidiFile(
          midiFilePath: widget.audioFile.path, soundBankFilePath: values[1]);
    });
  }

  Future<String> importMidAssetFile(
      String assetRelativeFilePath, String applicationDocumentsFileName) async {
    Directory directory = await getApplicationDocumentsDirectory();
    var file = join(directory.path, applicationDocumentsFileName);

    // copy file from Assets folder to Documents folder (only if not already there...)
    if (FileSystemEntity.typeSync(file) == FileSystemEntityType.notFound) {
      ByteData data = await rootBundle.load(assetRelativeFilePath);
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
    Provider.of<PlaybackNotifier>(this.context).setAudioFile(widget.audioFile);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_midiFileInfo.overallHeight > 0) {
        Log.v(LogTag.MIDI, 'Build done, ready to play file');
        // Provider.of<PlaybackNotifier>(context, listen: false).readyToPlay();
        var maxExtend = _verticalScrollController.position.maxScrollExtent;
        _verticalScrollController.jumpTo(maxExtend);
      }
    });

    Log.v(LogTag.MIDI,
        'Entering build(), OVERALL HEIGHT = ${_midiFileInfo.overallHeight}');
    return SafeArea(
      child: Scaffold(
        //resizeToAvoidBottomPadding: false,
        body: SlidingUpPanel(
          defaultPanelState: PanelState.OPEN,
          slideDirection: SlideDirection.DOWN,
          maxHeight: PANEL_OPENED,
          minHeight: PANEL_CLOSED,
          controller: _panelController,
          panel: AudioControls(
            title: 'Playing file ${widget.audioFile.path}',
            scrollController: _verticalScrollController,
            panelController: _panelController,
            midiFileInfo: _midiFileInfo,
          ),
          body: SingleChildScrollView(
            controller: _verticalScrollController,
            child: Container(
              // FIXME smoreau: regression, the bottom was correctly aligned above visualizer above, run bisect
              margin: EdgeInsets.only(bottom: VISUALIZER_HEIGHT + 30),
              padding: EdgeInsets.only(top: MediaQuery.of(context).size.height),
              height: _midiFileInfo.overallHeight,
              color: Colors.yellow[50],
              child: NotificationListener<UserScrollNotification>(
                onNotification: (UserScrollNotification notification) =>
                    _onHorizontalScrolling(notification),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  controller: _tearingNotesHorizontalScrollController,
                  itemCount: _midiFileInfo.midiNumberRange.count,
                  itemBuilder: (BuildContext context, int index) {
                    return getMidiNumberColumn(
                        _midiFileInfo.midiNumberRange.midiNumber(index));
                  },
                ),
              ),
            ),
          ),
        ),
        bottomNavigationBar: Container(
          height: VISUALIZER_HEIGHT,
          child: PianoVisualizer(
            keyWidth: 20,
            midiNumberRange: _midiFileInfo.midiNumberRange,
            scrollController: _visualizerHorizontalScrollController,
            onHorizontalScrolling: _onHorizontalScrolling,
          ),
        ),
      ),
    );
  }

  _onHorizontalScrolling(UserScrollNotification notification,
      {bool visualizerOrigin = false}) {
    (visualizerOrigin
            ? _tearingNotesHorizontalScrollController
            : _visualizerHorizontalScrollController)
        .jumpTo(notification.metrics.pixels);
    return false;
  }

  Widget getMidiNumberColumn(int midiNumber) {
    final List<Note> columnRestsAndNotes =
        _midiFileInfo.restsAndNotesByMidiNumber[midiNumber];
    List<Widget> columnNotes;

    if (columnRestsAndNotes != null) {
      columnNotes = columnRestsAndNotes
          .map<Widget>((noteOrRest) {
            return noteOrRest is Rest ? null : _getNote(noteOrRest);
          })
          .where((element) => element != null)
          .toList();
      //columnNotes.clear();
    } else {
      columnNotes = <Widget>[
        _getNote(Rest(0, midiNumber: midiNumber)
          ..durationInTicks = 100 *
              _midiFileInfo.overallDurationInTicks /
              _midiFileInfo.averageNoteDuration)
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
    bool isWhiteKeyBetweenTwoBlackKeys = ['D', 'G', 'A']
        .contains(MidiPitch(midiNumber: pitch.midiNumber).pitchBaseName);
    if (isBlackKey) {
      width = width * 1 / 4;
    } else if (isWhiteKeyBetweenTwoBlackKeys) {
      width = width * 3 / 4;
    } else {
      width = width * (3 / 4 + 1 / 8);
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
