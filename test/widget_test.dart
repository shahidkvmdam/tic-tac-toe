import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tic_tac_toe_game/main.dart';

void main() {
  testWidgets('plays a winning tic tac toe round', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    await tester.pumpWidget(const TicTacToeApp());

    expect(find.text('Tic Tac Toe'), findsOneWidget);
    expect(find.text('Player X turn'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2));

    final cells = find.byType(BoardCell);

    await tester.tap(cells.at(0));
    await tester.pumpAndSettle();
    await tester.tap(cells.at(3));
    await tester.pumpAndSettle();
    await tester.tap(cells.at(1));
    await tester.pumpAndSettle();
    await tester.tap(cells.at(4));
    await tester.pumpAndSettle();
    await tester.tap(cells.at(2));
    await tester.pumpAndSettle();

    expect(find.text('Player X wins!'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}
