import 'package:flutter/material.dart';

/// Owns text editing state until the dialog route finishes its transition.
class BottleEditorDialog extends StatefulWidget {
  const BottleEditorDialog({
    required this.title, this.initialName = '', this.initialColor, super.key,
  });
  final String title;
  final String initialName;
  final Color? initialColor;

  @override
  State<BottleEditorDialog> createState() => _BottleEditorDialogState();
}

class _BottleEditorDialogState extends State<BottleEditorDialog> {
  late final _name = TextEditingController(text: widget.initialName);
  late Color _color = widget.initialColor?.withAlpha(255) ?? const Color(0xFF389CE1);
  String? _error;
  static const _colors = [
    Color(0xFF389CE1), Color(0xFF33AB99), Color(0xFFEA88AF),
    Color(0xFFE9B457), Color(0xFF9C88DA), Color(0xFF819AB1),
  ];

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  void _save() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = '请输入瓶子名称'); return;
    }
    Navigator.pop(context, (_name.text.trim(), _color.toARGB32()));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true, title: Text(widget.title),
    content: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(
        key: const ValueKey('bottle-name-input'), controller: _name, autofocus: true,
        textInputAction: TextInputAction.done, onSubmitted: (_) => _save(),
        decoration: InputDecoration(labelText: '名称', errorText: _error),
      ),
      const SizedBox(height: 16),
      Wrap(spacing: 4, runSpacing: 4, children: [
        for (var i = 0; i < _colors.length; i++)
          Semantics(selected: _color == _colors[i], label: '瓶子颜色 ' + (i + 1).toString(),
            child: IconButton(
              tooltip: '颜色 ' + (i + 1).toString(),
              onPressed: () => setState(() => _color = _colors[i]),
              icon: CircleAvatar(backgroundColor: _colors[i],
                child: _color == _colors[i] ? const Icon(Icons.check, color: Colors.white) : null),
            )),
      ]),
    ]),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
      FilledButton(key: const ValueKey('save-bottle-button'), onPressed: _save, child: const Text('保存')),
    ],
  );
}
