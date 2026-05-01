class AppAccess {
  static const List<String> adminEmails = <String>[
    'muhammadbilalsheikh185@gmail.com',
  ];

  static bool isAdminEmail(String? email) {
    if (email == null) {
      return false;
    }

    return adminEmails.any(
      (String item) => item.toLowerCase().trim() == email.toLowerCase().trim(),
    );
  }
}
