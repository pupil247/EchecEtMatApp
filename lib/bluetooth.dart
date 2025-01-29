
/// @name: bluetooth.dart
/// @author: Felix Parent
/// @date: 07-05-2024
/// @version: 1.0
/// @desc: control the bluetooth communication with the esp32

import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'dart:convert';
import 'package:chess/chess.dart' as chesslib;
import 'package:flutter/material.dart';
import 'dart:async';

enum gameMode_t {
  computerVsComputer,
  playerVsComputer,
  playerVsBoard,
  computerVsBoard
}

enum rxState_t { STX, CMD_ID, CMD_SIZE, CMD_DATA, CHECKSUM, ETX }

//Global variables used by Bluetooth
String deviceAdressTag = "";
String playerMove = "";
BluetoothConnectionState connectionState =
    BluetoothConnectionState.disconnected;
late StreamSubscription<BluetoothConnectionState> connectionStateSubscription;
late StreamSubscription<List<int>> readSubscription;
late StreamSubscription scanResultSubscription;
late BluetoothDevice chessBoard;
late BluetoothCharacteristic characteristic;

List<bool> receivedResponse = [
  false,
  false,
  false,
  false,
  false,
  false,
  false,
  false,
  false,
  false
];

bool activeGame = false;
bool waitForBoardMovement = false;
gameMode_t gameMode = gameMode_t.computerVsComputer;
rxState_t rxState = rxState_t.STX;

/// @name: getChessBoardState
/// @desc: read the bluetooth caracteristic
/// @param: no param
/// @return: caracteristic content
Future<String> getChessBoardState() async {
  List<BluetoothService> services = await chessBoard.discoverServices();
  String data = "";
  for (BluetoothService s in services) {
    if (s.serviceUuid == "b2bbc642-46da-11ed-b878-0242ac120002") {
      List<BluetoothCharacteristic> characteristic = s.characteristics;
      for (BluetoothCharacteristic c in characteristic) {
        if (c.characteristicUuid == "c9af9c76-46de-11ed-b878-0242ac120002") {
          data = String.fromCharCodes(await c.read());
        }
      }
    }
  }
  return data;
}

/// @name: writeChessBoardData
/// @desc: write on the bluetooth caracteristic
/// @param: data to write(string)
/// @return: success(bool)
Future<bool> writeChessBoardData(String data) async {
  print("writing chess board data");
  bool alreadySent = false;
  List<BluetoothService> services = await chessBoard.discoverServices();
  print("services found");
  List<int> dataToSend = [];
  for (int i = 0; i < data.length; i++) {
    dataToSend.add(data.codeUnitAt(i));
  }
  String car = '~';
  dataToSend.add(car.codeUnitAt(0));
  for (BluetoothService s in services) {
    if ((s.serviceUuid).toString() == "b2bbc642-46da-11ed-b878-0242ac120002") {
      List<BluetoothCharacteristic> characteristic = s.characteristics;
      for (BluetoothCharacteristic c in characteristic) {
        if (c.characteristicUuid.toString() ==
                "c9af9c76-46de-11ed-b878-0242ac120002" &&
            !alreadySent) {
          alreadySent = true;
          await c.write(dataToSend);
          print("data sent to esp32");
          print(dataToSend);
          return true;
        }
      }
    }
  }
  return false;
}

/** ----------------------------------------------------**/
/** This section contains the commands to send to esp32 **/
/** ----------------------------------------------------**/

/// 0 - Start game *
/// @name: startGame
/// @desc: start the chessboard game on the esp32
/// @param: board color
/// @return: success(bool)
Future<bool> startGame(int boardColor) async {
  activeGame = true;
  bool success = false;
  int index = 0;
  int color = boardColor;
  List<int> data = [0, 1, color];
  int checksum = calculateChecksum(data);
  data.insert(0, 60);
  data.add(checksum);
  data.add(62);
  success = await writeChessBoardData(String.fromCharCodes(data));
  //wait for response
  while (receivedResponse[0] == false && index < 5) {
    //wait five minutes or else assume the board is not responsive and end game
    await Future.delayed(const Duration(milliseconds: 2000));
    index++;
  }
  if (receivedResponse[0] == true) {
    print("GAME HAS STARTED CORRECTLY");
    success = true;
    receivedResponse[0] = false;
  } else
    print("ERROR GAME START");
  return success;
}

/// 1 - End game *
/// @name: endBoardGame
/// @desc: end the chessboard game on the esp32
/// @param: no param
/// @return: success(bool)
Future<bool> endBoardGame() async {
  activeGame = false;
  bool success = false;
  List<int> data = [1, 0];
  int checksum = calculateChecksum(data);
  data.insert(0, 60);
  data.add(checksum);
  data.add(62);
  success = await writeChessBoardData(String.fromCharCodes(data));
  return success;
}

