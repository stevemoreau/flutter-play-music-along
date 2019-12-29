import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:play_music_along/utils/Log.dart';

class ScaffoldContext {
  BuildContext context;

  /// Pops a toast message for 2s by default and logs the message to the console
  ///
  /// Usage example:
  ///
  /// final _scaffoldContext = ScaffoldContext();
  /// ...
  ///   CustomScaffoldBody(
  ///     scaffoldContext: _scaffoldContext,
  ///     child: ...(
  ///       ...
  ///         onPressed: () => _scaffoldContext.toast("Button clicked"),
  ///       ...
  ///     )
  ///   )
  void toast(String message, [int durationInSeconds = 2, LogTag tag = LogTag.INTERNAL]) {
    Log.d(tag, message);
    if (context != null) {
      final scaffold = Scaffold.of(context);
      scaffold.showSnackBar(
        SnackBar(
          content: Text(message),
          duration: Duration(seconds: durationInSeconds),
          action: SnackBarAction(
              label: 'DONE',
              onPressed: scaffold.hideCurrentSnackBar
          ),
        ),
      );
    } else {
      Log.w(LogTag.INTERNAL, "Cannot get context for toast");
    }
  }
}

class CustomScaffoldBody extends Builder {
  final ScaffoldContext scaffoldContext;
  final Widget child;

  CustomScaffoldBody({Key key, this.child, this.scaffoldContext})
      : assert(scaffoldContext != null),
        super(key: key, builder: (BuildContext context) { return null; });

  @override
  Widget build(BuildContext context) {
    scaffoldContext.context = context;
    return child;
  }
}
