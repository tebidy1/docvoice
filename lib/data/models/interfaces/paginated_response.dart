class PaginatedResponse<T> {
  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;
  final int perPage;
  final int? from;
  final int? to;

  bool get hasMore => currentPage < lastPage;

  const PaginatedResponse({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    required this.perPage,
    this.from,
    this.to,
  });

  factory PaginatedResponse.fromJson(
    dynamic json,
    T Function(dynamic) fromItem,
  ) {
    if (json is! Map<String, dynamic>) {
      return PaginatedResponse(items: [], currentPage: 1, lastPage: 1, total: 0, perPage: 15);
    }
    final data = json['data'] as List<dynamic>? ?? [];
    final meta = json['meta'] as Map<String, dynamic>?;

    if (meta != null) {
      return PaginatedResponse(
        items: data.map((e) => fromItem(e)).toList(),
        currentPage: meta['current_page'] as int? ?? 1,
        lastPage: meta['last_page'] as int? ?? 1,
        total: meta['total'] as int? ?? data.length,
        perPage: meta['per_page'] as int? ?? 15,
        from: meta['from'] as int?,
        to: meta['to'] as int?,
      );
    }

    // Flat pagination format (fields at root level alongside data)
    return PaginatedResponse(
      items: data.map((e) => fromItem(e)).toList(),
      currentPage: json['current_page'] as int? ?? 1,
      lastPage: json['last_page'] as int? ?? 1,
      total: json['total'] as int? ?? data.length,
      perPage: json['per_page'] as int? ?? 15,
      from: json['from'] as int?,
      to: json['to'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': items,
      'meta': {
        'current_page': currentPage,
        'last_page': lastPage,
        'total': total,
        'per_page': perPage,
        'from': from,
        'to': to,
      },
    };
  }
}
