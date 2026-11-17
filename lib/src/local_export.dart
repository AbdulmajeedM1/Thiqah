import 'dart:convert';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import 'local_auth.dart';
import 'platform_files.dart';

/// Reads the original local repositories without changing their records.
Future<Map<String, dynamic>> exportLocalData() async {
  final raw = await const SecureAccountVault().read();
  final accounts = raw == null
      ? <dynamic>[]
      : (jsonDecode(raw) as Map)['users'] as List;
  final root = (await getApplicationSupportDirectory()).path;
  final sourceFile = File('$root/thiqah_migration_source_v1.txt');
  String source;
  if (await sourceFile.exists()) {
    source = await sourceFile.readAsString();
  } else {
    source = List.generate(
      16,
      (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await sourceFile.writeAsString(source);
  }
  final marketplaceFile = File('$root/thiqah_marketplace_v2.json');
  final marketplace = await marketplaceFile.exists()
      ? Map<String, dynamic>.from(
          jsonDecode(await marketplaceFile.readAsString()),
        )
      : <String, dynamic>{
          'requests': <dynamic>[],
          'profiles': <String, dynamic>{},
        };
  final files = <String, dynamic>{};
  final missingFiles = <String>[];
  for (final request in marketplace['requests'] as List) {
    for (final document in request['documents'] as List) {
      final path = document['path'] as String;
      if (files.containsKey(path)) continue;
      try {
        final bytes = await File(path).readAsBytes();
        files[path] = {
          'name': document['name'],
          'size': bytes.length,
          'base64': base64Encode(bytes),
        };
      } catch (_) {
        missingFiles.add(path);
      }
    }
  }
  return {
    'version': 1,
    'sourceId': source,
    'accounts': accounts,
    'marketplace': marketplace,
    'files': files,
    'missingFiles': missingFiles,
  };
}

class LocalExportScreen extends StatefulWidget {
  const LocalExportScreen({super.key, this.saveInternally = false});
  final bool saveInternally;
  @override
  State<LocalExportScreen> createState() => _LocalExportScreenState();
}

class _LocalExportScreenState extends State<LocalExportScreen> {
  Map<String, dynamic>? snapshot;
  String? status;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await exportLocalData();
      if (widget.saveInternally && !kIsWeb) {
        final root = (await getApplicationSupportDirectory()).path;
        await File('$root/thiqah_migration_export.json')
            .writeAsString(jsonEncode(data));
      }
      if (mounted) setState(() => snapshot = data);
    } catch (_) {
      if (mounted) setState(() => status = 'تعذر قراءة البيانات المحلية.');
    }
  }

  Future<void> download() async {
    await FilePicker.platform.saveFile(
      fileName: 'thiqah-local-migration.json',
      bytes: Uint8List.fromList(utf8.encode(jsonEncode(snapshot))),
    );
    if (mounted) {
      setState(
        () => status = 'تم تجهيز ملف الترحيل. يحتوي بيانات حساباتك الخاصة.',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('نقل البيانات القديمة')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (snapshot == null && status == null)
              const CircularProgressIndicator(),
            if (snapshot != null) ...[
              Text(
                'الحسابات القديمة: ${(snapshot!['accounts'] as List).length}',
              ),
              Text(
                'الطلبات القديمة: ${(snapshot!['marketplace']['requests'] as List).length}',
              ),
              Text('المرفقات المتاحة: ${(snapshot!['files'] as Map).length}'),
              const SizedBox(height: 20),
              if ((snapshot!['accounts'] as List).isNotEmpty)
                FilledButton(
                  onPressed: download,
                  child: const Text('تنزيل ملف الترحيل'),
                ),
            ],
            if (status != null) Text(status!),
          ],
        ),
      ),
    ),
  );
}
