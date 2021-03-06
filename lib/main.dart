import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_analytics/observer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_crashlytics/flutter_crashlytics.dart';
import 'package:logging/logging.dart';
import 'package:play_music_along/model/AudioFile.dart';
import 'package:play_music_along/utils/Log.dart';
import 'package:play_music_along/utils/i18n/bloc_provider_new.dart';
import 'package:play_music_along/utils/i18n/multiling_bloc.dart';
import 'package:play_music_along/utils/i18n/multiling_global_translations.dart';
import 'package:play_music_along/values/colors.dart';
import 'package:play_music_along/view/screen/PlayAlongScreen.dart';

Future main() async {
  bool isInDebugMode = !kReleaseMode;

  WidgetsFlutterBinding.ensureInitialized();

  if (isInDebugMode) {
    Log().initLogger(Level.ALL);

    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.dumpErrorToConsole(details);
    };

    runApp(MyApp());

    // FIXME smoreau: catcher sounds promising but prevents application to assemble
//    CatcherOptions debugOptions = CatcherOptions(DialogReportMode(), [ConsoleHandler()]);
//    Catcher(MyApp(), debugConfig: debugOptions);
  } else {
    Log().initLogger(Level.WARNING);

    FlutterError.onError = (FlutterErrorDetails details) {
      Zone.current.handleUncaughtError(details.exception, details.stack);
    };

    await FlutterCrashlytics().initialize();
    await allTranslations.init();

    runZoned<Future<Null>>(() async {
      runApp(MyApp());
    }, onError: (error, stackTrace) async {
      await FlutterCrashlytics()
          .reportCrash(error, stackTrace, forceCrash: false);
    });
  }
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  FirebaseAnalyticsObserver _observer;

  TranslationsBloc _translationsBloc;

  _MyAppState() {
    if (kReleaseMode) {
      final analytics = FirebaseAnalytics();
      _observer = FirebaseAnalyticsObserver(analytics: analytics);
    }
  }

  @override
  void initState() {
    super.initState();
    _translationsBloc = TranslationsBloc();
  }

  @override
  void dispose() {
    _translationsBloc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TranslationsBloc>(
        bloc: _translationsBloc,
        child: StreamBuilder<Locale>(
            stream: _translationsBloc.currentLocale,
            initialData: allTranslations.locale,
            builder: (BuildContext context, AsyncSnapshot<Locale> snapshot) {
              return MaterialApp(
                  navigatorObservers: _observer != null
                      ? <NavigatorObserver>[_observer]
                      : <NavigatorObserver>[],
                  title: allTranslations.text("flutter_mix"),
                  theme: ThemeData(
                      primarySwatch: MyColors.primaryColor,
                      fontFamily: 'Regular'),
//                  home: HomeScreen()
//                  home: Dummy()
                  home: PlayAlongScreen(
                      audioFile: AudioFile(
                          path: null))
              );
            }));
  }
}
