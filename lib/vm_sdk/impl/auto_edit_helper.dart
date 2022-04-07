import 'dart:convert';
import 'dart:math';

import 'package:path/path.dart';

import '../types/types.dart';
import 'global_helper.dart';

Map<int, EMediaLabel> classifiedLabelMap = {};
Map<int, bool> definitiveLabelMap = {};

Map<ETransitionType, List<String>> tempTransitionMap = {
  ETransitionType.xfade: [
    "xfade_fade",
    "xfade_wiperight",
    "xfade_slideright",
    "xfade_rectcrop",
    "xfade_circlecrop",
    "xfade_radial"
  ],
  ETransitionType.overlay: [
    "TRANSITION_DA001",
    "TRANSITION_DA002",
    "TRANSITION_DA003",
    "TRANSITION_HJ001",
    "TRANSITION_HJ002",
    "TRANSITION_HJ003",
    "TRANSITION_ON001",
    "TRANSITION_ON002",
    "TRANSITION_ON003",
    // "TRANSITION_SW002",
    "TRANSITION_SW003",
    "TRANSITION_YJ001",
    "TRANSITION_YJ002",
    "TRANSITION_YJ003",
    "TRANSITION_YJ004",
    "TRANSITION_YJ005",
    // "TRANSITION_SW001"
  ],
};

Map<EMediaLabel, List<String>> tempStickerMap = {
  EMediaLabel.background: [
    "STICKER_DA007",
    "STICKER_HJ009",
    "STICKER_HJ014",
    "STICKER_HJ016",
    "STICKER_ON014",
    "STICKER_ON016",
    "STICKER_ON019",
    "STICKER_ON020",
    "STICKER_SW009",
    "STICKER_SW011",
    "STICKER_SW012",
    "STICKER_SW014",
    "STICKER_SW015",
    "STICKER_SW017",
    "STICKER_YJ008",
    "STICKER_YJ014",
    "STICKER_YJ015",
    "STICKER_YJ017",
    "STICKER_YJ019",
    "STICKER_YJ020",
    "STICKER_YJ021",
    "STICKER_YJ026",
    "STICKER_YJ027",
  ],
  EMediaLabel.object: [
    "STICKER_DA003",
    "STICKER_DA009",
    "STICKER_DA018",
    "STICKER_DA019",
    "STICKER_DA020",
    "STICKER_DA021",
    "STICKER_HJ001",
    "STICKER_HJ005",
    "STICKER_HJ010",
    "STICKER_HJ011",
    "STICKER_HJ015",
    "STICKER_ON009",
    "STICKER_ON013",
    "STICKER_ON015",
    "STICKER_SW001",
    "STICKER_SW010",
    "STICKER_SW018",
    "STICKER_SW020",
    "STICKER_YJ001",
    "STICKER_YJ002",
    "STICKER_YJ003",
    "STICKER_YJ005",
    "STICKER_YJ006",
    "STICKER_YJ007",
    // "STICKER_YJ011",
    // "STICKER_YJ012",
    "STICKER_YJ018",
    "STICKER_YJ022",
    "STIKER_ON004",
    "STIKER_ON005",
    "STIKER_ON008",

// "STICKER_DA002",
// "STICKER_DA004",
// "STICKER_DA005",
// "STICKER_DA006",
// "STICKER_DA008",
// "STICKER_DA011",
// "STICKER_DA012",
// "STICKER_DA013",
// "STICKER_DA014",
// "STICKER_DA015",
// "STICKER_DA016",
// "STICKER_DA017",
// "STICKER_HJ002",
// "STICKER_HJ003",
// "STICKER_HJ004",
// "STICKER_HJ006",
// "STICKER_HJ007",
// "STICKER_HJ012",
// "STICKER_HJ013",
// "STICKER_ON010",
// "STICKER_ON011",
// "STICKER_ON012",
// "STICKER_ON017",
// "STICKER_ON018",
// "STICKER_SW002",
// "STICKER_SW003",
// "STICKER_SW004",
// "STICKER_SW005",
// "STICKER_SW006",
// "STICKER_SW007",
// "STICKER_SW008",
// "STICKER_SW013",
// "STICKER_SW016",
// "STICKER_SW019",
// "STICKER_YJ004",
// "STICKER_YJ009",
// "STICKER_YJ010",
// "STICKER_YJ013",
// "STICKER_YJ016",
// "STICKER_YJ023",
// "STICKER_YJ024",
// "STICKER_YJ025",
// "STIKER_ON001",
// "STIKER_ON002",
// "STIKER_ON003",
// "STIKER_ON006",
// "STIKER_ON007",

// "STICKER_DA010",
// "STICKER_HJ008",
  ]
};

