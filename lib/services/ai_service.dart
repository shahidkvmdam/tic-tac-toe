import 'dart:math';

enum AiDifficulty { easy, medium, hard }

class AiService {
  final AiDifficulty difficulty;
  final Random _random = Random();

  AiService(this.difficulty);

  // Returns the index (0-8) of the AI's chosen move
  int getBestMove(List<String> board, String aiSymbol) {
    switch (difficulty) {
      case AiDifficulty.easy:
        return _getEasyMove(board, aiSymbol);
      case AiDifficulty.medium:
        // 50% chance of optimal, 50% random
        return _random.nextBool()
            ? _getHardMove(board, aiSymbol)
            : _getEasyMove(board, aiSymbol);
      case AiDifficulty.hard:
        return _getHardMove(board, aiSymbol);
    }
  }

  // Easy: pick a random empty cell
  int _getEasyMove(List<String> board, String aiSymbol) {
    final empty = _emptyCells(board);
    return empty[_random.nextInt(empty.length)];
  }

  // Hard: full minimax — never loses
  int _getHardMove(List<String> board, String aiSymbol) {
    final humanSymbol = aiSymbol == 'X' ? 'O' : 'X';
    int bestScore = -1000;
    int bestMove = -1;

    for (final i in _emptyCells(board)) {
      board[i] = aiSymbol;
      final score = _minimax(board, 0, false, aiSymbol, humanSymbol, -1000, 1000);
      board[i] = '';
      if (score > bestScore) {
        bestScore = score;
        bestMove = i;
      }
    }
    return bestMove;
  }

  int _minimax(
    List<String> board,
    int depth,
    bool isMaximizing,
    String aiSymbol,
    String humanSymbol,
    int alpha,
    int beta,
  ) {
    final winner = _findWinner(board);
    if (winner == aiSymbol) return 10 - depth;
    if (winner == humanSymbol) return depth - 10;
    if (!board.contains('')) return 0;

    if (isMaximizing) {
      int best = -1000;
      for (final i in _emptyCells(board)) {
        board[i] = aiSymbol;
        best = max(best,
            _minimax(board, depth + 1, false, aiSymbol, humanSymbol, alpha, beta));
        board[i] = '';
        alpha = max(alpha, best);
        if (beta <= alpha) break;
      }
      return best;
    } else {
      int best = 1000;
      for (final i in _emptyCells(board)) {
        board[i] = humanSymbol;
        best = min(best,
            _minimax(board, depth + 1, true, aiSymbol, humanSymbol, alpha, beta));
        board[i] = '';
        beta = min(beta, best);
        if (beta <= alpha) break;
      }
      return best;
    }
  }

  List<int> _emptyCells(List<String> board) {
    return [for (int i = 0; i < 9; i++) if (board[i].isEmpty) i];
  }

  String _findWinner(List<String> board) {
    const lines = [
      [0, 1, 2], [3, 4, 5], [6, 7, 8],
      [0, 3, 6], [1, 4, 7], [2, 5, 8],
      [0, 4, 8], [2, 4, 6],
    ];
    for (final line in lines) {
      final f = board[line[0]];
      if (f.isNotEmpty && f == board[line[1]] && f == board[line[2]]) return f;
    }
    return '';
  }
}
