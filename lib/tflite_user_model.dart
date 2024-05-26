class TfLiteUserModel {
  TfLiteUserModel({
    this.name,
    this.embedding,
    this.image,
  });

  TfLiteUserModel.fromJson(dynamic json) {
    name = json['name'];
    embedding =
        json['embedding'] != null ? json['embedding'].cast<dynamic>() : [];
    image = json['image'];
  }

  String? name;
  List<dynamic>? embedding;
  String? image;

  TfLiteUserModel copyWith({
    String? name,
    String? empCode,
    List<dynamic>? embedding,
    String? image,
  }) =>
      TfLiteUserModel(
        name: name ?? this.name,
        embedding: embedding ?? this.embedding,
        image: image ?? this.image,
      );

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['name'] = name;
    map['embedding'] = embedding;
    map['image'] = image;
    return map;
  }
}
