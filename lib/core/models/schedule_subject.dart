class ScheduleSubject {
  final String matiereId;
  final String nom;
  final int durationMinutes;
  final String? projetId;

  const ScheduleSubject({
    required this.matiereId,
    required this.nom,
    required this.durationMinutes,
    this.projetId,
  });

  Map<String, dynamic> toJson() => {
        'matiereId': matiereId,
        'nom': nom,
        'durationMinutes': durationMinutes,
        if (projetId != null) 'projetId': projetId,
      };

  factory ScheduleSubject.fromJson(Map<String, dynamic> json) => ScheduleSubject(
        matiereId: json['matiereId'] as String,
        nom: json['nom'] as String,
        durationMinutes: json['durationMinutes'] as int,
        projetId: json['projetId'] as String?,
      );
}
