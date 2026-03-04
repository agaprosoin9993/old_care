// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:zuoye/main.dart';

void main() {
  testWidgets('显示求助与默认提醒', (WidgetTester tester) async {
    await tester.pumpWidget(const GuardianApp());

    expect(find.text('一键呼救'), findsOneWidget);
    expect(find.text('呼叫家人 / SOS'), findsOneWidget);

    // 切换到用药提醒 Tab
    await tester.tap(find.text('用药提醒'));
    await tester.pumpAndSettle();

    expect(find.textContaining('吃降压药'), findsOneWidget);
    expect(find.text('添加提醒'), findsOneWidget);
  });
}
