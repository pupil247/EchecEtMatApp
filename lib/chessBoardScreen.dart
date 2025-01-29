/// @name: chessBoardScreen.dart
/// @author: Felix Parent
/// @date: 07-05-2024
/// @version: 1.0
/// @desc: Play page of the chessboard app

// ignore_for_file: constant_identifier_names

//import 'dart:html';

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:clipboard/clipboard.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../models/board_arrow.dart';
import 'package:chess/chess.dart' as chesslib;
import 'package:stockfish/stockfish.dart';
import '../simple_chess_board.dart';
import 'bluetooth.dart';

chesslib.Chess _chess = chesslib.Chess.fromFEN(chesslib.Chess.DEFAULT_POSITION);

enum gameModes_t {
  COMPUTERVSCOMPUTER,
  PLAYERVSCOMPUTER,
  PLAYERVSBOARD,
  COMPUTERVSBOARD
}

/// @name: checkIfPossibleMove
/// @desc: check the active chess controller and see if game is over or not
/// @param: no param
/// @return: yes or no(bool)
bool checkIfPossibleMove() {
  print("Check if still possible moves");
  chesslib.Chess chess = getChessController();
  List<chesslib.Move> possibleMoves = chess.generate_moves();
  if (possibleMoves.isNotEmpty) {
    print("still possible");
    return true;
  }
  print("no possible moves");

  return false;
}

/// @name: handlePromotion
/// @desc: pop up a dialog to select piece type for promotion
/// @param: context(BuildContext)
/// @return: piece type
Future<PieceType?> handlePromotion(BuildContext context) {
  final navigator = Navigator.of(context);
  return showDialog<PieceType>(
    context: context,
    builder: (_) {
      return AlertDialog(
        title: const Text('Promotion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text("Queen"),
              onTap: () => navigator.pop(PieceType.queen),
            ),
            ListTile(
              title: const Text("Rook"),
              onTap: () => navigator.pop(PieceType.rook),
            ),
            ListTile(
              title: const Text("Bishop"),
              onTap: () => navigator.pop(PieceType.bishop),
            ),
            ListTile(
              title: const Text("Knight"),
              onTap: () => navigator.pop(PieceType.knight),
            ),
          ],
        ),
      );
    },
  );
}

/// @name: endGameDialog
/// @desc: pop up a dialog to warn user the game is finished
/// @param: context(BuildContext)
/// @return: void
void endGameDialog(BuildContext context) {
  final navigator = Navigator.of(context);
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return AlertDialog(
        content: const Text('Game is over, go back to menu'),
        actions: [
          TextButton(
            onPressed: () {
              endBoardGame();
              Navigator.of(context).pop(); // Close the dialog
              Navigator.of(context).pop(); // Close the widget
            },
            child: const Text('Ok'),
          ),
        ],
      );
    },
  );
}

/// @name: Page Play
/// @desc: widget with the chessboard
class PagePlay extends StatefulWidget {
  final bool playerColor;
  final int difficulty;
  final int modeSelect;

  const PagePlay(
      {required this.playerColor,
      required this.difficulty,
      required this.modeSelect});

  @override
  PagePlayState createState() => PagePlayState();
}

class PagePlayState extends State<PagePlay> {
  late Stockfish stockfish;

  BoardArrow? _lastMoveArrowCoordinates;
  late ChessBoardColors _boardColors;

  final _fenController =
      TextEditingController(text: chesslib.Chess.DEFAULT_POSITION);
  late StreamSubscription _stockfishOutputSubsciption;
  var _timeMs = 3000.0;
  var _nextMove = '';
  var _stockfishOutputText = '';
  bool playerTurn = false;
  bool waiting = false;
  bool endGame = false;

  @override
  void dispose() {
    super.dispose();
    if (widget.modeSelect != 2) {
      _stopStockfish();
      stockfish.dispose();
    }
    playerMove = "";
    endBoardGame();
  }

  @override
  void onWindowClose() {
    //dispose();
    super.dispose();
    endBoardGame();
  }

