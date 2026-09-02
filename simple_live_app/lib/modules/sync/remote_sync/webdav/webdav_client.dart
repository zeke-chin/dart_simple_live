import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:simple_live_app/app/log.dart';
import 'package:webdav_client/webdav_client.dart';

class DAVClient {
  late Client client;
  Completer<bool> pingCompleter = Completer();

  /// 先写应用自己的目录；群晖根路径通常不能 MKCOL，再回退到家目录。
  static const _dirCandidates = [
    '/simple_live_app',
    '/home/simple_live_app',
  ];

  DAVClient(
    String webDAVUri,
    String webDAVUser,
    String webDAVPassword,
  ) {
    client = newClient(
      webDAVUri,
      user: webDAVUser,
      password: webDAVPassword,
    );
    // 不要设置全局 Content-Type，否则 PUT zip 也会被当成 text/xml
    client.setHeaders({
      'accept-charset': 'utf-8',
    });
    client.setConnectTimeout(15000);
    client.setSendTimeout(60000);
    client.setReceiveTimeout(60000);
    pingCompleter.complete(_ping());
  }

  Future<bool> _ping() async {
    try {
      await client.ping();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> backup(Uint8List data) async {
    Object? lastError;
    for (final dir in _dirCandidates) {
      try {
        await _ensureDir(dir);
        await _putFile('$dir/backup.zip', data);
        Log.i('WebDAV上传成功: $dir/backup.zip');
        return;
      } catch (e) {
        Log.i('WebDAV上传尝试失败 $dir: $e');
        lastError = e;
        if (e is _WebDAVHttpException && !e.canTryNextPath) {
          rethrow;
        }
      }
    }
    throw lastError ?? Exception('WebDAV上传失败');
  }

  Future<List<int>> recovery() async {
    Object? lastError;
    for (final dir in _dirCandidates) {
      try {
        final data = await _getFile('$dir/backup.zip');
        Log.i('WebDAV下载成功: $dir/backup.zip');
        return data;
      } catch (e) {
        Log.i('WebDAV下载尝试失败 $dir: $e');
        lastError = e;
        if (e is _WebDAVHttpException && !e.canTryNextPath) {
          rethrow;
        }
      }
    }
    throw lastError ?? Exception('WebDAV下载失败');
  }

  Future<void> _ensureDir(String path) async {
    try {
      await client.mkdirAll(path);
    } catch (e) {
      // 目录已存在，或服务器对 MKCOL 返回 405，忽略后直接 PUT
      Log.i('WebDAV mkdir ignored: $path $e');
    }
  }

  /// 不走 [Client.write]：它会先对文件发 OPTIONS，且只接受 200。
  /// 不少网盘对文件 OPTIONS 返回 405，上传会在真正 PUT 前失败。
  Future<void> _putFile(String path, Uint8List data) async {
    var resp = await _requestPut(path, data);
    var status = resp.statusCode ?? 0;
    if (status == 409) {
      await _ensureDir(path.substring(0, path.lastIndexOf('/')));
      resp = await _requestPut(path, data);
      status = resp.statusCode ?? 0;
    }
    Log.i('WebDAV PUT $path status=$status');
    if (status == 200 || status == 201 || status == 204) {
      return;
    }
    throw _WebDAVHttpException('上传', path, status, resp.statusMessage);
  }

  Future<Response> _requestPut(String path, Uint8List data) {
    return client.c.req(
      client,
      'PUT',
      path,
      data: data,
      optionsHandler: (options) {
        options.headers ??= <String, dynamic>{};
        options.headers!['content-type'] = 'application/octet-stream';
        options.headers!['content-length'] = data.length;
      },
    );
  }

  Future<List<int>> _getFile(String path) async {
    final resp = await client.c.req(
      client,
      'GET',
      path,
      optionsHandler: (options) {
        options.responseType = ResponseType.bytes;
      },
    );
    final status = resp.statusCode ?? 0;
    Log.i('WebDAV GET $path status=$status');
    if (status == 200 && resp.data is List<int>) {
      return resp.data as List<int>;
    }
    throw _WebDAVHttpException('下载', path, status, resp.statusMessage);
  }
}

class _WebDAVHttpException implements Exception {
  final String action;
  final String path;
  final int status;
  final String? message;

  _WebDAVHttpException(this.action, this.path, this.status, this.message);

  bool get canTryNextPath =>
      status == 403 || status == 404 || status == 405 || status == 409;

  @override
  String toString() {
    final statusText = message;
    final detail =
        (statusText == null || statusText.isEmpty) ? '' : ' $statusText';
    var text = 'WebDAV$action失败 $path ($status$detail)';
    if (status == 405) {
      text += '。请在服务器地址中带上可写的备份路径';
    }
    return text;
  }
}
