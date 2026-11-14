class DatabaseFileLock {
  DatabaseFileLock(String path);
  Future<void> acquire() async {}
  Future<void> release() async {}
}
