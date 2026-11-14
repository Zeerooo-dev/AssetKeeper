import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';

class AppUpdate {
  const AppUpdate(this.version, this.notes, this.download, this.size);
  final String version;
  final String notes;
  final Uri download;
  final int size;
}

class GithubUpdates {
  static const repository = 'Zeerooo-dev/AssetKeeper';
  static const timeout = Duration(seconds: 15);
  static const maxResponseBytes = 1024 * 1024;

  bool get supported => !kIsWeb && assetSuffix != null;

  String? get assetSuffix => switch (defaultTargetPlatform) {
    TargetPlatform.android => 'android.apk',
    TargetPlatform.linux => 'linux-x64.tar.gz',
    TargetPlatform.windows => 'windows-x64.zip',
    _ => null,
  };

  Future<AppUpdate?> check({
    http.Client? client,
    Future<PackageInfo> Function()? installed,
  }) async {
    if (!supported) return null;
    final info = await (installed ?? PackageInfo.fromPlatform)();
    final connection = client ?? http.Client();
    try {
      return await _fetch(connection, info.version).timeout(timeout);
    } finally {
      if (client == null) connection.close();
    }
  }

  Future<AppUpdate?> _fetch(http.Client client, String installed) async {
    final request =
        http.Request(
            'GET',
            Uri.https('api.github.com', '/repos/$repository/releases/latest'),
          )
          ..followRedirects = false
          ..headers['Accept'] = 'application/vnd.github+json';
    final response = await client.send(request);
    if (response.statusCode == 404) return null;
    if (response.statusCode != 200) {
      throw StateError('Update service unavailable');
    }
    if ((response.contentLength ?? 0) > maxResponseBytes) {
      throw const FormatException('Release response too large');
    }
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      if (bytes.length + chunk.length > maxResponseBytes) {
        throw const FormatException('Release response too large');
      }
      bytes.addAll(chunk);
    }
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Invalid release');
    }
    return parseRelease(json, installed);
  }

  AppUpdate? parseRelease(Map<String, dynamic> json, String installed) {
    if (json['draft'] != false || json['prerelease'] != false) return null;
    final tag = json['tag_name'];
    if (tag is! String ||
        !RegExp(r'^v\d+\.\d+\.\d+$').hasMatch(tag) ||
        tag.length > 64) {
      return null;
    }
    final version = Version.parse(tag.substring(1));
    if (version <= Version.parse(installed)) return null;
    final assets = json['assets'];
    if (assets is! List || assetSuffix == null) return null;
    final expected = Uri.https(
      'github.com',
      '/$repository/releases/download/$tag/AssetKeeper-$tag-$assetSuffix',
    );
    for (final asset in assets) {
      if (asset is! Map ||
          asset['name'] != 'AssetKeeper-$tag-$assetSuffix' ||
          asset['state'] != 'uploaded' ||
          asset['browser_download_url'] != expected.toString() ||
          asset['size'] is! int ||
          asset['size'] <= 0) {
        continue;
      }
      final notes = json['body'] is String ? json['body'] as String : '';
      return AppUpdate(
        version.toString(),
        notes.length > 8000 ? '${notes.substring(0, 8000)}…' : notes,
        expected,
        asset['size'] as int,
      );
    }
    return null;
  }
}
