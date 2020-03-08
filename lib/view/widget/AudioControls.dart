import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_midi/flutter_midi.dart';
import "package:intl/intl.dart";
import 'package:path/path.dart';
import 'package:play_music_along/notifier/PlaybackNotifier.dart';
import 'package:play_music_along/utils/Log.dart';
import 'package:play_music_along/utils/Midi.dart';
import 'package:play_music_along/values/colors.dart';
import 'package:play_music_along/values/dimens.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class AudioControls extends StatefulWidget {
  final String title;
  final ScrollController scrollController;
  final PanelController panelController;
  final MidiFileInfo midiFileInfo;

  const AudioControls({
    Key key,
    this.title,
    this.scrollController,
    this.midiFileInfo,
    this.panelController,
  }) : super(key: key);

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
          return Container(
            color: MyColors.bluegreen800,
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                    playbackNotifier.audioFile != null
                        ? 'Playing ${basename(playbackNotifier.audioFile.path)}'
                        : 'Loading...',
                    style: TextStyle(
                      fontFamily: 'Bold',
                      color: Colors.white,
                      fontSize: 16.0,
                    )),
                Text(getPlaybackInfo(playbackNotifier.selection),
                    style: TextStyle(
                      fontFamily: 'Regular',
                      color: Colors.white,
                      fontSize: 10.0,
                    )),
                Row(
                  children: <Widget>[
                    IconButton(
                        padding: EdgeInsets.all(2),
                        onPressed: () => _playOrPause(playbackNotifier.selection),
                        icon: Icon(
                          _playing ? Icons.pause_circle_outline : Icons
                              .play_arrow,
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
                          'Stop playing and reset current to selection start',
                        )),
                    IconButton(
                        padding: EdgeInsets.all(2),
                        onPressed: () => _tempo(5),
                        icon: Icon(
                          Icons.add,
                          color: Colors.white,
                          semanticLabel: 'Increase tempo',
                        )),
                    IconButton(
                        padding: EdgeInsets.all(2),
                        onPressed: () => _tempo(-5),
                        icon: Icon(
                          Icons.remove,
                          color: Colors.white,
                          semanticLabel: 'Decrease tempo',
                        )),
                    Visibility(
                      visible: playbackNotifier.selectedNote != null,
                      child: IconButton(
                          padding: EdgeInsets.all(2),
                          onPressed: _setSelectionStart,
                          icon: Icon(
                            Icons.pin_drop,
                            color: Colors.white,
                            semanticLabel: 'Set selection start',
                          )),
                    ),
                    Visibility(
                      visible: playbackNotifier.selectedNote != null &&
                          playbackNotifier.selection.startNote != null,
                      child: Transform.rotate(
                        angle: pi,
                        child: IconButton(
                            padding: EdgeInsets.all(2),
                            onPressed: _setSelectionEnd,
                            icon: Icon(
                              Icons.pin_drop,
                              color: Colors.white,
                              semanticLabel: 'Set selection start',
                            )),
                      ),
                    ),
                  ],
                )
              ],
            ),
          );
        });
  }

  String getPlaybackInfo(PlaybackSelection selection) {
    String info = 'Tempo: ${(_tempoFactor * 100).round()}%';

    if (selection.startNote != null) {
      info += ', Selection: ' + _getHumanReadableDuration(
          durationInMicroSeconds: _getDurationInMicroSecondsForCurrentTempo(
              selection.startNote.absoluteTickStart));
    }
    if (selection.endNote != null) {
      info += ' → ' + _getHumanReadableDuration(
          durationInMicroSeconds: _getDurationInMicroSecondsForCurrentTempo(
              selection.endNote.absoluteTickEnd));
    }

    return info;
  }

  _setSelectionStart() {
    Provider.of<PlaybackNotifier>(this.context).setSelectionStart();
  }

  _setSelectionEnd() {
    Provider.of<PlaybackNotifier>(this.context).setSelectionEnd();
  }

  _playOrPause(PlaybackSelection selection) {
    setState(() {
      _playing = !_playing;
    });

    if (_playing) {
      Log.i(LogTag.AUDIO_CONTROLS, '[PLAY] Starting playback');
      _play(selection);
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

//  _toggleScrolling() {
//    setState(() {
//      _scroll = !_scroll;
//    });
//
//    Log.v(LogTag.MIDI, '--------------- SCROLLING');
//
//    //if (widget.scrollController.hasClients) {
//    if (_scroll) {
//      _startScrolling();
//    } else {
//      widget.scrollController.animateTo(widget.scrollController.offset,
//          duration: Duration(seconds: 1), curve: Curves.linear);
//    }
//    //}
//  }

  String _getHumanReadableDuration({int durationInMicroSeconds}) {
    final date = DateTime.fromMicrosecondsSinceEpoch(durationInMicroSeconds);
    final humanReadableFormat = DateFormat("m''''s\"");
    return '${humanReadableFormat.format(
        date)}.${date.millisecond}${date.microsecond}';
  }

  double get getPositionInTicks =>
      widget.midiFileInfo.getTicks(
          viewDimension: widget.scrollController.position.maxScrollExtent -
              widget.scrollController.offset);

  _getDurationInMicroSecondsForCurrentTempo(durationInTicks) =>
      (durationInTicks *
          widget.midiFileInfo.measure.tickDurationInMicroSeconds / _tempoFactor)
          .round();

  _startScrolling(startOffset) {
    double remainingExtend = widget.scrollController.position.maxScrollExtent - startOffset;
    widget.scrollController.jumpTo(remainingExtend);
    int scrollDuration =
    _getDurationInMicroSecondsForCurrentTempo(
        widget.midiFileInfo.getTicks(viewDimension: remainingExtend));

    Log.v(LogTag.MIDI,
        'Scrolling to origin extend=$remainingExtend in ${scrollDuration}us (${_getHumanReadableDuration(
            durationInMicroSeconds: scrollDuration)})');
    widget.scrollController
        .animateTo(0,
        duration: Duration(microseconds: scrollDuration),
        curve: Curves.linear)
        .then((value) {
      // FIXME: loop or stop
    });
  }

  Future _play(PlaybackSelection selection) {
    Log.i(LogTag.MIDI, 'Start playing');
    widget.panelController.animatePanelToPosition(0);
    double startTickPosition = selection.startNote != null ? selection.startNote.absoluteTickStart : getPositionInTicks;
    _startScrolling(widget.midiFileInfo.getViewDimension(durationInTicks: startTickPosition));
    Provider.of<PlaybackNotifier>(this.context).startPlaying();
    return FlutterMidi.playCurrentMidiFile(
        initialTickPosition: startTickPosition,
        endTickPosition: selection.endNote != null ? selection.endNote.absoluteTickEnd : -1,
        tempoFactor: _tempoFactor);
  }

  _tempo(int offsetPercentage) {
    setState(() {
      _tempoFactor += offsetPercentage / 100;
    });
  }

  Future _pause() {
    setState(() {
      _playing = false;
    });

    Provider.of<PlaybackNotifier>(this.context).stopPlaying();

    // FIXME smoreau: right way to cancel the scroll ? cancel the promise ?
    widget.scrollController.jumpTo(widget.scrollController.offset);

    return FlutterMidi.stopCurrentMidiFile();
  }

  Future _stop() {
    Log.i(LogTag.AUDIO_CONTROLS, '[STOP]');

    _scrollToStart();
    return _pause();
  }
}
