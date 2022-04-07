import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';

import 'vm_sdk/vm_sdk.dart';
import 'vm_sdk/types/types.dart';
import 'vm_sdk/impl/global_helper.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

FlutterFFprobe ffprobe = FlutterFFprobe();

class TestWidget extends StatelessWidget {
  TestWidget({Key? key}) : super(key: key);

  final VMSDKWidget _vmsdkWidget = VMSDKWidget();

  void _run() async {
    const String testAssetPath = "_test/set1";
    final filelist = [];

    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);

    for (final key in manifestMap.keys.toList()) {
      if (key.contains(testAssetPath) && !key.contains(".DS_")) {
        filelist.add(basename(key));
      }
    }

    List<MediaData> testMediaList = [];
    for (final String filename in filelist) {
      final writedFile =
          await copyAssetToLocalDirectory("$testAssetPath/$filename");

      final mediaInfo = await ffprobe.getMediaInformation(writedFile.path);
      final streams = mediaInfo.getStreams()![0].getAllProperties();

      int width = streams["width"];
      int height = streams["height"];
      EMediaType type = EMediaType.image;

      final extname = extension(filename);

      switch (extname.toLowerCase()) {
        case ".mp4":
        case ".mov":
          type = EMediaType.video;
          break;

        case ".jpg":
        case ".jpeg":
        case ".png":
        default:
          break;
      }
      testMediaList.add(MediaData(writedFile.path, type, width, height, null,
          DateTime.now(), "", null));
    }

    List<String?> results = [];
    for (final media in testMediaList) {
      final result = await _vmsdkWidget.extractMLKitDetectData(media);
      results.add(result);
    }
    print("");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("MLKIT SDK TEST"),
      ),
      body: _vmsdkWidget,
      floatingActionButton: FloatingActionButton(
          onPressed: _run, tooltip: 'Run', child: const Icon(Icons.play_arrow)),
    );
  }
}
