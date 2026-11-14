import 'dart:io';

class DatabaseFileLock {
  DatabaseFileLock(String path) : path = File('$path.lock').absolute.path;
  final String path;
  static final _activePaths = <String>{};
  RandomAccessFile? _handle;
  Future<void> acquire() async {
    if (_handle != null) return;
    if (!_activePaths.add(path)) {
      throw StateError(
        'AssetKeeper is already using this database. Close the other window and retry.',
      );
    }
    RandomAccessFile? candidate;
    try {
      candidate = await File(path).open(mode: FileMode.append);
      await candidate.lock(FileLock.exclusive);
      _handle = candidate;
    } catch (_) {
      await candidate?.close();
      _activePaths.remove(path);
      throw StateError(
        'Could not lock the database. Close other AssetKeeper windows and check folder permissions.',
      );
    }
  }

  Future<void> release() async {
    final handle = _handle;
    if (handle == null) return;
    _handle = null;
    try {
      await handle.unlock();
      await handle.close();
    } finally {
      _activePaths.remove(path);
    }
  }
}
