import 'package:flutter/material.dart';
import 'package:play_music_along/view/widget/AudioFilesListWidget.dart';
import 'package:play_music_along/view/widget/CustomScaffoldBody.dart';
import 'package:play_music_along/view/widget/SliverHeader.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldContext = ScaffoldContext();
  final _scrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomPadding: false,
      body: CustomScaffoldBody(
          scaffoldContext: _scaffoldContext,
          child: CustomScrollView(
            controller: _scrollController,
            slivers: <Widget>[
              SliverHeader(
                  title:
                  'List of audio files'
              ),
              SliverPadding(
                padding: const EdgeInsets.only(
                    left: 25.0, top: 30.0, right: 25.0),
                sliver: AudioFilesListWidget(),
              ),
            ],
          )),
    );
  }
}
