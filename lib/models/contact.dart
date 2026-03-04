class Contact {
  Contact({this.id, required this.name, required this.phone, this.relation = ''});

  int? id;
  String name;
  String phone;
  String relation;

  factory Contact.fromJson(Map<String, dynamic> json) => Contact(
        id: json['id'] as int?,
        name: json['name'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        relation: json['relation'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'relation': relation,
      };
}
