import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:play_music_along/model/AudioFile.dart';
import 'package:play_music_along/utils/Log.dart';
import 'package:play_music_along/utils/Midi.dart';

class PlaybackSelection {
  Note startNote;
  Note endNote;
}

class PlaybackNotifier extends ChangeNotifier {
  BuildContext context;
  AudioFile audioFile;
  Note selectedNote;
  PlaybackSelection selection = PlaybackSelection();

  PlaybackNotifier(this.context);

  setAudioFile(AudioFile audioFile) {
    this.audioFile = audioFile;
    //notifyListeners();
  }

  readyToPlay() {
    audioFile.readyToPlay = true;
    notifyListeners();
  }

  startPlaying() {
    audioFile.playing = true;
    //notifyListeners();
  }

  setSelectedNote(Note note) {
    selectedNote = note;
    notifyListeners();
  }

  setSelectionStart() {
    Log.v(LogTag.AUDIO_CONTROLS, 'Setting selection start @${selectedNote.absoluteStartOffsetInTicks}');
    selection.startNote = selectedNote;
    notifyListeners();
  }

  setSelectionEnd() {
    Log.v(LogTag.AUDIO_CONTROLS, 'Setting selection end @${selectedNote.absoluteStartOffsetInTicks}');
    selection.endNote = selectedNote;
    notifyListeners();
  }

  stopPlaying() {
    audioFile.playing = false;
    notifyListeners();
  }
}