import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:play_music_along/notifier/PlaybackNotifier.dart';
import 'package:play_music_along/utils/Log.dart';
import 'package:play_music_along/values/colors.dart';
import 'package:play_music_along/values/dimens.dart';
import "package:intl/intl.dart";
import 'package:play_music_along/utils/Midi.dart';
import 'package:flutter_midi/flutter_midi.dart';
import 'package:provider/provider.dart';

class AudioControls extends StatefulWidget {
  final String title;
  final ScrollController scrollController;
  final MidiFileInfo midiFileInfo;

  const AudioControls(
      {Key key, this.title, this.scrollController, this.midiFileInfo})
      : super(key: key);

  @override
  _AudioControlsState createState() => _AudioControlsState();
}

class _AudioControlsState extends State<AudioControls> {
  bool _playing = false;
  bool _scroll = false;
  double _tempoFactor = 0.2;

  @override
  Widget build(BuildContext context) {
    return Consumer<PlaybackNotifier>(
        builder: (context, playbackNotifier, child) {
      return SliverAppBar(
        expandedHeight: sliver_appbar_height,
        floating: true,
        backgroundColor: MyColors.bluegreen800,
        flexibleSpace: FlexibleSpaceBar(
          stretchModes: <StretchMode>[
            StretchMode.zoomBackground,
            StretchMode.blurBackground,
            StretchMode.fadeTitle,
          ],
          centerTitle: false,
          titlePadding: EdgeInsets.only(bottom: 10, left: 50),
          title: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Playing ${playbackNotifier.audioFile.path}',
                  style: TextStyle(
                    fontFamily: 'Bold',
                    color: Colors.white,
                    fontSize: 16.0,
                  )),
              Text('Tempo: 20%',
                  style: TextStyle(
                    fontFamily: 'Regular',
                    color: Colors.white,
                    fontSize: 10.0,
                  )),
              Row(
                children: <Widget>[
                  IconButton(
                      padding: EdgeInsets.all(2),
                      onPressed: _playOrPause,
                      icon: Icon(
                        _playing
                            ? Icons.pause_circle_outline
                            : Icons.play_arrow,
                        color: Colors.white,
                        semanticLabel: 'Play/pause song from selection start',
                      )),
                  IconButton(
                      padding: EdgeInsets.all(2),
                      onPressed: _stop,
                      icon: Icon(
                        Icons.stop,
                        color: Colors.white,
                        semanticLabel:
                            'Stop playing and reset current to slection start',
                      )),
                ],
              )
            ],
          ),
          background: Image.asset(
            "assets/images/background.png",
            fit: BoxFit.cover,
          ),
        ),
      );
    });
  }

  _playOrPause() {
    setState(() {
      _playing = !_playing;
    });

    if (_playing) {
      Log.i(LogTag.AUDIO_CONTROLS, '[PLAY] Starting playback');
      _play();
    } else {
      Log.i(LogTag.AUDIO_CONTROLS, '[PLAY] Pausing playback');
      _pause();
    }
  }

  _scrollToStart() {
    var maxExtend = widget.scrollController.position.maxScrollExtent;
    Log.v(LogTag.MIDI,
        'Scrolling to song start (full bottom, ie position = $maxExtend');
    widget.scrollController.jumpTo(maxExtend);
  }

  _scrollToEnd() {
    widget.scrollController.jumpTo(0);
  }

  _toggleScrolling() {
    setState(() {
      _scroll = !_scroll;
    });

    Log.v(LogTag.MIDI, '--------------- SCROLLING');

    //if (widget.scrollController.hasClients) {
    if (_scroll) {
      _startScrolling();
    } else {
      widget.scrollController.animateTo(widget.scrollController.offset,
          duration: Duration(seconds: 1), curve: Curves.linear);
    }
    //}
  }

  String getHumanReadableDuration({int durationInMicroSeconds}) {
    final date = DateTime.fromMicrosecondsSinceEpoch(durationInMicroSeconds);
    final humanReadableFormat = DateFormat("m''''s\"");
    return '${durationInMicroSeconds}us (${humanReadableFormat.format(date)}.${date.millisecond}${date.microsecond})';
  }

  _startScrolling() {
    double remainingExtend = widget.scrollController.offset;
    int scrollDuration =
        (widget.midiFileInfo.getTicks(viewDimension: remainingExtend) *
                widget.midiFileInfo.measure.tickDurationInMicroSeconds /
                _tempoFactor)
            .round();

    Log.v(LogTag.MIDI,
        'Scrolling to origin extend=$remainingExtend in ${getHumanReadableDuration(durationInMicroSeconds: scrollDuration)}');
    widget.scrollController
        .animateTo(0,
            duration: Duration(microseconds: scrollDuration),
            curve: Curves.linear)
        .then((value) {
      // FIXME: loop or stop
    });
  }

  Future _play() {
    Log.i(LogTag.MIDI, 'Start playing');
    _startScrolling();

    return FlutterMidi.playCurrentMidiFile(tempoFactor: _tempoFactor);
  }

  _pause() {
    setState(() {
      _playing = false;
    });

    // FIXME smoreau: right way to cancel the scroll ? cancel the promise ?
    widget.scrollController.jumpTo(widget.scrollController.offset);

    return FlutterMidi.stopCurrentMidiFile();
  }

  Future _stop() {
    Log.i(LogTag.AUDIO_CONTROLS, '[STOP]');

    _scrollToStart();
    _pause();
  }
}
