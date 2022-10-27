//@dart=2.9
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:desktop_project/custom-text_field.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart' hide Image;
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:window_size/window_size.dart';
import 'package:http/http.dart' as http;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    setWindowTitle('LSP打印机');
    // setWindowMaxSize(const Size(1024, 768));
    setWindowMinSize(const Size(800, 600));
    // setWindowSize(Size(800, 600));
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '打印机',
      debugShowCheckedModeBanner: false,
      debugShowMaterialGrid: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String date = '';
  List<Map<String, dynamic>> originalData = [];
  String error = '';
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _ipAddressController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  bool loggedIN = false;

  void connectSocket(String userID) {
    IO.Socket socket = IO.io("http://104.239.251.124:8800", <String, dynamic>{
      "transports": ["websocket"],
    });
    socket.onConnect((_) {
      print("Socket connected:");
      //PC: true, android: false
      socket.emit("new-user-add", {
        'userId': '6346f42b20525caf88fc8574',
        'isBrowser': false,
        'socketType': 'printer'
      });
    });

    socket.on('receive-print', (data) {
      originalData.add(data);

      if (originalData.length == 1) printerData();
    });
  }

  Future<void> printDemoReceipt(NetworkPrinter printer) async {
    printer.text(
      '作分单',
      styles: PosStyles(
        // codeTable: PosCodeTable.westEur,
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
      linesAfter: 1,
      containsChinese: true,
    );
    printer.hr();
    printer.row([
      PosColumn(
          text: '（退）宮保雞丁',
          containsChinese: true,
          width: 6,
          styles: PosStyles(
            height: PosTextSize.size2,
            width: PosTextSize.size1,
          )),
      PosColumn(
          text: '\$10.97',
          width: 6,
          styles: PosStyles(
            align: PosAlign.right,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          )),
    ]);
    printer.hr(ch: '=', linesAfter: 1);

    printer.feed(1);
    printer.cut();
    printer.disconnect();
  }

  void testPrint(String printerIp, int port) async {
    // TODO Don't forget to choose printer's paper size
    const PaperSize paper = PaperSize.mm80;
    final profile = await CapabilityProfile.load();
    final printer = NetworkPrinter(paper, profile);

    final PosPrintResult res = await printer.connect(printerIp, port: port);

    if (res == PosPrintResult.success) {
      await printDemoReceipt(printer);
    }
  }

  Future<void> printerData() async {
    if (originalData.length > 0) {
      final profile = await CapabilityProfile.load();
      final now = new DateTime.now();
      String formatter = DateFormat('yyyy-MM-dd kk:mm').format(now);

      const PaperSize paper = PaperSize.mm80;
      final printer = NetworkPrinter(paper, profile, spaceBetweenRows: 3);

      //0번쨰를 뽑아와서 인쇄
      if (originalData[0]['type'] == 'production-order') {
        Model_Order mOrder = Model_Order.fromJson(originalData[0]);
        List<Model_Printer> dataPrinter = mOrder.data;
        print(dataPrinter.length);

        await Future.forEach(dataPrinter, (mPrinter) async {
          var ipPort = mPrinter.ipPort.split(":");
          String ip = ipPort[0];
          String port = ipPort[1];
          final value = await printer.connect('192.168.1.114', port: 9100);
          if (value == PosPrintResult.success) {
            print('====인쇄시작===');
            print(mPrinter.toString());
            printer.text(
              mPrinter.title,
              styles: PosStyles(
                // codeTable: PosCodeTable.westEur,
                align: PosAlign.center,
                height: PosTextSize.size2,
                width: PosTextSize.size1,
              ),
              linesAfter: 1,
              containsChinese: true,
            );
            Future.delayed(Duration(milliseconds: 300), () {
              printer.text(
                '桌号； ${mPrinter.address}',
                styles: PosStyles(
                  height: PosTextSize.size2,
                  width: PosTextSize.size1,
                ),
                linesAfter: 1,
                containsChinese: true,
              );
            });
            Future.delayed(Duration(milliseconds: 300), () {
              printer.row([
                PosColumn(text: ' 菜品', containsChinese: true, width: 6),
                PosColumn(
                  text: '数量',
                  containsChinese: true,
                  // textEncoded: Uint8List.fromList(utf8.encode('你好')),
                  width: 6,
                  styles: PosStyles(
                    align: PosAlign.right,
                  ),
                ),
              ]);
            });
            Future.delayed(Duration(milliseconds: 300), () {
              printer.hr();
              printer.row([
                PosColumn(
                  text:
                      '${mPrinter.name.replaceAll("(", "）").replaceAll(")", "）")}',
                  containsChinese: true,
                  width: 6,
                  styles: PosStyles(
                    height: PosTextSize.size2,
                    width: PosTextSize.size1,
                  ),
                ),
                PosColumn(
                  text: '${mPrinter.volume}/  ${mPrinter.unit}',
                  containsChinese: true,
                  // textEncoded: Uint8List.fromList(utf8.encode('你好')),
                  width: 6,
                  styles: PosStyles(
                    align: PosAlign.right,
                    height: PosTextSize.size2,
                    width: PosTextSize.size1,
                  ),
                ),
              ]);
            });
            Future.delayed(Duration(milliseconds: 300), () {
              if (mPrinter.note != null) {
                printer.text(
                  mPrinter.note,
                  styles: PosStyles(
                    align: PosAlign.left,
                  ),
                  linesAfter: 1,
                  containsChinese: true,
                );
              }

              printer.hr();
              printer.text(
                '时间: ' + formatter,
                styles: PosStyles(
                  align: PosAlign.left,
                ),
                linesAfter: 1,
                containsChinese: true,
              );
            });

            printer.feed(1);
            printer.cut();
            printer.disconnect(delayMs: 500);
          }
        });
        print('========33333333333====');

        Future.delayed(Duration(seconds: 3), () {
          originalData.removeAt(0);
          if (originalData.length > 0) {
            print("========4444444444444========");
            printerData();
          }
        });
      } else {
        Model_Checkout mCheckout = Model_Checkout.fromJson(originalData[0]);
        Model_Checkout_Item checkData =
            Model_Checkout_Item.fromJson(mCheckout.data);

        await printer.connect('192.168.1.114', port: 9100).then((value) {
          if (value == PosPrintResult.scanInProgress ||
              value == PosPrintResult.printInProgress) {
            print('Sleeep....');
            sleep(Duration(seconds: 1));
          }

          if (value == PosPrintResult.success) {
            printer.text(
              '预结单',
              styles: PosStyles(
                // codeTable: PosCodeTable.westEur,
                align: PosAlign.center,
                height: PosTextSize.size2,
                width: PosTextSize.size2,
              ),
              linesAfter: 1,
              containsChinese: true,
            );
            printer.text(
              checkData.restaurantName,
              styles: PosStyles(
                // codeTable: PosCodeTable.westEur,
                align: PosAlign.center,
                height: PosTextSize.size2,
                width: PosTextSize.size2,
              ),
              linesAfter: 1,
              containsChinese: true,
            );
            printer.hr();
            printer.text(
              '桌号； ${checkData.layerName}-${checkData.roomName}',
              styles: PosStyles(
                height: PosTextSize.size2,
                width: PosTextSize.size2,
              ),
              linesAfter: 1,
              containsChinese: true,
            );

            printer.feed(1);
            printer.text(
              '人数: ${checkData.people}',
              styles: PosStyles(
                align: PosAlign.left,
              ),
              linesAfter: 1,
              containsChinese: true,
            );
            printer.row([
              PosColumn(
                text: '菜品',
                containsChinese: true,
                width: 6,
              ),
              PosColumn(
                text: '数量',
                containsChinese: true,
                width: 2,
                styles: PosStyles(
                  align: PosAlign.right,
                ),
              ),
              PosColumn(
                text: '小计',
                containsChinese: true,
                width: 2,
                styles: PosStyles(
                  align: PosAlign.right,
                ),
              ),
              PosColumn(
                text: '优惠价',
                containsChinese: true,
                width: 2,
                styles: PosStyles(
                  align: PosAlign.right,
                ),
              ),
            ]);
            List<Model_Checkout_Data> mcData = checkData.data;
            mcData.map((item) {
              printer.row([
                PosColumn(
                  text: item.name,
                  containsChinese: true,
                  width: 6,
                ),
                PosColumn(
                  text: '${item.volume}  ${item.unit}',
                  containsChinese: true,
                  width: 2,
                  styles: PosStyles(
                    align: PosAlign.right,
                  ),
                ),
                PosColumn(
                  text: '${item.price}',
                  containsChinese: true,
                  width: 2,
                  styles: PosStyles(
                    align: PosAlign.right,
                  ),
                ),
                PosColumn(
                  text: '${item.gift}',
                  containsChinese: true,
                  width: 2,
                  styles: PosStyles(
                    align: PosAlign.right,
                  ),
                ),
              ]);
            }).toList();
            printer.hr();
            printer.row([
              PosColumn(text: '菜品价格合计', containsChinese: true, width: 6),
              PosColumn(
                text: '${checkData.totalPrice}',
                containsChinese: true,
                // textEncoded: Uint8List.fromList(utf8.encode('你好')),
                width: 6,
                styles: PosStyles(
                  align: PosAlign.right,
                ),
              ),
            ]);
            printer.row([
              PosColumn(text: '打单金额', containsChinese: true, width: 6),
              PosColumn(
                text: '${checkData.totalPrice}',
                containsChinese: true,
                // textEncoded: Uint8List.fromList(utf8.encode('你好')),
                width: 6,
                styles: PosStyles(
                  align: PosAlign.right,
                ),
              ),
            ]);
            printer.text(
              '注： 其中不参与优惠的打单金额 ${checkData.totalPrice}, 参与优惠的打单金额 ${checkData.totalPrice - checkData.discount}',
              styles: PosStyles(
                align: PosAlign.left,
              ),
              containsChinese: true,
            );
            printer.hr();
            printer.row([
              PosColumn(text: '赠菜', containsChinese: true, width: 6),
              PosColumn(
                text: '${checkData.discount}',
                containsChinese: true,
                // textEncoded: Uint8List.fromList(utf8.encode('你好')),
                width: 6,
                styles: PosStyles(
                  align: PosAlign.right,
                ),
              ),
            ]);
            printer.row([
              PosColumn(
                text: '应付金额',
                containsChinese: true,
                width: 6,
                styles: PosStyles(
                  height: PosTextSize.size2,
                  width: PosTextSize.size2,
                ),
              ),
              PosColumn(
                text: '${checkData.totalPrice - checkData.discount}',
                containsChinese: true,
                // textEncoded: Uint8List.fromList(utf8.encode('你好')),
                width: 6,
                styles: PosStyles(
                  align: PosAlign.right,
                  height: PosTextSize.size2,
                  width: PosTextSize.size2,
                ),
              ),
            ]);
            printer.hr();
            printer.text(
              '下单人: ${checkData.restaurantName}',
              styles: PosStyles(
                align: PosAlign.left,
              ),
              containsChinese: true,
            );
            printer.text(
              '下单时间: ${checkData.openDate}',
              styles: PosStyles(
                align: PosAlign.left,
              ),
              containsChinese: true,
            );
            printer.text(
              '打印时间: ${checkData.closeDate}',
              styles: PosStyles(
                align: PosAlign.left,
              ),
              linesAfter: 1,
              containsChinese: true,
            );

            printer.cut();
            printer.disconnect();
          }
        }).whenComplete(() {
          originalData.removeAt(0);

          if (originalData.length > 0) printerData();
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (BuildContext context) {
          return Center(
            child: Container(
              width: 300,
              height: double.infinity,
              // decoration: const BoxDecoration(
              //   image: DecorationImage(
              //     image: AssetImage("assets/images/bg.png"),
              //     opacity: 1,
              //     fit: BoxFit.fill,
              //   ),
              // ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  loggedIN != true
                      ? customTextField(
                          hintText: "请输入电话号",
                          controller: _emailController,
                          label: "账号：",
                          isPassword: false)
                      : customTextField(
                          hintText: "请输入IP.",
                          controller: _ipAddressController,
                          label: "IP address：",
                          isPassword: false),
                  SizedBox(height: 20),
                  loggedIN != true
                      ? customTextField(
                          hintText: "请输入密码",
                          controller: _passwordController,
                          label: "密码：",
                          isPassword: true)
                      : customTextField(
                          hintText: "请输入Port.",
                          controller: _portController,
                          label: "Port number：",
                          isPassword: false),
                  SizedBox(height: 30),
                  loggedIN != true
                      ? SizedBox(
                          height: 50,
                          width: 300,
                          child: ElevatedButton(
                              child: Text('登   入'),
                              onPressed: () {
                                if (!loggedIN) {
                                  if (_emailController.text == "") {
                                    showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                              title: Text('通知'),
                                              content: Text('请输入账号。'),
                                            ));
                                  } else if (_passwordController.text == "") {
                                    showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                              title: Text('通知'),
                                              content: Text('请输入密码。'),
                                            ));
                                  } else {
                                    http
                                        .post(
                                      Uri.parse(
                                          'http://104.239.251.124:5055/api/user/login'),
                                      headers: <String, String>{
                                        'Content-Type':
                                            'application/json; charset=UTF-8',
                                      },
                                      body: jsonEncode(<String, String>{
                                        'phone': _emailController.text,
                                        'password': _passwordController.text,
                                        'type': 'printer',
                                        // 'deviceId': device
                                      }),
                                    )
                                        .then((value) {
                                      final b = json.decode(value.body);

                                      if (b['token'] != null) {
                                        setState(() {
                                          loggedIN = true;
                                        });
                                        connectSocket(b['_id']);
                                      } else {
                                        showDialog(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                                  title: Text('通知'),
                                                  content: Text('服务器的问题。'),
                                                ));
                                      }
                                    });
                                  }
                                }
                              }))
                      : SizedBox(
                          height: 50,
                          width: 300,
                          child: ElevatedButton(
                              child: Text('测试印刷'),
                              onPressed: () {
                                if (_ipAddressController.text == "") {
                                  showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                            title: Text('通知'),
                                            content:
                                                Text('请输入IP。192.168.1.115'),
                                          ));
                                } else if (_portController.text == "") {
                                  showDialog(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                            title: Text('通知'),
                                            content: Text('请输入Port。9100'),
                                          ));
                                } else {
                                  testPrint(_ipAddressController.text,
                                      int.parse(_portController.text));
                                }
                              })),
                  Text(error),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class Model_Order {
  String type;
  List<Model_Printer> data;

  Model_Order({this.type, this.data});

  factory Model_Order.fromJson(Map<String, dynamic> json) {
    return Model_Order(
        type: json['type'],
        data: List<Model_Printer>.from(
            json["data"].map((x) => Model_Printer.fromJson(x))));
  }
  @override
  String toString() {
    return '{ ${this.type}, ${this.data} }';
  }
}

class Model_Printer {
  String title;
  String address;
  String name;
  double volume;
  String unit;
  String restaurantName;
  String date;
  String ipPort;
  String note;

  Model_Printer(
      {this.title,
      this.address,
      this.name,
      this.volume,
      this.unit,
      this.restaurantName,
      this.date,
      this.ipPort,
      this.note});

  factory Model_Printer.fromJson(Map<String, dynamic> json) {
    return Model_Printer(
        title: json['title'],
        address: json['address'],
        name: json['name'],
        volume: json['volume'].toDouble(),
        unit: json['unit'],
        restaurantName: json['restaurantName'],
        date: json['date'],
        ipPort: json['ipPort'],
        note: json['note']);
  }

  @override
  String toString() {
    return '{ ${this.title}, ${this.address}, ${this.name}, ${this.volume}, ${this.unit}, ${this.restaurantName}, ${this.date}, ${this.ipPort} }';
  }
}

class Model_Checkout {
  String type;
  Map<String, dynamic> data;

  Model_Checkout({this.type, this.data});

  factory Model_Checkout.fromJson(Map<String, dynamic> json) {
    return Model_Checkout(type: json['type'], data: json["data"]);
  }
  @override
  String toString() {
    return '{ ${this.type}, ${this.data} }';
  }
}

class Model_Checkout_Item {
  String layerName;
  String roomName;
  int people;
  int totalPrice;
  int discount;
  String restaurantName;
  String openDate;
  String closeDate;
  String ipPort;
  List<Model_Checkout_Data> data;

  Model_Checkout_Item(
      {this.layerName,
      this.roomName,
      this.people,
      this.totalPrice,
      this.discount,
      this.restaurantName,
      this.openDate,
      this.closeDate,
      this.data});

  factory Model_Checkout_Item.fromJson(Map<dynamic, dynamic> json) {
    return Model_Checkout_Item(
        layerName: json['layerName'],
        roomName: json['roomName'],
        people: json['people'],
        totalPrice: json['totalPrice'],
        discount: json['discount'],
        restaurantName: json['restaurantName'],
        openDate: json['openDate'],
        closeDate: json['closeDate'],
        data: List<Model_Checkout_Data>.from(
            json["data"].map((x) => Model_Checkout_Data.fromJson(x))));
  }

  @override
  String toString() {
    return '{ ${this.layerName}, ${this.roomName}, ${this.people}, ${this.totalPrice}, ${this.discount}, ${this.restaurantName}, ${this.openDate}, ${this.closeDate} }';
  }
}

class Model_Checkout_Data {
  String name;
  int volume;
  double price;
  int gift;
  String unit;

  Model_Checkout_Data(
      {this.name, this.volume, this.price, this.gift, this.unit});

  factory Model_Checkout_Data.fromJson(Map<String, dynamic> json) {
    return Model_Checkout_Data(
        name: json['name'],
        volume: json['volume'],
        price: json['price'].toDouble(),
        gift: json['gift'],
        unit: json['unit']);
  }

  @override
  String toString() {
    return '{ ${this.name}, ${this.volume}, ${this.price}, ${this.gift}, ${this.unit}';
  }
}
