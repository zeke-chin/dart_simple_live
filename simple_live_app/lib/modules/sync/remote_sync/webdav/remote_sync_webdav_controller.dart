import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:simple_live_app/app/constant.dart';
import 'package:simple_live_app/app/controller/app_settings_controller.dart';
import 'package:simple_live_app/app/controller/base_controller.dart';
import 'package:simple_live_app/app/event_bus.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:simple_live_app/app/utils.dart';
import 'package:simple_live_app/app/utils/archive.dart';
import 'package:simple_live_app/app/utils/document.dart';
import 'package:simple_live_app/models/db/follow_user.dart';
import 'package:simple_live_app/models/db/follow_user_tag.dart';
import 'package:simple_live_app/models/db/history.dart';
import 'package:simple_live_app/modules/sync/remote_sync/webdav/webdav_client.dart';
import 'package:simple_live_app/services/bilibili_account_service.dart';
import 'package:simple_live_app/services/db_service.dart';
import 'package:simple_live_app/services/local_storage_service.dart';

class RemoteSyncWebDAVController extends BaseController {
  // ui
  var passwordVisible = true.obs;
  // ui-用户选择是否同步
  var isSyncFollows = true.obs;
  var isSyncHistories = true.obs;
  var isSyncBlockWord = true.obs;
  var isSyncBilibiliAccount = true.obs;

  late DAVClient davClient;
  var user = "--".obs;
  var lastRecoverTime = "--".obs;
  var lastUploadTime = "--".obs;

  final _userFollowJsonName = 'SimpleLive_follows.json';
  final _userHistoriesJsonName = 'SimpleLive_histories.json';
  final _userBlockedWordJsonName = 'SimpleLive_blocked_word.json';
  final _userBilibiliAccountJsonName = 'SimpleLive_bilibili_account.json';
  final _userSettingsJsonName = 'SimpleLive_Settings.json';
  final _userTagsJsonName = 'SimpleLive_Tags.json';

  // 备份/恢复设置时跳过 WebDAV 自身配置，避免把密码传到云端或覆盖当前登录状态
  static const _webdavSettingKeys = {
    LocalStorageService.kWebDAVUri,
    LocalStorageService.kWebDAVUser,
    LocalStorageService.kWebDAVPassword,
    LocalStorageService.kWebDAVLastUploadTime,
    LocalStorageService.kWebDAVLastRecoverTime,
  };

  @override
  void onInit() {
    doWebDAVInit();
    super.onInit();
  }

  // webDAV 逻辑
  // 初始化webDAV
  void doWebDAVInit() {
    var uri = LocalStorageService.instance
        .getValue(LocalStorageService.kWebDAVUri, "");
    if (uri.isEmpty) {
      notLogin.value = true;
    } else {
      user.value = LocalStorageService.instance
          .getValue(LocalStorageService.kWebDAVUser, "");
      var password = LocalStorageService.instance
          .getValue(LocalStorageService.kWebDAVPassword, "");
      davClient = DAVClient(uri, user.value, password);
      lastRecoverTime.value = _formatSyncTime(
        LocalStorageService.instance.getValue(
          LocalStorageService.kWebDAVLastRecoverTime,
          0,
        ),
        emptyText: "从未恢复",
      );
      lastUploadTime.value = _formatSyncTime(
        LocalStorageService.instance.getValue(
          LocalStorageService.kWebDAVLastUploadTime,
          0,
        ),
        emptyText: "从未上传",
      );
      checkIsLogin();
    }
  }

  // 检查webDAV登录状态
  Future<void> checkIsLogin() async {
    try {
      // 返回登录结果
      bool value = await davClient.pingCompleter.future;
      notLogin.value = !value;
    } catch (e) {
      Log.e("$e", StackTrace.current);
      notLogin.value = true;
    }
  }

  // WebDAV登录
  void doWebDAVLogin(
      String webDAVUri, String webDAVUser, String webDAVPassword) async {
    final uri = webDAVUri.trim();
    final account = webDAVUser.trim();
    SmartDialog.showLoading(msg: "正在验证账号");
    try {
      davClient = DAVClient(uri, account, webDAVPassword);
      await checkIsLogin();
      if (!notLogin.value) {
        LocalStorageService.instance
            .setValue(LocalStorageService.kWebDAVUri, uri);
        LocalStorageService.instance
            .setValue(LocalStorageService.kWebDAVUser, account);
        user.value = account;
        LocalStorageService.instance
            .setValue(LocalStorageService.kWebDAVPassword, webDAVPassword);
        Get.back();
        SmartDialog.showToast("登录成功！");
      } else {
        SmartDialog.showToast("WebDAV账号密码验证失败，请重新输入！");
      }
    } catch (e, st) {
      Log.e("WebDAV登录失败: $e", st);
      SmartDialog.showToast("WebDAV登录失败：$e");
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
    }
  }

