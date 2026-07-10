import 'package:flutter/material.dart';
import 'package:renderobjects/examples/message_attachment/message_attachment.dart';

void main() {
  runApp(const MessageAttachmentApp());
}

class MessageAttachmentApp extends StatelessWidget {
  const MessageAttachmentApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Message Attachment Demo',
      debugShowCheckedModeBanner: false,
      home: MessageAttachmentDemoPage(),
    );
  }
}

class MessageAttachmentDemoPage extends StatelessWidget {
  const MessageAttachmentDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ColoredBox(
        color: const Color(0xFFB026FF),
        child: Center(
          child: MessageAttachment(
            onThumbnailTap: () => debugPrint('Thumbnail tapped'),
            onRemoveTap: () => debugPrint('Remove tapped'),
            child: Image.network('/images/photo.png', width: 96),
          ),
        ),
      ),
    );
  }
}
