/// @name: main.dart
/// @author: Felix Parent
/// @date: 07-05-2024
/// @version: 1.0
/// @desc: main file of the chessboard app, contains most of the widgets in the app

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:async';
import 'chessBoardScreen.dart';
import 'bluetooth.dart';
import 'package:chess/chess.dart' as chesslib;

import 'package:shared_preferences/shared_preferences.dart';

List<int> dataRx = [];
List<int> checksumRx = [];
int cmdId = -1;
int cmdSize = -1;
String lastValue = "";
final Future<SharedPreferences> _prefs = SharedPreferences.getInstance();

/// @name: main
/// @desc: run main application
/// @param: no param
/// @return: no return
void main() {
  runApp(const MyApp());
}

/// @name: Myapp
/// @desc: main app class
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chessmatic',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const MyHomePage(title: 'Échec et Mat'),
    );
  }
}

/// @name: MyHomePage
/// @desc: homme page class
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  int currentPageIndex = 0;
  int _selectedIndex = 0;

  String inputValue = '';
  //
  void initBluetooth() {
    connectionStateSubscription =
        chessBoard.connectionState.listen((state) async {
      await Future.delayed(const Duration(milliseconds: 100));
      connectionState = state;
      if (state == BluetoothConnectionState.connected && mounted) {
        writeChessBoardData("hello world");
        characteristic.setNotifyValue(true); // Subscribe to notifications

        readSubscription = characteristic.onValueReceived.listen((value) {
          String str = String.fromCharCodes(value);
          if (str != lastValue) {
            lastValue = str;
            print('Received value: $str');
            List<int> asciiValues = str.runes.toList();
            print(asciiValues);
            for (var c in asciiValues) {
              setState(() {
                handleRxData(c);
              });
            }
          }
        });
        //to do when connected
        setState(() {});
        print('Connected!');
      } else if (state == BluetoothConnectionState.disconnected && mounted) {
        setState(() {});
        await Future.delayed(const Duration(milliseconds: 2000));
        try {
          await chessBoard.connect();
        } catch (e) {
          print("error");
        } finally {
          print('Finally block executed');
        }

        //print("error connecting");
        //}*/
        setState(() {});
        print('Trying to connect to the device...');
      } else if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void initState() {
    super.initState();
    print(deviceAdressTag);
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: const Text('Enter new MAC address'),
          actions: [
            TextField(
              onChanged: (value) {
                setState(() {
                  inputValue = value;
                });
              },
              decoration: const InputDecoration(
                hintText: 'Enter MAC Adress:',
              ),
            ),
            TextButton(
              onPressed: () async {
                final SharedPreferences prefs = await _prefs;
                await changeMacAdress(prefs.getString('macAdress'));

                setState(() {});
                Navigator.pop(context);
                chessBoard = BluetoothDevice(
                    remoteId: DeviceIdentifier(deviceAdressTag));
                characteristic = BluetoothCharacteristic(
                    remoteId: chessBoard.remoteId,
                    serviceUuid: Guid("b2bbc642-46da-11ed-b878-0242ac120002"),
                    characteristicUuid:
                        Guid("c9af9c76-46de-11ed-b878-0242ac120002"));
                initBluetooth();
                setState(() {});
                print(deviceAdressTag);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                await changeMacAdress(inputValue);
                Navigator.pop(context);
                chessBoard = BluetoothDevice(
                    remoteId: DeviceIdentifier(deviceAdressTag));
                characteristic = BluetoothCharacteristic(
                    remoteId: chessBoard.remoteId,
                    serviceUuid: Guid("b2bbc642-46da-11ed-b878-0242ac120002"),
                    characteristicUuid:
                        Guid("c9af9c76-46de-11ed-b878-0242ac120002"));
                initBluetooth();
                setState(() {});
              },
              child: const Text('Change'),
            ),
          ],
        ),
      );
    });
  }

  @override
  void dispose() {
    connectionStateSubscription.cancel();
    readSubscription.cancel();
    super.dispose();
  }

  //not used
  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  /// @name: _onItemTapped
  /// @desc: change page index when navbar item is tapped
  /// @param: index of the page
  /// @return: no return
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  static const TextStyle optionStyle =
      TextStyle(fontSize: 30, fontWeight: FontWeight.bold);

  static final List<Widget> _widgetOptions = <Widget>[
    const PageHome(),
    const PageLeds(),
    const PageStartGame(),
    const PageDebug(),
    const PageConnect(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ChessMatic',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        backgroundColor: Colors.deepPurple[800],
        centerTitle: true,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.attractions),
            label: 'Motors',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.lightbulb_outline),
            label: 'Leds',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.games),
            label: 'Play',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bug_report),
            label: 'Debug',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.purple[800],
        unselectedItemColor: Colors.grey,
        onTap: _onItemTapped,
      ),
      body: Center(
        child: connectionState == BluetoothConnectionState.connected
            ? _widgetOptions.elementAt(_selectedIndex)
            : _widgetOptions.elementAt(4),
      ),
    );
  }
}

