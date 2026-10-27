import 'package:flutter/material.dart';

import '../../../core/config.dart';
import '../../../core/strings.dart';

class Composer extends StatefulWidget {
  const Composer({super.key, required this.onSend, required this.onAttach});

  final void Function(String text) onSend;
  final VoidCallback onAttach;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controller = TextEditingController();
  bool _canSend = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final can = _controller.text.trim().isNotEmpty;
      if (can != _canSend) setState(() => _canSend = can);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 3,
      color: scheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                tooltip: S.attach,
                onPressed: widget.onAttach,
                icon: const Icon(Icons.add_photo_alternate_outlined),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: AppConfig.maxMessageLength,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                  decoration: InputDecoration(
                    hintText: S.messageHint,
                    filled: true,
                    fillColor: scheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                tooltip: S.send,
                onPressed: _canSend ? _send : null,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
