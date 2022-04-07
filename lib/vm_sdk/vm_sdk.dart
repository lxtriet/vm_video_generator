import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

import 'types/types.dart';
import 'impl/title_helper.dart';
import 'impl/ffmpeg_manager.dart';
// import 'impl/ffmpeg_argument_generator.dart';
import 'impl/resource_manager.dart';
import 'impl/auto_edit_helper.dart';
import 'impl/ml_kit_helper.dart';
import 'impl/lottie_widget.dart';
import 'impl/template_helper.dart';

import 'impl/ffmpeg_helper.dart';

class VMSDKWidget extends StatelessWidget {
  VMSDKWidget({Key? key}) : super(key: key);

  final LottieWidget _lottieWidget = LottieWidget();

  bool _isInitialized = false;
  final FFMpegManager _ffmpegManager = FFMpegManager();
  final ResourceManager _resourceManager = ResourceManager();

  Timer? _currentTimer;
  EGenerateStatus _currentStatus = EGenerateStatus.encoding;
  int _currentRenderedFrame = 0;
  int _maxRenderedFrame = 0;
  int _currentRenderedFrameInCallback = 0;
  int _allFrame = 0;

  bool get isInitialized {
    return _isInitialized;
  }

  // SDK Initialize
  Future<void> initialize() async {
    await _resourceManager.loadResourceMap();
    await loadLabelMap();
    _isInitialized = true;
  }


  //////////////////////////
  /// EXTRACT MLKIT DATA ///
  //////////////////////////
  Future<String?> extractMLKitDetectData(MediaData data) async {
    try {
      return await extractData(data);
    } catch (e) {}
    return null;
  }

