enum UserRole {
  client('client', legacyValues: ['Client']),
  franchisee('franchisee', legacyValues: ['Franchisee']),
  production('factory_worker', legacyValues: ['Production', 'factory_worker']),
  admin('admin', legacyValues: ['Admin']);

  final String value;
  final List<String> legacyValues;

  const UserRole(this.value, {this.legacyValues = const <String>[]});

  static const registrationRoles = <UserRole>[
    UserRole.client,
    UserRole.franchisee,
    UserRole.production,
  ];

  factory UserRole.fromMap(String value) {
    final normalized = value.trim().toLowerCase();
    return UserRole.values.firstWhere(
      (role) =>
          role.value == normalized ||
          role.legacyValues.any(
            (legacyValue) => legacyValue.toLowerCase() == normalized,
          ),
      orElse: () => UserRole.client,
    );
  }
}

extension UserRoleX on UserRole {
  String get historyActorLabel {
    switch (this) {
      case UserRole.client:
        return 'Client';
      case UserRole.franchisee:
        return 'Franchisee';
      case UserRole.production:
        return 'Factory';
      case UserRole.admin:
        return 'Admin';
    }
  }
}
