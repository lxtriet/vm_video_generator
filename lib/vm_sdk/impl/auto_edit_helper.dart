import 'dart:convert';
import 'dart:math';

import '../types/types.dart';
import 'global_helper.dart';

Map<int, EMediaLabel> classifiedLabelMap = {};
Map<int, bool> definitiveLabelMap = {};

Map<EMusicStyle, List<double>> tempDurationMap = {
  EMusicStyle.styleA: [4, 5, 6, 4, 5, 6, 4, 5, 6, 4, 5, 6, 4, 5, 6],
  EMusicStyle.styleB: [6, 7, 8, 6, 7, 8, 6, 7, 8, 6, 7, 8, 6, 7, 8],
  EMusicStyle.styleC: [3, 4, 5, 3, 4, 5, 3, 4, 5, 3, 4, 5, 3, 4, 5]
};

Future<void> loadLabelMap() async {
  List classifiedList =
      jsonDecode(await loadResourceString("data/mlkit-label-classified.json"));
  List definitiveList =
      jsonDecode(await loadResourceString("data/mlkit-label-definitive.json"));

  for (final Map map in classifiedList) {
    int id = map["id"];
    String type = map["type"];
    EMediaLabel mediaLabel = EMediaLabel.none;

    switch (type) {
      case "background":
      case "action":
      case "others":
        mediaLabel = EMediaLabel.background;
        break;

      case "person":
        mediaLabel = EMediaLabel.person;
        break;

      case "object":
        mediaLabel = EMediaLabel.object;
        break;

      default:
        break;
    }

    classifiedLabelMap[id] = mediaLabel;
  }

  for (final int id in definitiveList) {
    definitiveLabelMap[id] = true;
  }
}

Future<EMediaLabel> detectMediaLabel(
    AutoEditMedia media, MLKitDetected detected) async {
  EMediaLabel mediaLabel = EMediaLabel.none;
  final Map<EMediaLabel, double> labelConfidenceMap = {
    EMediaLabel.background: 0,
    EMediaLabel.person: 0,
    EMediaLabel.object: 0,
    EMediaLabel.none: 0
  };

  List<DetectedFrameData> detectedList = [];
  if (media.mediaData.type == EMediaType.image) {
    detectedList.addAll(detected.list);
  } //
  else if (media.mediaData.type == EMediaType.video) {
    final int startIndex = (media.startTime / (1.0 / detected.fps)).floor();
    final int endIndex =
        ((media.startTime + media.duration) / (1.0 / detected.fps)).floor();

    for (int i = startIndex; i <= endIndex && i < detected.list.length; i++) {
      detectedList.add(detected.list[i]);
    }
  }

  for (final DetectedFrameData frameData in detectedList) {
    for (final ImageLabel imageLabel in frameData.labelList) {
      EMediaLabel mediaLabel = classifiedLabelMap[imageLabel.index]!;
      double threshold = 1.0;

      if (mediaLabel == EMediaLabel.person) {
        threshold *= 4.0;
      } //
      else if (mediaLabel == EMediaLabel.background) {
        threshold *= 2.0;
      }

      labelConfidenceMap[mediaLabel] =
          labelConfidenceMap[mediaLabel]! + imageLabel.confidence * threshold;
    }
  }

  double maxValue = -1;
  for (final entry in labelConfidenceMap.entries) {
    if (entry.value > maxValue) {
      maxValue = entry.value;
      mediaLabel = entry.key;
    }
  }

  return mediaLabel;
}

