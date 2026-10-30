import 'package:duoscore/presentation/startup_failure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a failed start shows what went wrong', (tester) async {
    await tester.pumpWidget(StartupFailure(error: Exception('disk full')));
    await tester.pump();
    expect(find.textContaining("DuoScore couldn't start"), findsOneWidget);
    expect(find.textContaining('disk full'), findsOneWidget);
  });
}