/// 2 - Wait for Board move
/// @name: waitBoardMove
/// @desc: send the last move maade on the app and
/// wait for the board to respond with his move
/// @param: move to send(string)
/// @return: success(bool)
Future<bool> waitBoardMove(String move) async {
  bool success = false;
  int index = 0;
  List<int> data = [2, 5];
  List<int> moveCar = move.runes.toList();
  for (var number in moveCar) {
    data.add(number);
  }
  int checksum = calculateChecksum(data);
  data.insert(0, 60);
  data.add(checksum);
  data.add(62);
  print(data);

  //wait for response
  receivedResponse[2] = false;
  while (receivedResponse[2] == false && activeGame == true && index < 100) {
    //wait five minutes or else assume the board is not responsive and end game
    print("waiting for response...");
    if ((index % 10) == 0) {
      success = await writeChessBoardData(String.fromCharCodes(data));
    }
    if (receivedResponse[2] == false) {
      await Future.delayed(const Duration(seconds: 1));
    }
    index++;
  }
  if (receivedResponse[2] == true) {
    //playerMove = move;
    print("MOVE HAVE BEEN MADE CORRECTLY");
    success = true;
    receivedResponse[2] = false;
  } else
    print("ERROR MOVE FAILED");
  return success;
}

/// 3 - Send Possible Moves
/// @name: startGame
/// @desc: This function trigger on a request by the esp32
/// send every move possible for a certain piece
/// @param: possible moves(list of string)
/// @return: success(bool)
Future<bool> sendPossibleMoves(List<String> moves) async {
  bool success = false;
  List<int> data = [3, moves.length * 4];
  List<int> tmp = [];
  for (var move in moves) {
    print(move);
    tmp = move.runes.toList();
    for (var number in tmp) {
      data.add(number);
    }
    tmp.clear();
  }
  print(data);
  int checksum = calculateChecksum(data);
  data.insert(0, 60);
  data.add(checksum);
  data.add(62);
  print(data);
  success = await writeChessBoardData(String.fromCharCodes(data));
  await Future.delayed(const Duration(milliseconds: 500));
  return success; //doesn't need to wait for response for this command
}

/// 4 - Set Motors
/// @name: setMotors
/// @desc: set motor 1 or 2 on or off
/// @param: selected motor(bool), on or off(bool)
/// @return: success(bool)
Future<bool> setMotors(bool selectedMotor, bool onOff) async {
  bool success = false;
  int status = onOff ? 1 : 0;
  int motor = selectedMotor ? 1 : 0;
  int index = 0;
  List<int> data = [4, 2, motor, status];
  int checksum = calculateChecksum(data);
  data.insert(0, 60);
  data.add(checksum);
  data.add(62);
  print(data);
  await writeChessBoardData(String.fromCharCodes(data));

  //wait for response
  while (receivedResponse[4] == false && index < 4) {
    await Future.delayed(const Duration(milliseconds: 1000));
    index++;
  }
  if (receivedResponse[4] == true) {
    print("SET MOTOR SUCCESS");
    success = true;
    receivedResponse[4] = false;
  } else
    print("SET MOTOR FAILED");
  return success;
}

/// 5 - Set Motor Speed
/// @name: setMotorSpeed
/// @desc: set the speed of one of the two motors
/// @param: selectedMotor(bool), speed of the motor 0 to 100(int)
/// @return: success(bool)
Future<bool> setMotorSpeed(bool selectedMotor, int speed) async {
  bool success = false;
  int index = 0;
  int motor = selectedMotor ? 1 : 0;
  List<int> data = [5, 2, motor, speed];
  int checksum = calculateChecksum(data);
  data.insert(0, 60);
  data.add(checksum);
  data.add(62);
  success = await writeChessBoardData(String.fromCharCodes(data));

  //wait for response
  while (receivedResponse[5] == false && index < 4) {
    await Future.delayed(const Duration(milliseconds: 1000));
    index++;
  }
  if (receivedResponse[5] == true) {
    print("SET MOTOR SPEED SUCCESS");
    success = true;
    receivedResponse[5] = false;
  } else
    print("SET MOTOR SPEED FAILED");
  return success;
}

/// 6 - Set motor position
/// @name: setMotorPosition
/// @desc: set motor position (not working)
/// @param: positionx, positiony
/// @return: success(bool)
Future<bool> setMotorPosition(int x, int y) async {
  bool success = false;
  int index = 0;
  List<int> data = [6, 2, x, y];
  int checksum = calculateChecksum(data);
  data.insert(0, 60);
  data.add(checksum);
  data.add(62);
  success = await writeChessBoardData(String.fromCharCodes(data));

  //wait for response
  while (receivedResponse[6] == false && index < 4) {
    await Future.delayed(const Duration(milliseconds: 1000));
    index++;
  }
  if (receivedResponse[6] == true) {
    print("SET MOTOR POSITION SUCCESS");
    success = true;
    receivedResponse[6] = false;
  } else
    print("SET MOTOR POSITION FAILED");
  return success;
}

