import 'package:flutter_test/flutter_test.dart';
import 'package:myreader/presentation/pages/reader/reader_page.dart';

void main() {
  group('resolveTxtEdgeOverscroll', () {
    test('triggers forward paging after trailing-edge overscroll passes threshold', () {
      final partial = resolveTxtEdgeOverscroll(
        accumulatedOverscroll: 0,
        triggerLatched: false,
        hasTxtPages: true,
        hasTxtChapters: true,
        currentPage: 39,
        totalPages: 40,
        overscroll: 8,
      );

      expect(partial.shouldPage, isFalse);
      expect(partial.triggerLatched, isFalse);
      expect(partial.overscroll, 8);

      final triggered = resolveTxtEdgeOverscroll(
        accumulatedOverscroll: partial.overscroll,
        triggerLatched: partial.triggerLatched,
        hasTxtPages: true,
        hasTxtChapters: true,
        currentPage: 39,
        totalPages: 40,
        overscroll: 9,
      );

      expect(triggered.shouldPage, isTrue);
      expect(triggered.previous, isFalse);
      expect(triggered.triggerLatched, isTrue);
      expect(triggered.overscroll, 0);
    });

    test('triggers backward paging after leading-edge overscroll passes threshold', () {
      final triggered = resolveTxtEdgeOverscroll(
        accumulatedOverscroll: -10,
        triggerLatched: false,
        hasTxtPages: true,
        hasTxtChapters: true,
        currentPage: 0,
        totalPages: 40,
        overscroll: -7,
      );

      expect(triggered.shouldPage, isTrue);
      expect(triggered.previous, isTrue);
      expect(triggered.triggerLatched, isTrue);
      expect(triggered.overscroll, 0);
    });

    test('resets accumulated overscroll when gesture happens away from an edge', () {
      final resolution = resolveTxtEdgeOverscroll(
        accumulatedOverscroll: 12,
        triggerLatched: false,
        hasTxtPages: true,
        hasTxtChapters: true,
        currentPage: 10,
        totalPages: 40,
        overscroll: 6,
      );

      expect(resolution.shouldPage, isFalse);
      expect(resolution.triggerLatched, isFalse);
      expect(resolution.overscroll, 0);
    });

    test('does not trigger again once current gesture is latched', () {
      final resolution = resolveTxtEdgeOverscroll(
        accumulatedOverscroll: 0,
        triggerLatched: true,
        hasTxtPages: true,
        hasTxtChapters: true,
        currentPage: 39,
        totalPages: 40,
        overscroll: 20,
      );

      expect(resolution.shouldPage, isFalse);
      expect(resolution.triggerLatched, isTrue);
    });
  });
}
