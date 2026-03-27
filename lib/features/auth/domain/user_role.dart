enum UserRole {
  client('Client'),
  franchisee('Franchisee'),
  production('Production');

  final String value;
  const UserRole(this.value);

  factory UserRole.fromMap(String value) {
    return UserRole.values.firstWhere((e) => e.value == value, orElse: () => UserRole.client);
  }
}