  // WebDAV登出
  @override
  Future<void> onLogout() async {
    var result = await Utils.showAlertDialog("确定要登出WebDAV账号？", title: "退出登录");
    if (result) {
      // 清除本地账号数据
      LocalStorageService.instance.setValue(LocalStorageService.kWebDAVUri, "");
      LocalStorageService.instance
          .setValue(LocalStorageService.kWebDAVUser, "");
      LocalStorageService.instance
          .setValue(LocalStorageService.kWebDAVPassword, "");
      notLogin.value = true;
    }
  }

  // webDAV上传到云端
  Future<void> doWebDAVUpload() async {
    SmartDialog.showLoading(msg: "正在上传到云端");
    try {
      final value = await _backupData();
      await davClient.backup(Uint8List.fromList(value));
      final uploadTime = DateTime.now();
      lastUploadTime.value = Utils.parseTime(uploadTime);
      LocalStorageService.instance.setValue(
        LocalStorageService.kWebDAVLastUploadTime,
        uploadTime.millisecondsSinceEpoch,
      );
      SmartDialog.showToast("上传成功");
    } catch (e, st) {
      Log.e("上传失败: $e", st);
      SmartDialog.showToast("上传失败：$e");
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
    }
  }

  // 备份所有数据
  Future<List<int>> _backupData() async {
    final archive = Archive();
    // 获取本地备份路径
    var dir = (await getApplicationSupportDirectory()).path;
    var profile = Directory(join(dir, 'backup'));
    if (!profile.existsSync()) {
      profile.createSync();
    }
    try {
      // archive.add(filepath, data_map) 会导致文件损坏
      // follows
      var userFollowList = DBService.instance.getFollowList();
      var dataFollowsMap = {
        'data': userFollowList.map((e) => e.toJson()).toList()
      };
      final userFollowJsonFile = File(join(profile.path, _userFollowJsonName));
      await userFollowJsonFile.writeAsString(jsonEncode(dataFollowsMap));
      // 用户自定义标签
      var userTagsList = DBService.instance.getFollowTagList();
      var dataTagsMap = {'data': userTagsList.map((e) => e.toJson()).toList()};
      var userTagsJsonFile = File(join(profile.path, _userTagsJsonName));
      await userTagsJsonFile.writeAsString(jsonEncode(dataTagsMap));
      // histories
      var userHistoriesList = DBService.instance.getHistores();
      var dataHistoriesMap = {
        'data': userHistoriesList.map((e) => e.toJson()).toList()
      };
      final userHistoriesJsonFile =
          File(join(profile.path, _userHistoriesJsonName));
      await userHistoriesJsonFile.writeAsString(jsonEncode(dataHistoriesMap));

      // blocked_word
      var userShieldList = AppSettingsController.instance.shieldList;
      var dataShieldListMap = {'data': userShieldList.toList()};
      final userBlockedWordJsonFile =
          File(join(profile.path, _userBlockedWordJsonName));
      await userBlockedWordJsonFile
          .writeAsString(jsonEncode(dataShieldListMap));

      // bilibili_account
      var userBiliAccountCookieMap = {
        'data': {'cookie': BiliBiliAccountService.instance.cookie}
      };
      final bilibiliAccountJsonFile =
          File(join(profile.path, _userBilibiliAccountJsonName));
      await bilibiliAccountJsonFile
          .writeAsString(jsonEncode(userBiliAccountCookieMap));
      // settings
      var settingList = Map<dynamic, dynamic>.from(
        LocalStorageService.instance.settingsBox.toMap(),
      );
      for (final key in _webdavSettingKeys) {
        settingList.remove(key);
      }
      var dataSettingListMap = {'data': settingList};
      final settingJsonFile = File(join(profile.path, _userSettingsJsonName));
      await settingJsonFile.writeAsString(jsonEncode(dataSettingListMap));

      // 遍历profile路径下的所有文件压缩
      await archive.addDirectoryToArchive(profile.path, profile.path);
      final zipEncoder = ZipEncoder();
      final zipBytes = zipEncoder.encode(archive);
      if (zipBytes.isEmpty) {
        throw Exception("压缩备份数据失败");
      }
      return zipBytes;
    } catch (e) {
      Log.logPrint(e);
      rethrow;
    } finally {
      profile.clearSync();
    }
  }

  // webDAV恢复到本地
  Future<void> doWebDAVRecovery() async {
    SmartDialog.showLoading(msg: "正在恢复到本地");
    try {
      final data = await davClient.recovery();
      if (data.isEmpty) {
        throw Exception("云端备份文件为空");
      }
      final archive = await Isolate.run<Archive>(() {
        final zipDecoder = ZipDecoder();
        return zipDecoder.decodeBytes(data);
      });
      for (ArchiveFile file in archive) {
        await _recovery(file);
      }
      final recoverTime = DateTime.now();
      lastRecoverTime.value = Utils.parseTime(recoverTime);
      LocalStorageService.instance.setValue(
        LocalStorageService.kWebDAVLastRecoverTime,
        recoverTime.millisecondsSinceEpoch,
      );
      SmartDialog.showToast('同步完成');
    } catch (e, st) {
      Log.e("恢复失败: $e", st);
      SmartDialog.showToast("恢复失败：$e");
    } finally {
      SmartDialog.dismiss(status: SmartStatus.loading);
    }
  }

