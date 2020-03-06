class AudioFile {
  int id;
  String path;
  String type;
  String tracks;
  bool readyToPlay;
  bool playing;

  AudioFile(
      {this.id,
      this.path,
      this.type = '',
      this.tracks = '',
      this.readyToPlay = false,
      this.playing = false});
}