/// @name: PageHome
/// @desc: home page widget
class PageHome extends StatefulWidget {
  const PageHome({super.key});

  @override
  PageHomeState createState() => PageHomeState();
}

class PageHomeState extends State<PageHome> {
  int sliderValue = 0;
  int sliderValue2 = 0;
  int selectedMotor = 0;
  @override
  Widget build(BuildContext context) {
    return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
          const Text(
            'Contrôle des moteurs',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Radio(
                value: 0,
                groupValue: selectedMotor,
                onChanged: (value) {
                  setState(() {
                    selectedMotor = value!;
                  });
                },
              ),
              Text("Moteur 1"),
              const SizedBox(width: 50),
              Radio(
                value: 1,
                groupValue: selectedMotor,
                onChanged: (value) {
                  setState(() {
                    selectedMotor = value!;
                  });
                },
              ),
              Text("Moteur 2"),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  setMotors(selectedMotor == 0 ? true : false, false);
                },
                child: const Text('ON'),
              ),
              const SizedBox(
                  width: 90), // Add spacing between buttons (optional)
              ElevatedButton(
                onPressed: () {
                  setMotors(selectedMotor == 0 ? true : false, true);
                },
                child: const Text('OFF'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  setMotorDirection(selectedMotor == 0 ? true : false, true);
                },
                child: const Text('FORWARD'),
              ),
              const SizedBox(width: 40),
              ElevatedButton(
                onPressed: () {
                  setMotorDirection(selectedMotor == 0 ? true : false, false);
                },
                child: const Text('REVERSE'),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Slider(
            value: sliderValue.toDouble(),
            max: 100,
            divisions: 10,
            label: sliderValue.round().toString(),
            onChanged: (double value) {
              setState(() {
                sliderValue = value.round();
              });
            },
          ),
          ElevatedButton(
            onPressed: () {
              setMotorSpeed(selectedMotor == 0 ? true : false, sliderValue);
            },
            child: const Text('Set speed'),
          ),
          const SizedBox(width: 10),
          Slider(
            value: sliderValue2.toDouble(),
            max: 100,
            divisions: 10,
            label: sliderValue2.round().toString(),
            onChanged: (double value) {
              setState(() {
                sliderValue2 = value.round();
              });
            },
          ),
          ElevatedButton(
            onPressed: () {
              setMotorStep(selectedMotor == 0 ? true : false, sliderValue2);
            },
            child: const Text('Set steps'),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () {
              calibrate();
            },
            child: const Text('Calibrate'),
          ),
          const SizedBox(width: 10),
          const Text(
            "Contrôle de l'aimant",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  setAimant(true);
                },
                child: const Text('ON'),
              ),
              const SizedBox(width: 40),
              ElevatedButton(
                onPressed: () {
                  setAimant(false);
                },
                child: const Text('OFF'),
              ),
            ],
          ),
        ]));
  }
}

