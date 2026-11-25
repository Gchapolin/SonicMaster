// Host-side driver for `flutter drive`, which (unlike `flutter test`) can run
// integration tests on a wirelessly paired iOS device:
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/<test>.dart -d <device>
import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
