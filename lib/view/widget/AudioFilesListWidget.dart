import 'dart:io' as io;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:play_music_along/model/AudioFile.dart';
import 'package:play_music_along/utils/Log.dart';
import 'package:play_music_along/view/widget/AudioFileWidget.dart';


class AudioFilesListWidget extends StatefulWidget {
  @override
  _AudioFilesListWidgetState createState() => _AudioFilesListWidgetState();
}

class _AudioFilesListWidgetState extends State<AudioFilesListWidget> {
  Future<List<io.FileSystemEntity>> _getAudioFilesList() async {
    // FIXME smoreau: should have a better approach for next versions
    // BlocBuilder with individual file opening to now which track is available

    final directory = (await getApplicationDocumentsDirectory()).path + '/midi/';
    Directory(directory).createSync(recursive: true);
    Log.v(LogTag.API, 'Listing files from directory $directory');
    return io.Directory(directory).listSync().where((file) {
//      FileSystemEntityType type = await FileSystemEntity.type(file.path);
//      return type == FileSystemEntityType.file;
      return file.path.endsWith('.mid');
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _getAudioFilesList(),
        builder: (BuildContext context, AsyncSnapshot snapshot) {
          final audioFiles = snapshot.data;
          return snapshot.hasData ? SliverFixedExtentList(
            itemExtent: 100,
            delegate: SliverChildBuilderDelegate(
                  (BuildContext context, int index) {
                return AudioFileWidget(audioFile: AudioFile(path: audioFiles[index].path));
              },
              childCount: audioFiles.length,
            ),
          ) : SliverToBoxAdapter(child: Container());
        }
    );
  }
}