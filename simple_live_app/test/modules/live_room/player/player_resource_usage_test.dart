import 'package:flutter_test/flutter_test.dart';
import 'package:simple_live_app/modules/live_room/player/player_resource_usage.dart';

void main() {
  test('first sample only reports resident memory', () {
    final usage = calculatePlayerResourceUsage(
      current: const PlayerResourceCounters(
        elapsedMicroseconds: 1000000,
        cpuTimeMicroseconds: 500000,
        memoryBytes: 512 * 1024 * 1024,
        networkReceiveBytes: 10000,
        networkTransmitBytes: 2000,
        metalFxGpuMilliseconds: 40,
      ),
    );

    expect(usage.cpuPercent, isNull);
    expect(usage.metalFxGpuPercent, isNull);
    expect(usage.memoryBytes, 512 * 1024 * 1024);
  });

  test('calculates process, MetalFX and network rates', () {
    const previous = PlayerResourceCounters(
      elapsedMicroseconds: 1000000,
      cpuTimeMicroseconds: 2000000,
      memoryBytes: 500 * 1024 * 1024,
      networkReceiveBytes: 10 * 1024 * 1024,
      networkTransmitBytes: 1024 * 1024,
      metalFxGpuMilliseconds: 100,
    );
    const current = PlayerResourceCounters(
      elapsedMicroseconds: 2000000,
      cpuTimeMicroseconds: 2500000,
      memoryBytes: 512 * 1024 * 1024,
      networkReceiveBytes: 15 * 1024 * 1024,
      networkTransmitBytes: 1124 * 1024,
      metalFxGpuMilliseconds: 160,
    );

    final usage = calculatePlayerResourceUsage(
      previous: previous,
      current: current,
    );

    expect(usage.cpuPercent, 50);
    expect(usage.metalFxGpuPercent, 6);
    expect(usage.downloadBytesPerSecond, 5 * 1024 * 1024);
    expect(usage.uploadBytesPerSecond, 100 * 1024);
    expect(
      usage.values,
      'CPU 50.0%   MFX GPU 6.0%   MEM 512 MB   '
      'NET ↓5.0 MB/s ↑100 KB/s',
    );
  });

  test('counter reset suppresses invalid rates', () {
    const previous = PlayerResourceCounters(
      elapsedMicroseconds: 1000000,
      cpuTimeMicroseconds: 2000000,
      memoryBytes: 500,
      networkReceiveBytes: 10000,
      networkTransmitBytes: 10000,
      metalFxGpuMilliseconds: 100,
    );
    const current = PlayerResourceCounters(
      elapsedMicroseconds: 2000000,
      cpuTimeMicroseconds: 100,
      memoryBytes: 600,
      networkReceiveBytes: 100,
      networkTransmitBytes: 100,
      metalFxGpuMilliseconds: 1,
    );

    final usage = calculatePlayerResourceUsage(
      previous: previous,
      current: current,
    );

    expect(usage.cpuPercent, isNull);
    expect(usage.metalFxGpuPercent, isNull);
    expect(usage.downloadBytesPerSecond, isNull);
    expect(usage.uploadBytesPerSecond, isNull);
  });
}
