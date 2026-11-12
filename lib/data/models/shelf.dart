/// Estante creado por el usuario. Los estantes del sistema
/// (Leyendo / Por leer / Terminados) salen de `Book.status`.
class Shelf {
  const Shelf({
    required this.id,
    required this.name,
    required this.order,
    required this.createdAt,
  });

  final String id;
  final String name;
  final int order;
  final DateTime createdAt;

  Shelf copyWith({String? name, int? order}) => Shelf(
    id: id,
    name: name ?? this.name,
    order: order ?? this.order,
    createdAt: createdAt,
  );
}
