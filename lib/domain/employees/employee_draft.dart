/// Input payload for creating or updating an employee.
class EmployeeDraft {
  const EmployeeDraft({
    required this.name,
    this.jobTitle,
    this.phone,
    required this.baseSalary,
  });

  final String name;
  final String? jobTitle;
  final String? phone;

  /// Base salary in integer agorot (see `core/utils/money.dart`).
  final int baseSalary;

  Map<String, dynamic> toJson() => {
    'name': name,
    'job_title': jobTitle,
    'phone': phone,
    'base_salary': baseSalary,
  };
}