  /// @name: waitFirstMove
  /// @desc: async function, wait for the first move to be made by the board. Called only when playing black
  /// @param: none
  /// @return: Future void
  Future<void> waitFirstMove() async {
    print("waiting for first move");
    if (gameMode == gameMode_t.computerVsBoard) {
      while (
          stockfish.state.value != StockfishState.ready && activeGame == true) {
        setState(() {});
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    Future.delayed(const Duration(seconds: 2));
    while (playerMove == "" && activeGame == true) {
      setState(() {});
      await Future.delayed(const Duration(seconds: 2));
    }
    ShortMove firstMove = ShortMove(
        from: playerMove.substring(0, 2),
        to: playerMove.substring(2, 4),
        promotion: null);
    playerMove = "";

    final success = _chess.move(<String, String?>{
      'from': firstMove.from,
      'to': firstMove.to,
      'promotion': firstMove.promotion?.name,
    });
    if (success) {
      print(firstMove.from);
      print(firstMove.to);
      print(firstMove.promotion);
      _lastMoveArrowCoordinates =
          BoardArrow(from: firstMove.from, to: firstMove.to);
      playerTurn = !playerTurn;
    }
    if (mounted) {
      setState(() {
        waiting = false;
      });
    }
    if (gameMode == gameMode_t.computerVsBoard) {
      _fenController.text = _chess.generate_fen(); //its always stockfish turn
      _computeNextMove();
    }
  }

  /// @name: _readStockfishOutput
  /// @desc: read stockfish output and parse move in it once he's done computing the move
  /// @param: output(string)
  /// @return: void
  void _readStockfishOutput(String output) async {
    // At least now, stockfish is ready : update UI.
    if (mounted) {
      setState(() {
        _stockfishOutputText += "$output\n";
        //print(_stockfishOutputText);
      });
    }
    if (output.startsWith('bestmove')) {
      final parts = output.split(' ');

      _nextMove = parts[1];
      String fString = _nextMove.substring(0, 2);
      String tString = _nextMove.substring(2, 4);
      var aiMove;
      if (_nextMove.length == 5) {
        PieceType piece;
        switch (_nextMove[4]) {
          case 'q':
            piece = PieceType.queen;
          case 'n':
            piece = PieceType.knight;
          case 'r':
            piece = PieceType.rook;
          case 'b':
            piece = PieceType.bishop;
          default:
            piece = PieceType.queen;
        }
        aiMove = ShortMove(from: fString, to: tString, promotion: piece);
      } else
        aiMove = ShortMove(from: fString, to: tString);
      print(_nextMove);
      print("trymakingmove");
      tryMakingMove(move: aiMove);
      //wait for the board to move the piece
      print("computer made its move"); //its now player turn
      if (mounted) {
        setState(() {
          waiting = false;
        });
      }
    }
  }

  /// @name: _pasteFen
  /// @desc: paste the value of the fen
  /// @param: none
  /// @return: void
  void _pasteFen() {
    FlutterClipboard.paste().then((value) {
      if (mounted) {
        setState(() {
          _fenController.text = value;
        });
      }
    });
  }

  /// @name: _updateThinkingTime
  /// @desc: chang ethe thinking time of stockfish
  /// @param: new thinking time value(double)
  /// @return: void
  void _updateThinkingTime(double newValue) {
    if (mounted) {
      setState(() {
        _timeMs = newValue;
      });
    }
  }

  /// @name: _validPosition
  /// @desc: check if the fen is a valid position
  /// @param: none
  /// @return: valid or not(bool)
  bool _validPosition() {
    final chess = chesslib.Chess();
    return chess.load(_fenController.text.trim());
  }

  /// @name: _computeNextMove
  /// @desc: send a request to stockfish for another move with the current position of the board
  /// @param: none
  /// @return: none
  void _computeNextMove() async {
    if (mounted) {
      setState(() {
        waiting = true;
      });
    }
    while (
        stockfish.state.value != StockfishState.ready && activeGame == true) {
      setState(() {});
      await Future.delayed(const Duration(milliseconds: 5000));
    }
    if (!_validPosition()) {
      final message = "Illegal position: '${_fenController.text.trim()}' !\n";
      if (mounted) {
        setState(() {
          _stockfishOutputText = message;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _stockfishOutputText = '';
      });
    }
    stockfish.stdin = 'position fen ${_fenController.text.trim()}';
    stockfish.stdin = 'go movetime ${_timeMs.toInt()}';
  }

  /// @name: _stopStockfish
  /// @desc: stop stockfish plugin
  /// @param: none
  /// @return: void
  void _stopStockfish() async {
    if (stockfish.state.value == StockfishState.disposed ||
        stockfish.state.value == StockfishState.error) {
      return;
    }
    _stockfishOutputSubsciption.cancel();
    stockfish.stdin = 'quit';
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      setState(() {});
    }
  }

  /// @name: _doStartStockfish
  /// @desc: start stockfish plugin
  /// @param: none
  /// @return: "stockfish started"(string)
  Future<String> _doStartStockfish() async {
    if (mounted) {
      setState(() {
        waiting = true;
      });
    }

    _stockfishOutputSubsciption = stockfish.stdout.listen(_readStockfishOutput);
    if (mounted) {
      setState(() {
        _stockfishOutputText = '';
      });
    }
    await Future.delayed(const Duration(milliseconds: 5000));
    stockfish.stdin = 'uci';
    await Future.delayed(const Duration(milliseconds: 5000));
    stockfish.stdin = 'isready';
    stockfish.stdin = 'setoption name Skill Level value ${widget.difficulty}';
    stockfish.stdin = 'getoption name Skill Level';
    if (mounted) {
      setState(() {
        waiting = false;
      });
    }
    return 'stockfish started';
  }

  /// @name: _startStockfishIfNecessary
  /// @desc: start stockfish plugin
  /// @param: none
  /// @return: void
  void _startStockfishIfNecessary() async {
    if (stockfish.state.value == StockfishState.ready ||
        stockfish.state.value == StockfishState.starting) {
      return;
    }
    await _doStartStockfish();
    if (mounted) {
      setState(() {});
    }
  }

  /// @name: _getStockfishStatusIcon
  /// @desc: get stockfish icon, depends of its status
  /// @param: none
  /// @return: Icon
  Icon _getStockfishStatusIcon() {
    Color color;
    switch (stockfish.state.value) {
      case StockfishState.ready:
        color = Colors.green;
        break;
      case StockfishState.disposed:
      case StockfishState.error:
        color = Colors.red;
        break;
      case StockfishState.starting:
        color = Colors.orange;
    }
    return Icon(MdiIcons.circle, color: color);
  }

  /// @name: initState
  /// @desc: inititalisation of the game widget
  /// @param: none
  /// @return: none
  @override
  void initState() {
    playerMove = "";
    _chess = chesslib.Chess.fromFEN(chesslib.Chess.DEFAULT_POSITION);
    _boardColors = ChessBoardColors()
      ..lightSquaresColor = Color.fromARGB(255, 227, 211, 162)
      ..darkSquaresColor = Color.fromARGB(255, 114, 90, 33)
      ..coordinatesZoneColor = Color.fromARGB(255, 66, 44, 12)
      ..lastMoveArrowColor = Colors.cyan
      ..startSquareColor = Colors.orange
      ..endSquareColor = Colors.green
      ..circularProgressBarColor = Color.fromARGB(255, 250, 149, 27)
      ..coordinatesColor = Color.fromARGB(255, 227, 211, 162);

    playerTurn = (widget.playerColor == true &&
        widget.modeSelect != gameModes_t.COMPUTERVSCOMPUTER &&
        widget.modeSelect != gameModes_t.COMPUTERVSBOARD);

    if (gameMode != gameMode_t.computerVsComputer &&
        gameMode != gameMode_t.playerVsComputer) {
      startGame(widget.playerColor ? 0 : 1);
    } else {
      startGame(3); //start game but board is only passive and reproduce moves
    }
    switch (gameModes_t.values[widget.modeSelect]) {
      case gameModes_t.PLAYERVSCOMPUTER:
        stockfish = Stockfish();
        _doStartStockfish();
        playerTurn = (widget.playerColor == true);
        if (!playerTurn) {
          _fenController.text = _chess.generate_fen();
          _computeNextMove();
        }
        break;
      case gameModes_t.COMPUTERVSBOARD:
        stockfish = Stockfish();
        _doStartStockfish();
        playerTurn = (widget.playerColor == false);
        if (!playerTurn) {
          _fenController.text =
              _chess.generate_fen(); //its always stockfish turn
          _computeNextMove();
          playerTurn = !playerTurn;
        } else {
          waitFirstMove();
        }
        print("start game computervsboard");
        break;
      case gameModes_t.PLAYERVSBOARD:
        playerTurn = (widget.playerColor == true);

        if (!playerTurn) {
          print("init done wait for bioard to made move");
          waitFirstMove(); //move received after init
        }
        print("start game playervsboard");
        break;
      case gameModes_t.COMPUTERVSCOMPUTER:
        stockfish = Stockfish();
        _doStartStockfish();
        _fenController.text = _chess.generate_fen(); //its always stockfish turn
        _computeNextMove();
        print("start game computervscomputer");
        print(!widget.playerColor &&
            (gameModes_t.values[widget.modeSelect] !=
                gameModes_t.COMPUTERVSCOMPUTER) &&
            (gameModes_t.values[widget.modeSelect] !=
                gameModes_t.COMPUTERVSBOARD));
        break;
      default:
    }

    super.initState();
  }

  /// @name: _getStockfishStatusIcon
  /// @desc: called every time a move is made, try to make move on the chessboard
  /// and do something depending on the game mode
  /// @param: move(ShortMove)
  /// @return: none
  void tryMakingMove({required ShortMove move}) async {
    final success = _chess.move(<String, String?>{
      'from': move.from,
      'to': move.to,
      'promotion': move.promotion?.name,
    });
    if (success) {
      if (mounted) {
        setState(() {
          waiting = true;
        });
      }

      print(move.from);
      print(move.to);
      print(move.promotion);
      _lastMoveArrowCoordinates = BoardArrow(from: move.from, to: move.to);
      playerTurn = !playerTurn;
      String moveToSend =
          move.from + move.to + pieceTypeToString(move.promotion);
      if (checkIfPossibleMove()) {
        playerMove = "";
        print("awaitboardmove");
        await waitBoardMove(moveToSend);
        print("board made move");
        print(playerMove);
        switch (gameModes_t.values[widget.modeSelect]) {
          case gameModes_t.PLAYERVSBOARD:
            print("check if promotion request");
            print(playerMove);
            while (playerMove == "" && activeGame == true) {
              print(playerMove);
              print("waiting for board move to be made...");
              setState(() {});
              await Future.delayed(const Duration(seconds: 2));
            }

            print("updating the ui for board move");
            print(playerMove);
            PieceType? promotion;
            if (playerMove[4] != '#') {
              print("promotion");
              promotion = await handlePromotion(context);
              promotion ??= PieceType.queen;
            }

            if (!playerTurn) {
              final success1 = _chess.move(<String, String?>{
                'from': playerMove.substring(0, 2),
                'to': playerMove.substring(2, 4),
                'promotion': playerMove[4] == '#' ? null : promotion?.name,
              });
              if (success1) {
                print(playerMove.substring(0, 2));
                print(playerMove.substring(2, 4));
                print(null);
                _lastMoveArrowCoordinates = BoardArrow(
                    from: playerMove.substring(0, 2),
                    to: playerMove.substring(2, 4));
                playerTurn = !playerTurn;
                if (promotion?.name != null) {
                  sendPromotionType(promotion?.name);
                }
                print("board move registered on the ui");
                playerMove = "";
                if (mounted) {
                  setState(() {
                    waiting = false;
                  });
                }
              } else if (!checkIfPossibleMove()) {
                endGame = true;
              }
            }
            break;
          case gameModes_t.COMPUTERVSBOARD:
            print("check if promotion request");
            while (playerMove == "" && activeGame == true) {
              print("waiting for board move to be made...");
              setState(() {});
              await Future.delayed(const Duration(seconds: 2));
            }
            PieceType? promotion;
            if (playerMove[4] != '#') {
              promotion = await handlePromotion(context);
              promotion ??= PieceType.queen;
            }

            final success1 = _chess.move(<String, String?>{
              'from': playerMove.substring(0, 2),
              'to': playerMove.substring(2, 4),
              'promotion': playerMove[4] == '#' ? null : promotion?.name(),
            });
            if (success1) {
              print(move.from);
              print(move.to);
              print(move.promotion);
              _lastMoveArrowCoordinates = BoardArrow(
                  from: playerMove.substring(0, 2),
                  to: playerMove.substring(2, 4));
              if (promotion?.name != null) {
                sendPromotionType(promotion?.name);
              }
            } else if (!checkIfPossibleMove()) {
              print("move not possible, game is finished");
              endGame = true;
            }

            _fenController.text =
                _chess.generate_fen(); //its now stockfish turn
            _computeNextMove();

            break;
          case gameModes_t.PLAYERVSCOMPUTER:
            if (!playerTurn) {
              _fenController.text =
                  _chess.generate_fen(); //its always stockfish turn
              _computeNextMove();
            }
            break;
          case gameModes_t.COMPUTERVSCOMPUTER:
            _fenController.text =
                _chess.generate_fen(); //its always stockfish turn
            _computeNextMove();
            break;
        }
      } else {
        endGame = true;
      }
      if (mounted) {
        setState(() {
          waiting = false;
        });
      }
    } else if (!checkIfPossibleMove()) {
      endGame = true;
    }

    if (endGame == true || !checkIfPossibleMove()) {
      print("endgame");
      endGame = false;
      endGameDialog(context);
      //endBoardGame();
    }
  }

  /// @name: build
  /// @desc: build the widget
  /// @param: context(BuildContext)
  /// @return: the widget to be shown(Widget)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Play page"),
      ),
      body: Center(
        child: SimpleChessBoard(
            engineThinking: waiting,
            fen: _chess.fen,
            onMove: tryMakingMove,
            chessBoardColors: _boardColors,
            blackSideAtBottom: !widget.playerColor,
            whitePlayerType: (widget.playerColor &&
                    (gameModes_t.values[widget.modeSelect] !=
                        gameModes_t.COMPUTERVSCOMPUTER) &&
                    (gameModes_t.values[widget.modeSelect] !=
                        gameModes_t.COMPUTERVSBOARD))
                ? PlayerType.human
                : PlayerType.computer,
            blackPlayerType: !widget.playerColor &&
                    (gameModes_t.values[widget.modeSelect] !=
                        gameModes_t.COMPUTERVSCOMPUTER) &&
                    (gameModes_t.values[widget.modeSelect] !=
                        gameModes_t.COMPUTERVSBOARD)
                ? PlayerType.human
                : PlayerType.computer,
            lastMoveToHighlight: _lastMoveArrowCoordinates,
            onPromote: () => handlePromotion(context),
            onPromotionCommited: ({
              required ShortMove moveDone,
              required PieceType pieceType,
            }) {
              moveDone.promotion = pieceType;
              tryMakingMove(move: moveDone);
            }),
      ),
    );
  }
}

/// @name: getChessController
/// @desc: return the chess controller of the current game
/// @param: none
/// @return: the chess controller(Chess)
chesslib.Chess getChessController() {
  return _chess;
}

/// @name: getChessController
/// @desc: return a string wich correspond to the pieceType
/// @param: pieceType(PieceType)
/// @return: pieceType(string)
String pieceTypeToString(PieceType? pieceType) {
  if (pieceType == null) {
    return '\u0000';
  }

  switch (pieceType) {
    case PieceType.queen:
      return 'q';
    case PieceType.rook:
      return 'r';
    case PieceType.bishop:
      return 'b';
    case PieceType.knight:
      return 'k';
    default:
      return '\u0000';
  }
}