/// @name: PageStartGame
/// @desc: start game page
class PageStartGame extends StatefulWidget {
  const PageStartGame({super.key});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<PageStartGame> {
  int selectedColor = 1;
  int selectedDifficulty = 1;
  int selectedMode = 1;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Game Mode',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            RadioListTile<int>(
              title: const Text('Computer vs Computer'),
              value: 0,
              groupValue: selectedMode,
              onChanged: (value) {
                setState(() {
                  selectedMode = value!;
                  gameMode = gameMode_t.computerVsComputer;
                });
              },
            ),
            RadioListTile<int>(
              title: const Text('Player vs Computer'),
              value: 1,
              groupValue: selectedMode,
              onChanged: (value) {
                setState(() {
                  selectedMode = value!;
                  gameMode = gameMode_t.playerVsComputer;
                });
              },
            ),
            RadioListTile<int>(
              title: const Text('Player vs Board'),
              value: 2,
              groupValue: selectedMode,
              onChanged: (value) {
                setState(() {
                  selectedMode = value!;
                  gameMode = gameMode_t.playerVsBoard;
                });
              },
            ),
            RadioListTile<int>(
              title: const Text('Computer vs Board'),
              value: 3,
              groupValue: selectedMode,
              onChanged: (value) {
                setState(() {
                  selectedMode = value!;
                  gameMode = gameMode_t.computerVsBoard;
                });
              },
            ),
            Visibility(
                visible: selectedMode == 1,
                child: const Text('Player Color',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            Visibility(
                visible: selectedMode == 1,
                child: RadioListTile<int>(
                  title: const Text('White'),
                  value: 0,
                  groupValue: selectedColor,
                  onChanged: (value) {
                    setState(() {
                      selectedColor = value!;
                    });
                  },
                )),
            Visibility(
                visible: selectedMode == 1,
                child: RadioListTile<int>(
                  title: const Text('Black'),
                  value: 1,
                  groupValue: selectedColor,
                  onChanged: (value) {
                    setState(() {
                      selectedColor = value!;
                    });
                  },
                )),
            Visibility(
                visible: selectedMode == 2 || selectedMode == 3,
                child: const Text('Board Color',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
            Visibility(
                visible: selectedMode == 2 || selectedMode == 3,
                child: RadioListTile<int>(
                  title: const Text('White'),
                  value: 1,
                  groupValue: selectedColor,
                  onChanged: (value) {
                    setState(() {
                      selectedColor = value!;
                    });
                  },
                )),
            Visibility(
                visible: selectedMode == 2 || selectedMode == 3,
                child: RadioListTile<int>(
                  title: const Text('Black'),
                  value: 0,
                  groupValue: selectedColor,
                  onChanged: (value) {
                    setState(() {
                      selectedColor = value!;
                    });
                  },
                )),

            Visibility(
                visible: selectedMode != 2,
                child: const Text('Computer Level')),
            Visibility(
              visible: selectedMode != 2,
              child: Slider(
                value: selectedDifficulty.toDouble(),
                max: 20,
                divisions: 20,
                label: selectedDifficulty.round().toString(),
                onChanged: (double value) {
                  setState(() {
                    selectedDifficulty = value.round();
                  });
                },
              ),
            ),

            ElevatedButton(
              onPressed: () {
                if (connectionState == BluetoothConnectionState.connected) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PagePlay(
                          playerColor: selectedColor == 0,
                          difficulty: selectedDifficulty,
                          modeSelect: selectedMode),
                    ),
                  );
                }
              },
              child: const Text('Start Game'),
            )
            // Add your settings widgets here
          ],
        ),
      ),
    );
  }
}

/// @name: connect page
/// @desc: page that show uo when board is not connected
class PageConnect extends StatefulWidget {
  const PageConnect({super.key});

  @override
  ConnectPageState createState() => ConnectPageState();
}

class ConnectPageState extends State<PageConnect> {
  @override
  void dispose() {
    super.dispose();
  }

