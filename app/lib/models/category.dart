import 'package:flutter/widgets.dart';

class Category {
  const Category({required this.id, required this.name, required this.color});

  final String id;
  final String name;
  final Color color;

  factory Category.fromMap(String id, Map<String, dynamic> map) => Category(
    id: id,
    name: map['name'] as String,
    color: Color(map['color'] as int),
  );

  Map<String, dynamic> toMap() => {'name': name, 'color': color.toARGB32()};
}
