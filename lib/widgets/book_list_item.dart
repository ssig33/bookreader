import 'package:flutter/material.dart';
import '../models/book.dart';

class BookListItem extends StatelessWidget {
  final Book book;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final Function(String)? onAddTag;

  const BookListItem({
    super.key,
    required this.book,
    required this.onTap,
    this.onRename,
    this.onDelete,
    this.onAddTag,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      book.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    children: [
                      if (onRename != null)
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: onRename,
                          tooltip: '名前変更',
                        ),
                      if (onDelete != null)
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: onDelete,
                          tooltip: '削除',
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.description,
                    book.fileType.toUpperCase(),
                  ),
                  const SizedBox(width: 8),
                  _buildInfoChip(
                    Icons.swap_horiz,
                    book.isRightToLeft ? '右→左' : '左→右',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (book.tags.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children:
                      book.tags
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              backgroundColor:
                                  Theme.of(
                                    context,
                                  ).colorScheme.primaryContainer,
                            ),
                          )
                          .toList(),
                ),
                const SizedBox(height: 8),
              ],
              if (onAddTag != null)
                TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('タグを追加'),
                  onPressed: () {
                    _showAddTagDialog(context);
                  },
                ),
              if ((book.lastReadAt != null || book.totalPages > 0) &&
                  book.fileType.toLowerCase() != 'pdf') ...[
                const Divider(),
                if (book.lastReadAt != null)
                  Text(
                    '最終閲覧: ${_formatDate(book.lastReadAt!)} (ページ: ${book.lastReadPage + 1}${book.totalPages > 0 ? ' / ${book.totalPages}' : ''})',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                if (book.lastReadAt == null && book.totalPages > 0)
                  Text(
                    '総ページ数: ${book.totalPages}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
              ],
              if (book.lastReadAt != null &&
                  book.fileType.toLowerCase() == 'pdf') ...[
                const Divider(),
                Text(
                  '最終閲覧: ${_formatDate(book.lastReadAt!)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showAddTagDialog(BuildContext context) {
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('タグを追加'),
            content: TextField(
              controller: textController,
              decoration: const InputDecoration(
                labelText: 'タグ名',
                hintText: 'タグ名を入力してください',
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('キャンセル'),
              ),
              TextButton(
                onPressed: () {
                  final tag = textController.text.trim();
                  if (tag.isNotEmpty) {
                    onAddTag?.call(tag);
                  }
                  Navigator.pop(context);
                },
                child: const Text('追加'),
              ),
            ],
          ),
    );
  }
}
