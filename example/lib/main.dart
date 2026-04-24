import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:k_gallery/k_gallery.dart';
import 'k_gallery_screen.dart';

void main() {
  runApp(const MyApp());
}

final GoRouter _router = GoRouter(
  initialLocation: KGalleryScreen.path,
  routes: [
    GoRoute(
      path: KGalleryScreen.path,
      builder: (context, state) => const KGalleryScreen(),
    ),
    GoRoute(
      path: KGalleryDetailScreen.id,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return KGalleryDetailScreen(
          contentList: extra['contentList'] as List<GalleryItem>,
          initialIndex: extra['initialIndex'] as int,
          onIndexChanged: extra['onIndexChanged'] as void Function(int)?,
        );
      },
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'KGallery Telegram Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}
