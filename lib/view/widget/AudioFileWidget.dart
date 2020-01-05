import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:play_music_along/model/AudioFile.dart';
import 'package:play_music_along/view/screen/PlayAlongScreen.dart';

class AudioFileWidget extends StatelessWidget {
  final AudioFile audioFile;

  const AudioFileWidget({Key key, @required this.audioFile}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => PlayAlongScreen(
                audioFile: audioFile,
              ))),
      child: ListTile(
        leading: Text(
          '${audioFile.type}',
          style: TextStyle(fontSize: 12.0),
        ),
        title: Text('${audioFile.path}'),
        isThreeLine: true,
        subtitle: Text(audioFile.tracks),
        dense: true,
      ),
    );
  }
}
