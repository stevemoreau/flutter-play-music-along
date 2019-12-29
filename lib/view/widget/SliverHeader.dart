import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:play_music_along/values/colors.dart';
import 'package:play_music_along/values/dimens.dart';

class SliverHeader extends StatelessWidget {
  const SliverHeader({
    Key key,
    this.title,
    this.actions,
  }) : super(key: key);

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: sliver_appbar_height,
      floating: true,
      pinned: true,
      actions: actions,
      backgroundColor: MyColors.bluegreen800,
      flexibleSpace: FlexibleSpaceBar(
          centerTitle: false,
          title: Text(title,
              style: TextStyle(
                fontFamily: 'Bold',
                color: Colors.white,
                fontSize: 16.0,
              )),
          background: Image.asset(
            "assets/images/background.png",
            fit: BoxFit.cover,
          )),
    );
  }
}
