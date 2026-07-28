String? readDouyinUserUniqueId(Map roomData) {
  final userStore = roomData['userStore'];
  if (userStore is! Map) {
    return null;
  }

  final odin = userStore['odin'];
  if (odin is! Map) {
    return null;
  }

  final userUniqueId = odin['user_unique_id']?.toString();
  if (userUniqueId == null || userUniqueId.isEmpty || userUniqueId == 'null') {
    return null;
  }
  return userUniqueId;
}
