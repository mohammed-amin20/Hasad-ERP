/// An employee record stored in the `employees` table.
class Employee {
  const Employee({
    required this.id,
    required this.name,
    this.jobTitle,
    this.phone,
    required this.baseSalary,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? jobTitle;
  final String? phone;

  /// Base salary in integer agorot (see `core/utils/money.dart`).
  final int baseSalary;
  final DateTime? createdAt;

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        id: json['id'] as String,
        name: json['name'] as String,
        jobTitle: json['job_title'] as String?,
        phone: json['phone'] as String?,
        baseSalary: (json['base_salary'] as num?)?.toInt() ?? 0,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
      );
}