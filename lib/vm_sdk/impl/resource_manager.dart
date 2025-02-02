import '../types/types.dart';
import 'global_helper.dart';
import 'dart:convert';

class ResourceManager {
  static const rawAssetPath = "raw";
  static const audioAssetPath = "$rawAssetPath/audio";
  static const transitionAssetPath = "$rawAssetPath/transition";
  static const stickerAssetPath = "$rawAssetPath/sticker";

  Map<String, TransitionData> transitionMap = <String, TransitionData>{};
  Map<String, StickerData> stickerMap = <String, StickerData>{};

  Future<void> loadResourceMap() async {
    final transitionJsonMap =
        jsonDecode(await loadResourceString("data/transition.json"));

    for (final String transitionKey in transitionJsonMap.keys) {
      transitionMap[transitionKey] =
          TransitionData.fromJson(transitionJsonMap[transitionKey]!);
    }

    final stickerJsonMap =
        jsonDecode(await loadResourceString("data/sticker.json"));

    for (final String stickerKey in stickerJsonMap.keys) {
      stickerMap[stickerKey] =
          StickerData.fromJson(stickerJsonMap[stickerKey]!);
    }
  }

  Future<void> loadAutoEditAssets(AutoEditedData autoEditedData) async {
    for (int i = 0; i < autoEditedData.musicList.length; i++) {
      await loadAudioFile(autoEditedData.musicList[i].filename);
    }

    for (int i = 0; i < autoEditedData.autoEditMediaList.length; i++) {
      final AutoEditMedia autoEditMedia = autoEditedData.autoEditMediaList[i];
      String? transitionKey = autoEditMedia.transitionKey;
      String? stickerKey = autoEditMedia.stickerKey;

      final TransitionData? transitionData = transitionMap[transitionKey];
      final StickerData? stickerData = stickerMap[stickerKey];

      if (transitionData != null) {
        autoEditedData.transitionMap[transitionKey!] = transitionData;
        if (transitionData.filename != null) {
          await loadTransitionFile(transitionData.filename!);
        }
      }
      if (stickerData != null) {
        autoEditedData.stickerMap[stickerKey!] = stickerData;
        await loadStickerFile(stickerData.filename);
      }
    }
  }

  Future<void> loadAudioFile(String filename) async {
    await copyAssetToLocalDirectory("$audioAssetPath/$filename");
  }

  Future<void> loadTransitionFile(String filename) async {
    await copyAssetToLocalDirectory("$transitionAssetPath/$filename");
  }

  Future<void> loadStickerFile(String filename) async {
    await copyAssetToLocalDirectory("$stickerAssetPath/$filename");
  }
}
