import 'package:flutter/foundation.dart';

/// Cursor pagination metadata parsed from ADR-0053 response envelope.
@immutable
class MobileCursorPaginationMeta {
  final String type;
  final int pageSize;
  final bool hasNext;
  final bool hasPrevious;
  final String? nextCursor;
  final String? previousCursor;

  const MobileCursorPaginationMeta({
    this.type = 'cursor',
    required this.pageSize,
    required this.hasNext,
    required this.hasPrevious,
    this.nextCursor,
    this.previousCursor,
  });

  factory MobileCursorPaginationMeta.fromJson(Map<String, dynamic> json) {
    return MobileCursorPaginationMeta(
      type: json['type'] as String? ?? 'cursor',
      pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
      hasNext: json['has_next'] as bool? ?? false,
      hasPrevious: json['has_previous'] as bool? ?? false,
      nextCursor: json['next_cursor'] as String?,
      previousCursor: json['previous_cursor'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'page_size': pageSize,
      'has_next': hasNext,
      'has_previous': hasPrevious,
      'next_cursor': nextCursor,
      'previous_cursor': previousCursor,
    };
  }
}

/// Generic cursor-paginated page container for Flutter Mobile Manager.
@immutable
class MobileCursorPage<T> {
  final List<T> items;
  final MobileCursorPaginationMeta pagination;
  final Map<String, dynamic> filters;
  final String requestId;
  final String messageEn;
  final String messageBn;

  const MobileCursorPage({
    required this.items,
    required this.pagination,
    this.filters = const {},
    this.requestId = '',
    this.messageEn = '',
    this.messageBn = '',
  });

  bool get isEmpty => items.isEmpty;
  int get count => items.length;
}
