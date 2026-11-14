import 'dart:convert';

import 'package:assetkeeper/services/github_updates.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';

Map<String, dynamic> release({
  String tag = 'v1.0.5',
  String suffix = 'android.apk',
}) => {
  'tag_name': tag,
  'draft': false,
  'prerelease': false,
  'body': 'New release',
  'assets': [
    {
      'name': 'AssetKeeper-$tag-$suffix',
      'state': 'uploaded',
      'size': 1234,
      'browser_download_url':
          'https://github.com/Zeerooo-dev/AssetKeeper/releases/download/$tag/AssetKeeper-$tag-$suffix',
    },
  ],
};

void main() {
  final updates = GithubUpdates();
  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('selects the exact uploaded asset for each supported platform', () {
    for (final entry in {
      TargetPlatform.android: 'android.apk',
      TargetPlatform.windows: 'windows-x64.zip',
      TargetPlatform.linux: 'linux-x64.tar.gz',
    }.entries) {
      debugDefaultTargetPlatformOverride = entry.key;
      expect(
        updates.parseRelease(release(suffix: entry.value), '1.0.4')?.version,
        '1.0.5',
      );
      expect(
        updates.parseRelease(release(suffix: entry.value), '1.0.5'),
        isNull,
      );
      expect(
        updates.parseRelease(release(suffix: entry.value), '1.0.6'),
        isNull,
      );
      expect(
        updates
            .parseRelease(release(tag: 'v1.0.10', suffix: entry.value), '1.0.9')
            ?.version,
        '1.0.10',
      );
    }
  });

  test(
    'rejects drafts, prereleases, malformed versions and foreign downloads',
    () {
      for (final change in <String, dynamic>{
        'draft': true,
        'prerelease': true,
        'tag_name': 'v1.0.5-beta',
        'assets': [],
      }.entries) {
        expect(
          updates.parseRelease({
            ...release(),
            change.key: change.value,
          }, '1.0.4'),
          isNull,
        );
      }
      for (final url in [
        'http://github.com/Zeerooo-dev/AssetKeeper/releases/download/v1.0.5/AssetKeeper-v1.0.5-android.apk',
        'https://github.com.evil.test/Zeerooo-dev/AssetKeeper/releases/download/v1.0.5/AssetKeeper-v1.0.5-android.apk',
        'https://github.com/another/repo/releases/download/v1.0.5/AssetKeeper-v1.0.5-android.apk',
        'file:///tmp/update.apk',
      ]) {
        final data = release();
        (data['assets'] as List).first['browser_download_url'] = url;
        expect(updates.parseRelease(data, '1.0.4'), isNull);
      }
      for (final change in {
        'state': 'new',
        'size': -1,
        'name': 'another.apk',
      }.entries) {
        final data = release();
        (data['assets'] as List).first[change.key] = change.value;
        expect(updates.parseRelease(data, '1.0.4'), isNull);
      }
    },
  );

  test('uses installed app version and makes an unauthenticated metadata-only request', () async {
    final client = MockClient((request) async {
      expect(
        request.url.toString(),
        'https://api.github.com/repos/Zeerooo-dev/AssetKeeper/releases/latest',
      );
      expect(
        request.headers.keys.map((e) => e.toLowerCase()),
        isNot(contains('authorization')),
      );
      expect(request.body, isEmpty);
      return http.Response(jsonEncode(release()), 200);
    });
    addTearDown(client.close);
    Future<PackageInfo> installed() async => PackageInfo(
      appName: 'AssetKeeper',
      packageName: 'com.zeerooo.assetkeeper',
      version: '1.0.4',
      buildNumber: '5',
    );
    expect(
      (await updates.check(client: client, installed: installed))?.version,
      '1.0.5',
    );
  });

  test(
    'handles an empty repository and rejects API errors and oversized metadata',
    () async {
      Future<PackageInfo> installed() async => PackageInfo(
        appName: 'AssetKeeper',
        packageName: 'com.zeerooo.assetkeeper',
        version: '1.0.4',
        buildNumber: '5',
      );
      for (final status in [404, 403, 500]) {
        final client = MockClient((_) async => http.Response('', status));
        addTearDown(client.close);
        if (status == 404) {
          expect(
            await updates.check(client: client, installed: installed),
            isNull,
          );
        } else {
          await expectLater(
            updates.check(client: client, installed: installed),
            throwsStateError,
          );
        }
      }
      final large = MockClient(
        (_) async =>
            http.Response('x' * (GithubUpdates.maxResponseBytes + 1), 200),
      );
      addTearDown(large.close);
      await expectLater(
        updates.check(client: large, installed: installed),
        throwsFormatException,
      );
      final offline = MockClient(
        (_) async => throw http.ClientException('offline'),
      );
      addTearDown(offline.close);
      await expectLater(
        updates.check(client: offline, installed: installed),
        throwsA(isA<http.ClientException>()),
      );
    },
  );
}
