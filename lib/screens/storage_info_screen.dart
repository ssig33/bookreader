import 'package:flutter/material.dart';
import '../services/file_service.dart';
import 'dart:io';

class StorageInfoScreen extends StatefulWidget {
  const StorageInfoScreen({Key? key}) : super(key: key);

  @override
  State<StorageInfoScreen> createState() => _StorageInfoScreenState();
}

class _StorageInfoScreenState extends State<StorageInfoScreen> {
  final FileService _fileService = FileService();
  List<FileSystemEntity> _files = [];
  String _totalSize = '計算中...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStorageInfo();
  }

  Future<void> _loadStorageInfo() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _fileService.initialize();
      final files = await _fileService.getAllFiles();
      final totalSize = await _fileService.getHumanReadableTotalStorageUsed();

      setState(() {
        _files = files;
        _totalSize = totalSize;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラー: ${e.toString()}')));
      }
    }
  }

  Future<void> _deleteFile(FileSystemEntity file) async {
    try {
      await _fileService.deleteFile(file.path);
      await _loadStorageInfo();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ファイルを削除しました')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('削除エラー: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ストレージ情報'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStorageInfo,
            tooltip: '更新',
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  _buildStorageSummary(),
                  const Divider(),
                  Expanded(
                    child:
                        _files.isEmpty ? _buildEmptyState() : _buildFileList(),
                  ),
                ],
              ),
    );
  }

  Widget _buildStorageSummary() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '合計ストレージ使用量:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                _totalSize,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [const Text('ファイル数:'), Text('${_files.length} 個')],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'ファイルがありません',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildFileList() {
    return ListView.builder(
      itemCount: _files.length,
      itemBuilder: (context, index) {
        final file = _files[index];
        final fileName = file.path.split(Platform.pathSeparator).last;

        return FutureBuilder<String>(
          future: _fileService.getHumanReadableFileSize(file.path),
          builder: (context, snapshot) {
            final fileSize = snapshot.hasData ? snapshot.data! : '計算中...';

            return ListTile(
              leading: _getFileIcon(fileName),
              title: Text(
                fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(fileSize),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _confirmDelete(file),
                tooltip: '削除',
              ),
            );
          },
        );
      },
    );
  }

  Widget _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();

    switch (extension) {
      case 'pdf':
        return const Icon(Icons.picture_as_pdf, color: Colors.red);
      case 'zip':
      case 'cbz':
        return const Icon(Icons.archive, color: Colors.amber);
      default:
        return const Icon(Icons.insert_drive_file);
    }
  }

  void _confirmDelete(FileSystemEntity file) {
    final fileName = file.path.split(Platform.pathSeparator).last;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('削除の確認'),
            content: Text(
              '$fileNameを削除してもよろしいですか？\n\n注意: このファイルを参照している本がある場合、その本は開けなくなります。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteFile(file);
                },
                child: const Text('削除'),
              ),
            ],
          ),
    );
  }
}
