import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:play_music_along/model/AudioFile.dart';

class PlaybackNotifier extends ChangeNotifier {
  BuildContext context;
  AudioFile audioFile;

  PlaybackNotifier(this.context);

  setAudioFile(AudioFile audioFile) {
    this.audioFile = audioFile;
    notifyListeners();
  }

  readyToPlay() {
    audioFile.readyToPlay = true;
    notifyListeners();
  }
}