Future<AutoEditedData> generateAutoEditData(
    List<MediaData> list, EMusicStyle musicStyle, bool isAutoSelect) async {
  final AutoEditedData autoEditedData = AutoEditedData();

  list.sort((a, b) => a.createDate.compareTo(b.createDate));

  ////////////////////////////////////
  // GENERATE MLKIT DETECTED OBJECT //
  ////////////////////////////////////

  final Map<MediaData, MLKitDetected> mlkitMap = {};
  final Map<MediaData, Map<int, double>> mediaAllLabelConfidenceMap = {};
  for (int i = 0; i < list.length; i++) {
    final MediaData media = list[i];
    final Map<int, double> allLabelConfidence = {};

    MLKitDetected detected = MLKitDetected.fromJson(media.mlkitDetected!);

    for (int j = 0; j < detected.list.length; j++) {
      final DetectedFrameData frameData = detected.list[j];

      for (int k = 0; k < frameData.labelList.length; k++) {
        final ImageLabel label = frameData.labelList[k];

        if (!allLabelConfidence.containsKey(label.index)) {
          allLabelConfidence[label.index] = 0;
        }
        allLabelConfidence[label.index] =
            allLabelConfidence[label.index]! + label.confidence;
      }
    }

    for (final key in allLabelConfidence.keys) {
      allLabelConfidence[key] = allLabelConfidence[key]! / detected.list.length;
    }

    mediaAllLabelConfidenceMap[media] = allLabelConfidence;
    mlkitMap[media] = detected;
  }

  /////////////////////
  // SET MEDIA GROUP //
  /////////////////////

  final Map<int, List<MediaData>> groupMap = <int, List<MediaData>>{};
  int curGroupIndex = 0;

  for (int i = 0; i < list.length - 1; i++) {
    final MediaData curData = list[i], nextData = list[i + 1];
    bool isGrouped = false;

    final int totalSecondsDiff =
        (curData.createDate.difference(nextData.createDate).inSeconds).abs();
    final int minutesDiff = ((totalSecondsDiff / 60) % 60).floor();
    final int hoursDiff = ((totalSecondsDiff / 3600) % 60).floor();

    if (minutesDiff >= 10 || hoursDiff >= 1) {
      isGrouped = true;
    } //
    else {
      for (int j = 0; j < 3; j++) {
        final diffThreshold = j <= 1 ? 0 : 15;
        final double latitudeDiff =
            (curData.gpsData.latitude[j] - nextData.gpsData.latitude[j]).abs();
        final double longitudeDiff =
            (curData.gpsData.longitude[j] - nextData.gpsData.longitude[j])
                .abs();

        if (latitudeDiff > diffThreshold || longitudeDiff > diffThreshold) {
          isGrouped = true;
          break;
        }
      }
    }

    if (!groupMap.containsKey(curGroupIndex)) {
      groupMap[curGroupIndex] = <MediaData>[];
    }
    groupMap[curGroupIndex]!.add(curData);

    if (isGrouped) {
      curGroupIndex++;
    }

    // last Element
    if (i + 1 == list.length - 1) {
      if (!groupMap.containsKey(curGroupIndex)) {
        groupMap[curGroupIndex] = <MediaData>[];
      }
      groupMap[curGroupIndex]!.add(nextData);
    }
  }

  ////////////////////////////////////////////
  // MEDIA FILTERING, REMOVE DUPLICATE CLIP //
  ////////////////////////////////////////////

  if (isAutoSelect) {
    int totalMediaCount = list.length;

    // MEDIA FILTERING
    for (final entry in groupMap.entries) {
      if (totalMediaCount < 20) break;

      final int key = entry.key;
      final List<MediaData> curList = entry.value;

      for (int i = 0; i < curList.length; i++) {
        final MediaData data = curList[i];
        bool isShortVideo = false, isFewObject = false;
        bool isContainDefinitiveLabel = false;
        bool isRemove = false;

        // less than 3 seconds (video)
        if (data.type == EMediaType.video &&
            data.duration != null &&
            data.duration! < 3) {
          isShortVideo = true;
        }

        // Detected ImageLabels <= 4
        Map<int, double> labelMap = mediaAllLabelConfidenceMap[data]!;
        if (labelMap.length <= 4) {
          isFewObject = true;
        }

        // If contain definitve label, pass
        for (final label in labelMap.entries) {
          if (definitiveLabelMap.containsKey(label.key)) {
            isContainDefinitiveLabel = true;
            break;
          }
        }

        if (isShortVideo) {
          isRemove = true;
        } //
        else if (!isContainDefinitiveLabel) {
          if (isFewObject) isRemove = true;
        }

        if (isRemove) {
          curList.removeAt(i);
          i--;
          totalMediaCount--;
        }
        if (totalMediaCount < 20) break;
      }
    }

    // REMOVE DUPLICATE CLIP
    for (final entry in groupMap.entries) {
      if (totalMediaCount < 20) break;

      final List<MediaData> curList = entry.value;
      int startSimilarIndex = -1, endSimilarIndex = -1;

      for (int i = 0; i < curList.length - 1; i++) {
        final MediaData cur = curList[i], next = curList[i + 1];

        final Map<int, double> curLabelMap = mediaAllLabelConfidenceMap[cur]!,
            nextLabelMap = mediaAllLabelConfidenceMap[next]!;
        final Map<int, bool> allLabelMap = {};

        for (final label in curLabelMap.entries) {
          if (label.value >= 0.1) {
            allLabelMap[label.key] = true;
          }
        }
        for (final label in nextLabelMap.entries) {
          if (label.value >= 0.1) {
            allLabelMap[label.key] = true;
          }
        }

        double similarity = 0;
        for (final labelKey in allLabelMap.keys) {
          double curConfidence =
              curLabelMap.containsKey(labelKey) ? curLabelMap[labelKey]! : 0;
          double nextConfidence =
              nextLabelMap.containsKey(labelKey) ? nextLabelMap[labelKey]! : 0;

          similarity += min(curConfidence, nextConfidence) /
              max(curConfidence, nextConfidence);
        }
        similarity /= allLabelMap.length;

        if (similarity >= 0.4) {
          if (startSimilarIndex == -1) {
            startSimilarIndex = i;
          }
          endSimilarIndex = i + 1;
        } //
        else {
          if (startSimilarIndex != -1 && endSimilarIndex != -1) {
            int duplicatedCount = endSimilarIndex - startSimilarIndex + 1;
            int picked =
                startSimilarIndex + (Random()).nextInt(duplicatedCount);

            final List<MediaData> removeTargets = [];
            for (int j = startSimilarIndex;
                j <= endSimilarIndex && j < curList.length;
                j++) {
              if (picked != j) removeTargets.add(curList[j]);
            }

            for (final MediaData deleteTarget in removeTargets) {
              curList.remove(deleteTarget);
              totalMediaCount--;
              if (totalMediaCount < 20) break;
            }

            i = startSimilarIndex;
            startSimilarIndex = endSimilarIndex = -1;

            if (totalMediaCount < 20) break;
          }
        }
      }
    }
  }

  ////////////////////////////////////////
  // SET CLIP DURATION, SET MEDIA LABEL //
  ////////////////////////////////////////

  final List<double> durationList = tempDurationMap[musicStyle]!;
  int currentMediaIndex = 0;
  double totalRemainDuration = 0;

  for (final entry in groupMap.entries) {
    final List<MediaData> curList = entry.value;
    if (curList.isEmpty) continue;

    for (int i = 0; i < curList.length; i++) {
      final MediaData mediaData = curList[i];
      final AutoEditMedia autoEditMedia = AutoEditMedia(mediaData);
      if (i == curList.length - 1) autoEditMedia.isBoundary = true;

      final double currentDuration =
          durationList[currentMediaIndex % durationList.length];
      if (mediaData.type == EMediaType.image) {
        autoEditMedia.duration = currentDuration;
      } //
      else if (mediaData.type == EMediaType.video) {
        if (mediaData.duration! < currentDuration) {
          autoEditMedia.duration = mediaData.duration!;
          totalRemainDuration += currentDuration - mediaData.duration!;
          // print(mediaData.absolutePath);
          // print("index : $currentMediaIndex");
          // print("defined : $currentDuration");
          // print("duration : ${autoEditMedia.duration}");
          // print("remain : ${currentDuration - mediaData.duration!}");
          // print("totalRemain : $totalRemainDuration");
          // print("");
          // print("");
        } //
        else {
          autoEditMedia.startTime =
              min(3, (mediaData.duration! - currentDuration) / 2.0);
          autoEditMedia.duration = currentDuration;

          if (totalRemainDuration > 0) {
            final double mediaRemainDuration = max(
                0,
                (mediaData.duration! -
                    currentDuration -
                    autoEditMedia.startTime));

            // print(mediaData.absolutePath);
            // print("index : $currentMediaIndex");
            // print("defined : $currentDuration");
            // print("start/b : ${autoEditMedia.startTime}");
            // print("duration/b : ${autoEditMedia.duration}");
            // print("mediaRemain/b : $mediaRemainDuration");
            // print("totalRemain/b : $totalRemainDuration");
            if (mediaRemainDuration >= totalRemainDuration) {
              autoEditMedia.duration += totalRemainDuration;
              totalRemainDuration = 0;
            } //
            else {
              autoEditMedia.duration += mediaRemainDuration;
              totalRemainDuration -= mediaRemainDuration;

              if (autoEditMedia.startTime >= totalRemainDuration) {
                autoEditMedia.startTime -= totalRemainDuration;
                autoEditMedia.duration += totalRemainDuration;
                totalRemainDuration = 0;
              } //
              else {
                totalRemainDuration -= autoEditMedia.startTime;
                autoEditMedia.duration += autoEditMedia.startTime;
                autoEditMedia.startTime = 0;
              }
            }
            // print("");
            // print("start/a : ${autoEditMedia.startTime}");
            // print("duration/a : ${autoEditMedia.duration}");
            // print("mediaRemain/a : $mediaRemainDuration");
            // print("totalRemain/a : $totalRemainDuration");
            // print("");
            // print("");
          }
        }
      }

      autoEditMedia.mediaLabel =
          await detectMediaLabel(autoEditMedia, mlkitMap[mediaData]!);

      autoEditedData.autoEditMediaList.add(autoEditMedia);
      currentMediaIndex++;
    }
  }

  return autoEditedData;
}