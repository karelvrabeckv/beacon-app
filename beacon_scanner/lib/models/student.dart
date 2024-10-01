class Student {
  final int? id;
  final String name;
  final String surname;
  final String sm_number;

  Student({
    this.id,
    required this.name,
    required this.surname,
    required this.sm_number,
  });

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'surname': surname,
      'sm_number': sm_number,
    };
  }
}
