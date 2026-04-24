import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:injectable/injectable.dart';
import '../models/gallery_item.dart';

part 'gallery_bloc.freezed.dart';

@injectable
class GalleryBloc extends Bloc<GalleryEvent, GalleryState> {
  GalleryBloc({List<GalleryItem> initialItems = const [], int initialIndex = 0})
    : super(
        GalleryState(
          items: initialItems,
          currentIndex: initialIndex,
          isInitialized: initialItems.isNotEmpty,
        ),
      ) {
    on<GalleryInitialize>((event, emit) {
      emit(
        state.copyWith(
          items: event.items,
          currentIndex: event.initialIndex,
          isInitialized: true,
        ),
      );
    });

    on<GalleryIndexChanged>((event, emit) {
      if (state.currentIndex != event.index) {
        emit(
          state.copyWith(
            currentIndex: event.index,
            textPanelHeight: GalleryState.minTextPanelHeight,
          ),
        );
      }
    });

    on<GalleryTextPanelHeightChanged>((event, emit) {
      emit(state.copyWith(textPanelHeight: event.height));
    });

    on<GalleryToggleUI>((event, emit) {
      emit(state.copyWith(isUIVisible: event.isVisible ?? !state.isUIVisible));
    });

    on<GallerySetSliding>((event, emit) {
      emit(state.copyWith(isSliding: event.isSliding));
    });
  }
}

@freezed
class GalleryState with _$GalleryState {
  const GalleryState._();

  static const double minTextPanelHeight = 70.0;

  const factory GalleryState({
    @Default([]) List<GalleryItem> items,
    @Default(0) int currentIndex,
    @Default(true) bool isUIVisible,
    @Default(false) bool isInitialized,
    @Default(false) bool isSliding,
    @Default(GalleryState.minTextPanelHeight) double textPanelHeight,
  }) = _GalleryState;
}

sealed class GalleryEvent {}

class GalleryInitialize extends GalleryEvent {
  final List<GalleryItem> items;
  final int initialIndex;

  GalleryInitialize({required this.items, required this.initialIndex});
}

class GalleryIndexChanged extends GalleryEvent {
  final int index;

  GalleryIndexChanged(this.index);
}

class GalleryToggleUI extends GalleryEvent {
  final bool? isVisible;

  GalleryToggleUI({this.isVisible});
}

class GallerySetSliding extends GalleryEvent {
  final bool isSliding;

  GallerySetSliding(this.isSliding);
}

class GalleryTextPanelHeightChanged extends GalleryEvent {
  final double height;

  GalleryTextPanelHeightChanged(this.height);
}
