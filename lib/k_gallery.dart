library k_gallery;

import 'package:flutter/material.dart';

/// A sample KGallery widget
class KGallery extends StatelessWidget {
  const KGallery({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.blueAccent,
      alignment: Alignment.center,
      child: const Text(
        'KGallery Placeholder',
        style: TextStyle(color: Colors.white, fontSize: 24),
      ),
    );
  }
}