// Load JSON Data
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
        mediaLabel = EMediaLabel.background;
        break;

      case "person":
        mediaLabel = EMediaLabel.person;
        break;

      case "action":
        mediaLabel = EMediaLabel.action;
        break;

      case "object":
        mediaLabel = EMediaLabel.object;
        break;

      case "food":
        mediaLabel = EMediaLabel.food;
        break;

      case "animal":
        mediaLabel = EMediaLabel.animal;
        break;

      case "others":
        mediaLabel = EMediaLabel.others;
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


////////////////////////////////////
/// 클립의 Label을 지정하는 Method 입니다.
////////////////////////////////////
Future<EMediaLabel> detectMediaLabel(
    AutoEditMedia media, MLKitDetected detected) async {
  EMediaLabel mediaLabel = EMediaLabel.none;
  final Map<EMediaLabel, double> labelConfidenceMap = {
    EMediaLabel.background: 0,
    EMediaLabel.person: 0,
    EMediaLabel.action: 0,
    EMediaLabel.object: 0,
    EMediaLabel.food: 0,
    EMediaLabel.animal: 0,
    EMediaLabel.others: 0
  };

  List<DetectedFrameData> detectedList = [];
  
  // 이미지는 1장이므로 별다른 처리를 하지 않습니다.
  if (media.mediaData.type == EMediaType.image) {
    detectedList.addAll(detected.list);
  } //
  // 비디오는 SET MEDIA DURATION 섹션에셔 편집점만큼 재생되는 구간만 label 데이터를 로드합니다.
  // (예 => startTime: 3, duration: 4 => 3~7초 구간 재생. 그 구간의 label 데이터 로드)
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

      // Label을 "배경, 사람, 오브젝트, 행동, 음식, 동물, 기타"로 분류해놓은 데이터 HashMap에서 해당 label의 분류를 로드합니다.
      // assets/data/mlkit-label-classified.json에 정의되어 있습니다.
      // https://docs.google.com/spreadsheets/d/1Htht-CwchTAz98wTu7j9jLH3qY-eXzx-k6Gnb2TIAJE/edit#gid=0
      EMediaLabel mediaLabel = classifiedLabelMap[imageLabel.index]!;
      double threshold = 1.0;

      // 현재 threshold(가중치)는 하드코딩 되어있습니다.
      if (mediaLabel == EMediaLabel.person) {
        threshold *= 4.0;
      } //
      else if (mediaLabel == EMediaLabel.background ||
          mediaLabel == EMediaLabel.animal ||
          mediaLabel == EMediaLabel.food) {
        threshold *= 2.0;
      }

      // 가중치를 HashMap에 합산합니다.
      // 예) labelConfidenceMap["배경"] += 0.98
      labelConfidenceMap[mediaLabel] =
          labelConfidenceMap[mediaLabel]! + imageLabel.confidence * threshold;
    }
  }

  // 가장 높게 계산된 가중치의 Label을 확인 후 return 합니다.
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
    List<MediaData> list,
    EMusicStyle musicStyle,
    List<TemplateData> templateList,
    bool isAutoSelect) async {
  final AutoEditedData autoEditedData = AutoEditedData();

  ////////////////////////////////////
  /// * 모든 클립을 시간순으로 정렬합니다.
  //////////////////////////////////// 
  list.sort((a, b) => a.createDate.compareTo(b.createDate));

  ////////////////////////////////////
  /// GENERATE MLKIT DETECTED OBJECT
  /// * 하단 SET MEDIA LABEL 섹션에서 사용될
  ///   데이터 HashMap을 설정합니다.
  ///   mediaAllLabelConfidenceMap => MLKit Result PDF에서 확인되는 형태의 클립의 Label별 Confidence 평균값을 계산합니다.
  ///   mlkitMap => 비디오 클립의 경우 전체 구간이 아닌, SET CLIP DURATION 섹션에서 지정된 구간만 Label 데이터를 사용합니다. (예 => 3~6초 구간의 Label 인식 데이터)
  ///               SET MEDIA LABEL 섹션에서 detectMediaLabel 호출하는 부분에서 사용됩니다.
  ////////////////////////////////////

  final Map<MediaData, MLKitDetected> mlkitMap = {};
  final Map<MediaData, Map<int, double>> mediaAllLabelConfidenceMap = {};
  for (int i = 0; i < list.length; i++) {
    final MediaData media = list[i];
    final Map<int, double> allLabelConfidence = {};

    // String으로 저장되있었던 mlkit detected json string을 class로 로드합니다.
    MLKitDetected detected = MLKitDetected.fromJson(media.mlkitDetected!);

    // 모든 프레임의 label confidence를 더합니다.
    // 예) allLabelConfidence[0] += 0.982
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

    // label confidence의 평균치를 계산합니다.
    for (final key in allLabelConfidence.keys) {
      allLabelConfidence[key] = allLabelConfidence[key]! / detected.list.length;
    }

    // hashmap에 저장합니다.
    mediaAllLabelConfidenceMap[media] = allLabelConfidence;
    mlkitMap[media] = detected;
  }

  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  /// SET MEDIA GROUP 
  /// 그룹 => 클립의 경계로 묶인 클립의 그룹입니다.
  /// 현재 클립 / 다음 클립의 시간/장소 값을 비교하여 클립의 경계를 지정합니다.
  /// 
  /// * 현재는 클립을 그룹으로 groupMap 안에 묶고, SET CLIP DURATION 섹션애서 List로(autoEditedData.autoEditMediaList.add) 펼치는 과정이 있는데,
  ///   굳이 HashMap으로 담고 List 변환하는 과정은 필요없습니다. 바로 autoEditedData.autoEditMediaList에 삽입하고 isBoundary = true를 지정해줘도 됩니다.
  //////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

  final Map<int, List<MediaData>> groupMap = <int, List<MediaData>>{};
  int curGroupIndex = 0;

  for (int i = 0; i < list.length - 1; i++) {
    final MediaData curData = list[i], nextData = list[i + 1];
    bool isGrouped = false;

    // 현재 클랩 / 다음 클립의 시간차를 계산합니다. (분, 시간)
    final int totalSecondsDiff =
        (curData.createDate.difference(nextData.createDate).inSeconds).abs();
    final int minutesDiff = ((totalSecondsDiff / 60) % 60).floor();
    final int hoursDiff = ((totalSecondsDiff / 3600) % 60).floor();

    // 10분 이상 차이날 경우 경계를 설정합니다.
    if (minutesDiff >= 10 || hoursDiff >= 1) {
      isGrouped = true;
    } //
    else {
      // 현재 클립 / 다음 클립의 위도/경도 차를 계산합니다.
      // 예) 54 deg 4' 23.16" N, 27 deg 12' 27.00" E
      // latitude = [ 54, 4, 23.16 ]
      // longitude = [ 27, 12, 27.00 ]

      // 배열 마지막 인자 -> 가장 작은 단위의 위도/경도 값입니다.
      // 15 이상 차이날 경우 경계를 설정합니다.
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

  // 자동편집을 활성화했을 경우에만 Media filtering, 중복 제거를 진행합니다.
  if (isAutoSelect) {
    int totalMediaCount = list.length;

    ///////////////////
    /// MEDIA FILTERING
    ///////////////////
    for (final entry in groupMap.entries) {
      if (totalMediaCount < 20) break;

      final int key = entry.key;
      final List<MediaData> curList = entry.value;

      for (int i = 0; i < curList.length; i++) {
        final MediaData data = curList[i];
        bool isShortVideo = false, isFewObject = false;
        bool isContainDefinitiveLabel = false;
        bool isRemove = false;

        // 3초 미만 클립은 제거합니다.
        if (data.type == EMediaType.video &&
            data.duration != null &&
            data.duration! < 3) {
          isShortVideo = true;
        }

        // MLKit Detected label이 4개 이하일 경우 제거합니다.
        Map<int, double> labelMap = mediaAllLabelConfidenceMap[data]!;
        if (labelMap.length <= 4) {
          isFewObject = true;
        }
        // 단, Selfie 등 결정적인 Label이 검출되었을 경우 제거하지 않습니다.
        // assets/data/mlkit-label-definitive.json에 정의되어 있습니다. (439: "Selfie" Index Key)
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

    /// REMOVE DUPLICATE CLIP
    /// 특이사항) 비슷한 클립이어도 다른 그룹의 클립일 경우 중복으로 인식하지 않습니다.
    for (final entry in groupMap.entries) {
      if (totalMediaCount < 20) break;

      final List<MediaData> curList = entry.value;

      /// startSimilarIndex : 중복 시작 Clip Index
      /// endSimilarIndex : 중복 끝 Clip Index
      /// 
      /// [start~end를 지정해놓은 이유]
      /// 중복 클립이 3개 이상 연속으로 찍혀있을 수도 있습니다.
      /// 그런 경우에는 연속된 중복 클립을 N개로 묶고, 랜덤으로 하나의 클립을 지정합니다.
      int startSimilarIndex = -1, endSimilarIndex = -1;

      for (int i = 0; i < curList.length - 1; i++) {
        final MediaData cur = curList[i], next = curList[i + 1];

        // 현재 클립, 다음 클립의 label confidence 유사치 계산
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

        // 40% 이상 일치할 경우 중복으로 인식
        if (similarity >= 0.4) {
          if (startSimilarIndex == -1) {
            startSimilarIndex = i;
          }
          endSimilarIndex = i + 1;
        } //
        else {
          // 현재 클립이 클립 중복이 아니고, 이전 클립까지는 중복이었을 경우
          if (startSimilarIndex != -1 && endSimilarIndex != -1) {
            // 랜덤으로 중복 클립 중 하나를 지정 => picked
            int duplicatedCount = endSimilarIndex - startSimilarIndex + 1;
            int picked =
                startSimilarIndex + (Random()).nextInt(duplicatedCount);

            // picked 제외 전부 삭제
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

  /// 가상템플릿에서 편집점 데이터를 로드합니다.
  final List<double> durationList = [];
  for (int i = 0; i < templateList.length; i++) {
    final List<SceneData> scenes = templateList[i].scenes;

    for (int j = 0; j < scenes.length; j++) {
      durationList.add(scenes[j].duration);
    }
  }
  int currentMediaIndex = 0;
  double totalRemainDuration = 0;

  for (final entry in groupMap.entries) {
    final List<MediaData> curList = entry.value;
    if (curList.isEmpty) continue;

    for (int i = 0; i < curList.length; i++) {
      // 미디어를 로드합니다
      final MediaData mediaData = curList[i];
      final AutoEditMedia autoEditMedia = AutoEditMedia(mediaData);
      if (i == curList.length - 1) autoEditMedia.isBoundary = true; // isBoundary: true => 클립 경계. 트랜지션 삽입 가능

      // 가상템플릿에 지정된 duration 데이터 로드
      final double currentDuration =
          durationList[currentMediaIndex % durationList.length];

      // * 편집점을 각 클립에 적용합니다.
      // 이미지는 별다른 처리 없이 duration을 그대로 적용합니다.
      if (mediaData.type == EMediaType.image) {
        autoEditMedia.duration = currentDuration;
      } //
      // 비디오는 클립의 길이가 편집점 길이보다 짧은 경우가 있습니다.
      // 그에 따른 추가 처리가 존재합니다.
      else if (mediaData.type == EMediaType.video) {
        // 클립 길이가 편집점 길이보다 짧을 경우
        if (mediaData.duration! < currentDuration) {
          autoEditMedia.duration = mediaData.duration!;
          totalRemainDuration += currentDuration - mediaData.duration!; // 다음 클립에서 부족한 만큼 채우게끔
        } //
        // 클립 길이가 편집점 길이보다 길거나 같을 경우
        else {

          /// 클립 시작 시간 지정
          /// 3초 미만) 클립의 중간 지점 재생 (3초 미만 구간부터 재생)
          /// 3초 이상) 클립의 3초 부터 재생
          autoEditMedia.startTime =
              min(3, (mediaData.duration! - currentDuration) / 2.0);
          autoEditMedia.duration = currentDuration;

          // 이전 클립에서 부족한 만큼 채우는 처리
          if (totalRemainDuration > 0) {
            final double mediaRemainDuration = max(
                0,
                (mediaData.duration! -
                    currentDuration -
                    autoEditMedia.startTime));

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
          }
        }
      }

      ///////////////////////////////////////////////////////////////////
      /// 미디어 Label을 지정합니다. (배경, 사람, 오브젝트, 행동, 음식, 동물, 기타 등등)
      /// (비디오는 편집점으로 잘린 구간만 detect 데이터를 사용해야 하기 때문에 SET CLIP DURATION 섹션에서 Media Label을 지정해야 합니다.)
      ///////////////////////////////////////////////////////////////////
      autoEditMedia.mediaLabel =
          await detectMediaLabel(autoEditMedia, mlkitMap[mediaData]!);

      autoEditedData.autoEditMediaList.add(autoEditMedia);
      currentMediaIndex++;
    }
  }

  ///////////////////////
  // INSERT TRANSITION //
  ///////////////////////

  // TO DO : Load from Template Data
  // 트랜지션 데이터를 로드합니다.
  // (현재는 가상템플릿 데이터에서 로드하지 않고, 전역변수에서 로드합니다.)
  final Map<ETransitionType, List<String>> transitionMap = tempTransitionMap;
  final List<String> originXfadeTransitionList =
          transitionMap[ETransitionType.xfade]!,
      originOverlayTransitionList = transitionMap[ETransitionType.overlay]!;

  final List<String> curXfadeTransitionList = [], curOverlayTransitionList = [];
  curXfadeTransitionList.addAll(originXfadeTransitionList);
  curOverlayTransitionList.addAll(originOverlayTransitionList);

  // 클립 경계를 지나고, 마지막으로 트랜지션을 삽입했던 클립에서 4~7개의 클립을 지났을 경우 트랜지션을 삽입합니다.
  int lastTransitionInsertedIndex = 0;
  int clipCount = 4 + (Random()).nextInt(3);

  // isPassedBoundary => 클립 경계를 지남 (이 때 overlay 트랜지션 삽입이 가능합니다.)
  bool isPassedBoundary = false;

  for (int i = 0; i < autoEditedData.autoEditMediaList.length - 1; i++) {
    final AutoEditMedia autoEditMedia = autoEditedData.autoEditMediaList[i];
    if (autoEditMedia.isBoundary) {
      isPassedBoundary = true;
    }

    // 마지막으로 트랜지션을 삽입했던 클립에서 4~7개의 클립을 지났을 경우
    final int diff = i - lastTransitionInsertedIndex;
    if (diff >= clipCount) {
      ETransitionType currentTransitionType = ETransitionType.xfade;

      double xfadeDuration = 1;
      if (musicStyle == EMusicStyle.styleB) {
        xfadeDuration = 0.8;
      } //
      else if (musicStyle == EMusicStyle.styleC) {
        xfadeDuration = 0.5;
      }

      if (autoEditMedia.duration < 2) continue;
      if (autoEditedData.autoEditMediaList[i + 1].duration <
          (xfadeDuration + 0.1)) continue;

      // 트랜지션 타입 지정 (xfade, overlay)
      // 클립 경계를 지났을 경우
      if (isPassedBoundary) {
        // 60% 확률로 xfade, 40% 확률로 overlay를 사용
        currentTransitionType = (Random()).nextDouble() >= 0.4
            ? ETransitionType.xfade
            : ETransitionType.overlay;
      } //
      // 클립 경계를 지나지 않았을 경우에도 트랜지션을 삽입하나, overlay(모션그래픽 트랜지션)이 아닌 xfade(잔잔한 전환효과)만 허용
      else {
        currentTransitionType = ETransitionType.xfade;
      }

      // 클립이 transition의 길이보다 짧을 경우의 처리. 짧으면 트랜지션을 삽입하지 않음.
      if (currentTransitionType == ETransitionType.xfade) {
        if (autoEditMedia.mediaData.type == EMediaType.video) {
          final double mediaRemainDuration = max(
              0,
              (autoEditMedia.mediaData.duration! -
                  autoEditMedia.duration -
                  autoEditMedia.startTime));

          if (mediaRemainDuration < xfadeDuration) {
            continue;
          }
        }
        autoEditMedia.xfadeDuration = xfadeDuration;
      }

      // xfade 또는 overlay에서 랜덤으로 트랜지션 삽입
      if (currentTransitionType == ETransitionType.xfade) {
        int randIdx = (Random()).nextInt(curXfadeTransitionList.length) %
            curXfadeTransitionList.length;
        autoEditMedia.transitionKey = curXfadeTransitionList[randIdx];
        curXfadeTransitionList.removeAt(randIdx);
        if (curXfadeTransitionList.isEmpty) {
          curXfadeTransitionList.addAll(originXfadeTransitionList);
        }
      } //
      else if (currentTransitionType == ETransitionType.overlay) {
        int randIdx = (Random()).nextInt(curOverlayTransitionList.length) %
            curOverlayTransitionList.length;
        autoEditMedia.transitionKey = curOverlayTransitionList[randIdx];
        curOverlayTransitionList.removeAt(randIdx);
        if (curOverlayTransitionList.isEmpty) {
          curOverlayTransitionList.addAll(originXfadeTransitionList);
        }
      }

      lastTransitionInsertedIndex = i; // 마지막으로 트랜지션이 삽입된 클립 위치 index
      clipCount = 4 + (Random()).nextInt(3);
      isPassedBoundary = false;
    }
  }

  ////////////////////
  // INSERT STICKER //
  ////////////////////

  /// TO DO : Load from Template Data
  /// 프레임, 스티커 데이터를 로드합니다.
  /// 
  /// 프레임 : EMediaLabel.background
  /// 스티커 : EMediaLabel.object, person, food, animal, action...
  /// (현재는 가상템플릿 데이터에서 로드하지 않고, 전역변수에서 로드합니다.)
  final Map<EMediaLabel, List<String>> originStickerMap = tempStickerMap,
      curStickerMap = {};

  for (final key in originStickerMap.keys) {
    curStickerMap[key] = [];
    curStickerMap[key]!.addAll(originStickerMap[key]!);
  }

  // 마지막으로 스티커를 삽입했던 클립에서 3~5개의 클립을 지났을 경우 트랜지션을 삽입합니다.
  int lastStickerInsertedIndex = 0;
  clipCount = 3 + (Random()).nextInt(2);

  for (int i = 0; i < autoEditedData.autoEditMediaList.length; i++) {
    final AutoEditMedia autoEditMedia = autoEditedData.autoEditMediaList[i];

    final int diff = i - lastStickerInsertedIndex;

    // 마지막으로 트랜지션을 삽입했던 클립에서 3~5개의 클립을 지났을 경우
    if (diff >= clipCount) {
      if (autoEditMedia.duration < 2) continue;

      EMediaLabel mediaLabel = autoEditMedia.mediaLabel;

      // 현재 프레임,스티커 리소스가 background, object 타입만 있어서 들어간 처리.
      // 추후 제거 예정입니다.
      switch (mediaLabel) {
        case EMediaLabel.background:
        case EMediaLabel.action:
          mediaLabel = EMediaLabel.background;
          break;

        case EMediaLabel.person:
        case EMediaLabel.object:
        case EMediaLabel.food:
        case EMediaLabel.animal:
          mediaLabel = EMediaLabel.object;
          break;

        default:
          mediaLabel = EMediaLabel.none;
          break;
      }

      if (!curStickerMap.containsKey(mediaLabel)) continue;

      // 프레임, 스티커 리소스 중 랜덤으로 하나 지정하여 삽입
      List<String> curStickerList = curStickerMap[mediaLabel]!;
      int randIdx =
          (Random()).nextInt(curStickerList.length) % curStickerList.length;
      autoEditMedia.stickerKey = curStickerList[randIdx];

      curStickerList.removeAt(randIdx);
      if (curStickerList.isEmpty) {
        curStickerList.addAll(originStickerMap[mediaLabel]!);
      }

      lastStickerInsertedIndex = i;
      clipCount = 3 + (Random()).nextInt(2);
    }
  }

  print("--------------------------------------");
  print("--------------------------------------");
  for (int i = 0; i < autoEditedData.autoEditMediaList.length; i++) {
    final autoEditMedia = autoEditedData.autoEditMediaList[i];
    print(
        "${basename(autoEditMedia.mediaData.absolutePath)} / totalDuration:${autoEditMedia.mediaData.duration} / start:${autoEditMedia.startTime} / duration:${autoEditMedia.duration} / remain:${autoEditMedia.mediaData.duration != null ? (autoEditMedia.mediaData.duration! - autoEditMedia.startTime - autoEditMedia.duration) : 0} / ${autoEditMedia.mediaLabel} / sticker:${autoEditMedia.stickerKey}");
    if (autoEditMedia.transitionKey != null) {
      print("index : $i");
      print(autoEditMedia.transitionKey);
      print("");
    }
  }

  // 템플릿에서 음악 로드
  for (int i = 0; i < templateList.length; i++) {
    autoEditedData.musicList.add(templateList[i].music);
  }

  return autoEditedData;
}