  Future<String?> generateVideo(
      List<MediaData> mediaList,
      EMusicStyle? style,
      bool isAutoEdit,
      List<String> titles,
      Function(EGenerateStatus status, double progress, double estimatedTime)?
          progressCallback) async {
    try {
      ////////////////////////////
      /// AUTO EDITING SECTION ///
      ////////////////////////////
      EMusicStyle selectedStyle = style ?? EMusicStyle.styleA;
      final List<TemplateData>? templateList =
          await loadTemplateData(selectedStyle);
      if (templateList == null) return null;

      final AutoEditedData autoEditedData = await generateAutoEditData(
          mediaList, selectedStyle, templateList, isAutoEdit);

      ///////////////////////////////
      /// FFMPEG ENCODING SECTION ///
      ///////////////////////////////
      await _resourceManager.loadAutoEditAssets(autoEditedData);

      const List<ETitleType> titleList = ETitleType.values;
      final ETitleType pickedTitle =
          titleList[(Random()).nextInt(titleList.length) % titleList.length];

      final TitleData title = (await loadTitleData(pickedTitle))!;
      title.texts.addAll(titles);

      ExportedTitlePNGSequenceData? exportedTitleData;// = await _lottieWidget.exportTitlePNGSequence(title);

      final List<AutoEditMedia> autoEditMediaList =
          autoEditedData.autoEditMediaList;
      final Map<String, TransitionData> transitionMap =
          autoEditedData.transitionMap;
      final Map<String, StickerData> stickerMap = autoEditedData.stickerMap;

      _currentStatus = EGenerateStatus.encoding;
      _currentRenderedFrame = 0;
      _maxRenderedFrame = 0;
      _currentRenderedFrameInCallback = 0;
      _allFrame = 0;

      int videoFramerate = getFramerate();
      for (int i = 0; i < autoEditMediaList.length; i++) {
        final AutoEditMedia autoEditMedia = autoEditMediaList[i];
        double duration =
            normalizeTime(autoEditMedia.duration + autoEditMedia.xfadeDuration);
        _allFrame += (duration * videoFramerate).floor();

        if (i < autoEditMediaList.length - 1) {
          TransitionData? transition =
              transitionMap[autoEditMedia.transitionKey];
          if (transition != null && transition.type == ETransitionType.xfade) {
            final AutoEditMedia nextMedia = autoEditMediaList[i + 1];
            double duration = normalizeTime(autoEditMedia.duration +
                nextMedia.duration -
                autoEditMedia.xfadeDuration -
                0.01);
            _allFrame += (duration * videoFramerate).floor();
          }
        }
      }

      if (_currentTimer != null) {
        _currentTimer!.cancel();
      }

      _currentTimer =
          Timer.periodic(const Duration(milliseconds: 250), (timer) {
        _currentTimer = timer;
        if (progressCallback != null) {
          if (_currentRenderedFrame + _currentRenderedFrameInCallback >
              _maxRenderedFrame) {
            _maxRenderedFrame =
                _currentRenderedFrame + _currentRenderedFrameInCallback;
          }

          progressCallback(
              _currentStatus, min(1.0, _maxRenderedFrame / _allFrame), 0);
        }
      });

      DateTime now = DateTime.now();

      final List<RenderedData> clipDataList = [];
      for (int i = 0; i < autoEditMediaList.length; i++) {
        final AutoEditMedia autoEditMedia = autoEditMediaList[i];
        final StickerData? stickerData = stickerMap[autoEditMedia.stickerKey];

        TransitionData? prevTransition, nextTransition;
        if (i > 0) {
          prevTransition =
              transitionMap[autoEditMediaList[i - 1].transitionKey];
        }
        if (i < autoEditMediaList.length - 1) {
          nextTransition = transitionMap[autoEditMediaList[i].transitionKey];
        }

        final RenderedData? clipData = await clipRender(
            autoEditMedia,
            i,
            stickerData,
            prevTransition,
            nextTransition,
            i == 0 ? exportedTitleData : null,
            (statistics) =>
                _currentRenderedFrameInCallback = statistics.videoFrameNumber);

        _currentRenderedFrameInCallback = 0;

        double duration =
            normalizeTime(autoEditMedia.duration + autoEditMedia.xfadeDuration);
        _currentRenderedFrame += (duration * videoFramerate).floor();

        if (clipData == null) return null;
        clipDataList.add(clipData);
      }

      final List<RenderedData> xfadeAppliedList = [];
      for (int i = 0; i < clipDataList.length; i++) {
        final RenderedData curRendered = clipDataList[i];
        final AutoEditMedia autoEditMedia = autoEditMediaList[i];
        TransitionData? xfadeTransition =
            transitionMap[autoEditMediaList[i].transitionKey];

        if (i < autoEditMediaList.length - 1 &&
            autoEditMedia.xfadeDuration > 0 &&
            xfadeTransition != null &&
            xfadeTransition.type == ETransitionType.xfade &&
            xfadeTransition.filterName != null) {
          //
          final RenderedData nextRendered = clipDataList[i + 1];

          final RenderedData? xfadeApplied = await applyXFadeTransitions(
              curRendered,
              nextRendered,
              i,
              xfadeTransition.filterName!,
              autoEditMedia.xfadeDuration,
              (statistics) => _currentRenderedFrameInCallback =
                  statistics.videoFrameNumber);

          _currentRenderedFrameInCallback = 0;
          double duration = normalizeTime(curRendered.duration +
              nextRendered.duration -
              autoEditMedia.xfadeDuration -
              0.01);
          _currentRenderedFrame += (duration * videoFramerate).floor();

          if (xfadeApplied == null) return null;
          xfadeAppliedList.add(xfadeApplied);
          i++;
        } //
        else {
          xfadeAppliedList.add(curRendered);
        }
      }

      _currentStatus = EGenerateStatus.merge;
      _currentRenderedFrame = _allFrame;

      final RenderedData? mergedClip = await mergeVideoClip(xfadeAppliedList);
      if (mergedClip == null) return null;

      final RenderedData? resultClip =
          await applyMusics(mergedClip, autoEditedData.musicList);
      if (resultClip == null) return null;

      print(DateTime.now().difference(now).inSeconds);

      if (_currentTimer != null) {
        _currentTimer!.cancel();
      }
      _currentTimer = null;

      return resultClip.absolutePath;
    } //
    catch (e) {
      if (_currentTimer != null) {
        _currentTimer!.cancel();
      }
      _currentTimer = null;

      rethrow;
    }
  }

  // cancel generate
  void cancelGenerate() async {
    try {
      await _ffmpegManager.cancel();
    } catch (e) {}
  }

  // release
  void release() {}

  @override
  Widget build(BuildContext context) {
    return _lottieWidget;
  }
}