  String textFieldValue = "";
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Center(
              child: Text(
                'Board not connected',
                style: TextStyle(fontSize: 24),
                textAlign: TextAlign.center,
              ),
            ),
            Center(
              child: Text(
                'Please make sure its powered, close to the device and that bluetooth is activated',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// @name: PageLeds
/// @desc: control led page
class PageLeds extends StatefulWidget {
  const PageLeds({super.key});

  @override
  PageLedsState createState() => PageLedsState();
}

class PageLedsState extends State<PageLeds> {
  @override
  void dispose() {
    super.dispose();
  }

  Color ledColor = Colors.red;
  int selectedEffect = 0;
  int selectedSpeed = 0;
  String sliderText = "Slow";
  @override
  Widget build(BuildContext context) {
    return Center(
        child: SingleChildScrollView(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
          const Text(
            'Contrôle des leds',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 30),
          const Text('Effects',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          Table(
            children: [
              TableRow(
                children: [
                  Row(
                    children: [
                      Radio(
                        value: 0,
                        groupValue: selectedEffect,
                        onChanged: (value) {
                          setState(() {
                            selectedEffect = value!;
                          });
                        },
                      ),
                      Text("Static"),
                    ],
                  ),
                  Row(
                    children: [
                      Radio(
                        value: 1,
                        groupValue: selectedEffect,
                        onChanged: (value) {
                          setState(() {
                            selectedEffect = value!;
                          });
                        },
                      ),
                      Text("Snake"),
                    ],
                  ),
                ],
              ),
              TableRow(
                children: [
                  Row(
                    children: [
                      Radio(
                        value: 2,
                        groupValue: selectedEffect,
                        onChanged: (value) {
                          setState(() {
                            selectedEffect = value!;
                          });
                        },
                      ),
                      Text("Stars"),
                    ],
                  ),
                  Row(
                    children: [
                      Radio(
                        value: 3,
                        groupValue: selectedEffect,
                        onChanged: (value) {
                          setState(() {
                            selectedEffect = value!;
                          });
                        },
                      ),
                      Text("Rainbow"),
                    ],
                  ),
                ],
              ),
              TableRow(
                children: [
                  Row(
                    children: [
                      Radio(
                        value: 4,
                        groupValue: selectedEffect,
                        onChanged: (value) {
                          setState(() {
                            selectedEffect = value!;
                          });
                        },
                      ),
                      Text("Waves"),
                    ],
                  ),
                  Row(
                    children: [
                      Radio(
                        value: 5,
                        groupValue: selectedEffect,
                        onChanged: (value) {
                          setState(() {
                            selectedEffect = value!;
                          });
                        },
                      ),
                      Text("Scan"),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Effect Color',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ColorPicker(
            pickerColor: Colors.red,
            enableAlpha: false,
            onColorChanged: (Color color) {
              ledColor = color;
              print(color);
            },
          ),
          const SizedBox(width: 10),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              String effect = "solid";
              int white = 0;
              if (selectedEffect == 0) {
                effect = "solid:64;1;" +
                    ledColor.red.toString() +
                    ";" +
                    ledColor.green.toString() +
                    ";" +
                    ledColor.blue.toString() +
                    ";0";
              } else if (selectedEffect == 1) {
                effect = "snake";
              } else if (selectedEffect == 2) {
                effect = "stars:64;1;99000;10;" +
                    ledColor.red.toString() +
                    ";" +
                    ledColor.green.toString() +
                    ";" +
                    ledColor.blue.toString() +
                    ";0";
              } else if (selectedEffect == 3) {
                effect = "rainbow";
              } else if (selectedEffect == 4) {
                effect = "police";
              } else if (selectedEffect == 5) {
                effect = "static";
              }
              print(effect);
              print(ledColor.red);
              print(ledColor.green);
              print(ledColor.blue);
              print(selectedSpeed);
              setRGBEffect(true, ledColor.red, ledColor.green, ledColor.blue,
                  selectedSpeed, effect);
            },
            child: const Text('Set Leds'),
          ),
        ])));
  }
}

/// @name: PageDebug
/// @desc: page to test command and other features(not used yet)
class PageDebug extends StatefulWidget {
  const PageDebug({super.key});

  @override
  PageDebugState createState() => PageDebugState();
}

class PageDebugState extends State<PageDebug> {
  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
                'Debug page. Put here commands to manually send to the chess board to facilitate debugging',
                style: TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

/// @name: sendMovesFromPosition
/// @desc: send possible moves to the esp32
/// @param:position(string)
/// @return: no return
void sendMovesFromPosition(String position) {
  print("Possible moves sent to esp32");
  chesslib.Chess chess = getChessController();
  List<chesslib.Move> possibleMoves = chess.generate_moves();
  List<String> movesFromPosition = [];
  for (var move in possibleMoves) {
    print(move.fromAlgebraic);
    if (move.fromAlgebraic == position) {
      String moveStr = move.fromAlgebraic + move.toAlgebraic;
      print(move);
      movesFromPosition.add(moveStr);
    }
  }
  if (possibleMoves.isNotEmpty) {
    sendPossibleMoves(movesFromPosition);
  }
}

/// @name: handleRxData
/// @desc: handle the reception of the bluetooth data received from the esp32
/// @param:car(int)
/// @return: no return
void handleRxData(int car) {
  bool trameValide = false;

  print(car);
  print(rxState);
  switch (rxState) {
    case rxState_t.STX:
      if (car == 60) {
        rxState = rxState_t.CMD_ID;
      }
      break;
    case rxState_t.CMD_ID:
      cmdId = car;
      checksumRx.add(car);
      rxState = rxState_t.CMD_SIZE;
      break;
    case rxState_t.CMD_SIZE:
      cmdSize = car;
      checksumRx.add(car);
      rxState = rxState_t.CMD_DATA;
      break;
    case rxState_t.CMD_DATA:
      dataRx.add(car);
      checksumRx.add(car);
      print(dataRx.length);
      print(cmdSize);
      if (dataRx.length == cmdSize) {
        rxState = rxState_t.CHECKSUM;
      }
      print(rxState);
      break;
    case rxState_t.CHECKSUM:
      if (calculateChecksum(checksumRx) != car) {
        dataRx.clear();
        rxState = rxState_t.STX;
      } else {
        rxState = rxState_t.ETX;
      }
      checksumRx.clear();

      break;
    case rxState_t.ETX:
      if (car == 62) {
        trameValide = true;
      } else {
        dataRx.clear();
      }
      rxState = rxState_t.STX;
      break;
    default:
      break;
  }
  if (trameValide) {
    switch (cmdId) {
      case 0:
        print("Game started correctly");
        break;
      case 1:
        print("Game ended correctly");
        break;
      case 2:
        if (dataRx.length == 5) {
          print("CurrentGameMode: BOARD PLAYING");
          print("Move made by board:");
          print(dataRx[0]);
          print(dataRx[1]);
          print(dataRx[2]);
          print(dataRx[3]);
          print(dataRx[4]);
          playerMove = "";

          playerMove = String.fromCharCode(dataRx[0]) +
              String.fromCharCode(dataRx[1]) +
              String.fromCharCode(dataRx[2]) +
              String.fromCharCode(dataRx[3]) +
              (playerMove += (dataRx[4] != 0 ? 'p' : '#'));
          print(playerMove);
        } else {
          print("CurrentGameMode: BOARD WATCHING");
        }

        break;
      case 3: //response possible moves
        String position =
            dataRx.map((value) => String.fromCharCode(value)).join('');
        print(position);
        sendMovesFromPosition(position);
        break;
      case 4:
        print("Motors has been set correctly");
        break;
      case 5:
        print("Motors has been set correctly");
        break;
      case 6:
        print("Motors has been set correctly");
        break;
      case 7:
        print("Motors has been set correctly");
        break;
      case 8:
        print("LedBoard set correctly");
      default:
        break;
    }
    receivedResponse[cmdId] = true;
    dataRx.clear();
  }
}

/// @name: changeMacAdress
/// @desc: save the new mac adress
/// @param:new macadress(string)
/// @return: future void
Future<void> changeMacAdress(String? mac) async {
  final SharedPreferences prefs = await _prefs;
  if (mac != null) {
    deviceAdressTag =
        await prefs.setString('macAdress', mac).then((bool success) {
      return mac;
    });
  }
  print(deviceAdressTag);
}
