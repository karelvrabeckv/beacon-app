class Classroom {
  final int id;
  final String label;

  Classroom({
    required this.id,
    required this.label,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'label': label,
    };
  }

  @override
  String toString() {
    return 'Classroom{id: $id, label: $label}';
  }
}