  Future<void> _recovery(ArchiveFile file) async {
    final fileName = _archiveFileName(file);
    if (file.isFile && fileName.endsWith('.json')) {
      var jsonString = utf8.decode(file.content);
      var jsonData = json.decode(jsonString)['data'];
      // 同步follows
      if (fileName == _userFollowJsonName && isSyncFollows.value) {
        // 当前云优先
        try {
          // 清空本地关注列表
          await DBService.instance.followBox.clear();
          for (var item in jsonData) {
            var user = FollowUser.fromJson(item);
            await DBService.instance.followBox.put(user.id, user);
          }
          Log.i('已同步关注用户列表');
        } catch (e) {
          Log.e('同步关注用户列表失败: $e', StackTrace.current);
        }
      } else if (fileName == _userHistoriesJsonName && isSyncHistories.value) {
        try {
          for (var item in jsonData) {
            var history = History.fromJson(item);
            if (DBService.instance.historyBox.containsKey(history.id)) {
              var old = DBService.instance.historyBox.get(history.id);
              //如果本地的更新时间比较新，就不更新
              if (old!.updateTime.isAfter(history.updateTime)) {
                continue;
              }
            }
            await DBService.instance.addOrUpdateHistory(history);
          }
          Log.i('已同步用户观看历史记录');
        } catch (e) {
          Log.e('同步用户观看历史记录失败: $e', StackTrace.current);
        }
      } else if (fileName == _userBlockedWordJsonName &&
          isSyncBlockWord.value) {
        try {
          for (var keyword in jsonData) {
            AppSettingsController.instance.addShieldList(keyword.trim());
          }
          Log.i('已同步用户屏蔽词');
        } catch (e) {
          Log.e('同步用户屏蔽词失败:$e', StackTrace.current);
        }
      } else if (fileName == _userBilibiliAccountJsonName &&
          isSyncBilibiliAccount.value) {
        try {
          var cookie = jsonData['cookie'];
          BiliBiliAccountService.instance.setCookie(cookie);
          BiliBiliAccountService.instance.loadUserInfo();
          Log.i('已同步哔哩哔哩账号');
        } catch (e) {
          Log.e('同步哔哩哔哩账号失败：$e', StackTrace.current);
        }
      } else if (fileName == _userSettingsJsonName) {
        try {
          if (jsonData is Map) {
            final restored = Map<dynamic, dynamic>.from(jsonData);
            for (final key in _webdavSettingKeys) {
              restored.remove(key);
            }
            final preserved = <dynamic, dynamic>{};
            for (final key in _webdavSettingKeys) {
              if (LocalStorageService.instance.settingsBox.containsKey(key)) {
                preserved[key] =
                    LocalStorageService.instance.settingsBox.get(key);
              }
            }
            await LocalStorageService.instance.settingsBox.clear();
            await LocalStorageService.instance.settingsBox.putAll(restored);
            await LocalStorageService.instance.settingsBox.putAll(preserved);
            Log.i('已同步用户设置');
          }
        } catch (e) {
          Log.e("同步用户设置失败：$e", StackTrace.current);
        }
      } else if (fileName == _userTagsJsonName && isSyncFollows.value) {
        try {
          // 标签功能和关注具有依赖关系，必须同时同步
          // 清空本地标签列表
          await DBService.instance.tagBox.clear();
          for (var item in jsonData) {
            var tag = FollowUserTag.fromJson(item);
            await DBService.instance.tagBox.put(tag.id, tag);
            // 插入之后验证
            var insertedTag = DBService.instance.tagBox.get(tag.id);
            Log.i('Inserted tag: ${insertedTag?.tag}');
          }
          EventBus.instance.emit(Constant.kUpdateFollow, 0);
          Log.i('已同步用户自定义标签');
        } catch (e) {
          Log.e('同步用户自定义标签失败:$e', StackTrace.current);
        }
      } else {
        return;
      }
    } else {
      Log.i('不是正确的文件名');
    }
  }

  String _archiveFileName(ArchiveFile file) {
    return file.name.replaceAll('\\', '/').split('/').last;
  }

  String _formatSyncTime(int milliseconds, {required String emptyText}) {
    if (milliseconds <= 0) {
      return emptyText;
    }
    return Utils.parseTime(DateTime.fromMillisecondsSinceEpoch(milliseconds));
  }

  // ui控制--密码可见控制
  void changePasswordVisible() {
    passwordVisible.value = !passwordVisible.value;
  }

  void changeIsSyncFollows() {
    isSyncFollows.value = !isSyncFollows.value;
  }

  void changeIsSyncHistories() {
    isSyncHistories.value = !isSyncHistories.value;
  }

  void changeIsSyncBlockWord() {
    isSyncBlockWord.value = !isSyncBlockWord.value;
  }

  void changeIsSyncBilibiliAccount() {
    isSyncBilibiliAccount.value = !isSyncBilibiliAccount.value;
  }
}
