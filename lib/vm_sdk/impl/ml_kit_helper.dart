import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

import '../types/global.dart';
import 'ffmpeg_manager.dart';
import 'global_helper.dart';

final FaceDetector faceDetector = GoogleMlKit.vision.faceDetector();
final ImageLabeler imageLabeler = GoogleMlKit.vision.imageLabeler();
final FFMpegManager ffMpegManager = FFMpegManager();
const int convertFrame = 4;

Map convertFaceToMap(Face face) {
  final Map map = {};

  map["b"] = <String, dynamic>{
    "t": face.boundingBox.top.floor(),
    "b": face.boundingBox.bottom.floor(),
    "l": face.boundingBox.left.floor(),
    "r": face.boundingBox.right.floor()
  };
  if (face.headEulerAngleY != null) {
    map["ay"] = double.parse(face.headEulerAngleY!.toStringAsFixed(4));
  }
  if (face.headEulerAngleZ != null) {
    map["az"] = double.parse(face.headEulerAngleZ!.toStringAsFixed(4));
  }
  if (face.leftEyeOpenProbability != null) {
    map["lp"] = double.parse(face.leftEyeOpenProbability!.toStringAsFixed(4));
  }
  if (face.rightEyeOpenProbability != null) {
    map["rp"] = double.parse(face.rightEyeOpenProbability!.toStringAsFixed(4));
  }
  if (face.smilingProbability != null) {
    map["sp"] = double.parse(face.smilingProbability!.toStringAsFixed(4));
  }
  if (face.trackingId != null) {
    map["tid"] = int.parse(face.trackingId!.toString());
  }

  return map;
}

Map convertImageLabelToMap(ImageLabel label) {
  final Map map = {};

  // confidence, label
  map["c"] = double.parse(label.confidence.toStringAsFixed(4));
  map["id"] = label.index;

  return map;
}

Future<Map> detectObjects(String path) async {
  List<Map> faceList = [];
  List<Map> labelList = [];
  try {
    final InputImage inputImage = InputImage.fromFilePath(path);

    // 입력된 프레임 1장에 대한 Face Detection 실행, JSON 데이터로 변환
    final detectedFaceList = await faceDetector.processImage(inputImage);
    for (final face in detectedFaceList) {
      faceList.add(convertFaceToMap(face));
    }

    // 입력된 프레임 1장에 대한 Image Labeling 실행, JSON 데이터로 변환
    final detectedLabelList = await imageLabeler.processImage(inputImage);
    for (final label in detectedLabelList) {
      labelList.add(convertImageLabelToMap(label));
    }
  } catch (e) {}

  return {"f": faceList, "lb": labelList};
}

Future<List<Map>> runDetect(List<String> frames) async {
  // 모든 프레임을 비동기 + 병렬로 detection을 실행합니다.
  List<Future<Map>> futures = [];
  for (final frame in frames) {
    futures.add(detectObjects(frame));
  }

  return await Future.wait(futures);
}

Future<String?> extractData(MediaData data) async {
  String? result;

  // 전처리 이전 폴더 설정
  final String filename = basename(data.absolutePath);
  final String extname = extension(filename);
  final int index = filename.indexOf(extname);

  final String mlkitResultDir =
      "${await getAppDirectoryPath()}/mlkit/${filename.substring(0, index)}";
  final Directory dir = Directory(mlkitResultDir);

  if (await dir.exists()) {
    await dir.delete(recursive: true);
  }
  await dir.create(recursive: true);

  // 미디어의 해상도를 480 픽셀 이하로 조정합니다.
  // 원본 1920 * 1080 => 480 * 270
  // 원본 1080 * 1080 => 480 * 480
  // 원본 1080 * 1350 => 384 * 480
  int scaledWidth = -1;
  int scaledHeight = -1;

  if (data.width > data.height) {
    scaledWidth = 480;
    scaledHeight = (data.height * (scaledWidth / data.width)).floor();
    if (scaledHeight % 2 == 1) scaledHeight += 1;
  } else {
    scaledHeight = 480;
    scaledWidth = (data.width * (scaledHeight / data.height)).floor();
    if (scaledWidth % 2 == 1) scaledWidth += 1;
  }

  // 이미지는 해상도만 조정하여 출력합니다.
  // Output : 1.jpg
  //
  // 비디오는 프레임레이트를 4프레임으로 고정 후, Image Sequence로 출력합니다.
  // Input : 13.5초 길이의 동영상
  // Output : 1.jpg ~ 54.jpg (총 54프레임)
  final List<String> frames = [];
  if (await ffMpegManager.execute([
    "-i",
    data.absolutePath,
    "-filter_complex",
    "${data.type == EMediaType.video ? "fps=$convertFrame," : ""}scale=$scaledWidth:$scaledHeight,setdar=dar=${scaledWidth / scaledHeight}",
    "$mlkitResultDir/${data.type == EMediaType.video ? "%d" : "1"}.jpg",
    "-y"
  ], (p0) => null)) {
    await for (final entity in dir.list()) {
      frames.add(entity.path);
    }
  }

  // Image Labeling, Face Detection을 실행합니다.
  result = json.encode({"fps": convertFrame, "r": await runDetect(frames)});
  await dir.delete(recursive: true);

  return result;
}