/// 7 - Set Motor Direction
/// @name: setMotorDirection
/// @desc: set the direction of one of the two motors
/// @param: selectedMotor(bool), direction of the motor forward or reverse(bool)
/// @return: success(bool)
Future<bool> setMotorDirection(bool selectedMotor, bool direction) async {
  bool success = false;
  int status = direction ? 1 : 0;
  int motor = selectedMotor ? 1 : 0;
  int index = 0;
  List<int> data = [7, 2, motor, status];
  int checksum = calculateChecksum(data);
  data.insert(0, 60);
  data.add(checksum);
  data.add(62);
  print(data);
  await writeChessBoardData(String.fromCharCodes(data));

  //wait for response
  while (receivedResponse[7] == false && index < 4) {
    await Future.delayed(const Duration(milliseconds: 1000));
    index++;
  }
  if (receivedResponse[7] == true) {
    print("SET MOTOR DIRECTION SUCCESS");
    success = true;
    receivedResponse[7] = false;
  } else
    print("SET MOTOR DIRECTION FAILED");
  return success;
}

/// 8 - Set Led Board
/// @name: setRGBEffect
/// @desc: set the effect of the leadboard and control on off
/// @param: onOff(bool), red(int), green(int), blue(int), effect name(string), effectspeed(string)
/// @return: success(bool)
Future<bool> setRGBEffect(bool onOff, int red, int green, int blue,
    int speedEffect, String effect) async {
  bool success = false;
  int index = 0;
  int status = onOff ? 1 : 0;
  print(red);
  List<int> data = [8, effect.length];
  List<int> effectCar = effect.runes.toList();
  for (var number in effectCar) {
    data.add(number);
  }
  int checksum = calculateChecksum(data);
  data.insert(0, 60);
  data.add(checksum);
  data.add(62);
  print(data);
  await writeChessBoardData(String.fromCharCodes(data));

  //wait for response
  while (receivedResponse[8] == false && index < 4) {
    await Future.delayed(const Duration(milliseconds: 1000));
    index++;
  }
  if (receivedResponse[8] == true) {
    print("LEDBOARD SET CORRECTLY");
    success = true;
    receivedResponse[8] = false;
  } else
    print("LEDBOARD ERROR SET");
  return success;
}

/// 9 - Send Promotion
/// @name: sendPromotionType
/// @desc: this function triggers on a request by the esp32
/// send the chosen piece type for promotion
/// @param: piece type(string)
/// @return: success(bool)
Future<bool> sendPromotionType(String type) async {
  bool success = false;

  List<int> data = [9, 1, type.codeUnitAt(0)];
  int checksum = calculateChecksum(data);
  data.insert(0, 60);
  data.add(checksum);
  data.add(62);
  print(data);
  success = await writeChessBoardData(String.fromCharCodes(data));
  return success;
}

/// 10 - Calibrate *
Future<bool> calibrate() async {
  bool success = false;

  List<int> data = [10, 1, 0];
  int checksum = calculateChecksum(data);
  data.insert(0, 60);
  data.add(checksum);
  data.add(62);
  print(data);
  success = await writeChessBoardData(String.fromCharCodes(data));
  return success;
}

/// 11 - Set Motor Step
/// @name: setMotorStep
/// @desc: set the steps of one of the two motors
/// @param: selectedMotor(bool), steps of the motor(int)
/// @return: success(bool)
Future<bool> setMotorStep(bool selectedMotor, int step) async {
  bool success = false;
  int index = 0;
  int motor = selectedMotor ? 1 : 0;
  List<int> data = [11, 2, motor, step];
  int checksum = calculateChecksum(data);
  data.insert(0, 60);
  data.add(checksum);
  data.add(62);
  success = await writeChessBoardData(String.fromCharCodes(data));

  return success;
}

/// 11 - Set Aimant
/// @name: setAimant
/// @desc: turn on or off the magnet
/// @param: onOff(bool)
/// @return: success(bool)
Future<bool> setAimant(bool onOff) async {
  bool success = false;
  int state = onOff ? 1 : 0;
  List<int> data = [12, 1, state];
  int checksum = calculateChecksum(data);
  data.insert(0, 60);
  data.add(checksum);
  data.add(62);
  success = await writeChessBoardData(String.fromCharCodes(data));

  return success;
}
//*--------------------------------------------------------------*//

/// @name: calculateChecksum
/// @desc: calculate the checksum for command to send via bluetooth
/// @param: list, the content of the command(list<int>)
/// @return: checksum(int)
int calculateChecksum(List<int> list) {
  int tmp = 0;
  for (int i in list) {
    tmp = tmp + i;
  }
  return tmp & 0x00FF;
}
