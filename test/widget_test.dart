import 'package:flutter_test/flutter_test.dart';
import 'package:your_pomodoro/main.dart';

void main() {
  testWidgets('Tomato timer screen renders the default timer values', (tester) async {
    await tester.pumpWidget(const TomatoTimerApp());

    expect(find.text('Tomato Timer'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('05:00'), findsOneWidget);
  });
}
