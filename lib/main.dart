import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'utils/helpers.dart';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ManMiner',
      home: MyHomePage(title: 'ManMiner'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, required this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  void _clearaddresses() async {
    final prefs = await SharedPreferences.getInstance();
    addresses = [];
    selectedAddress = '1NSL8tP3giTS3yGsxfTLqFdRdLRa8MMpbi';
    selectedindex = double.infinity;
    prefs.setDouble('selected', selectedindex.toDouble());
    prefs.setStringList('addresses', addresses);
    setState(() {});
  }

  void selectaddress(String address) {
    selectedAddress = address;
    Navigator.pop(context);
    setState(() {});
  }

  void validatenonce(value) {
    if (!value.isEmpty) {
      if (!digitValidator.hasMatch(value) || int.parse(value) >= 2147483647) {
        setValidator(false);
      } else {
        setValidator(true);
      }
    }
    return null;
  }

  RegExp digitValidator = RegExp("[0-9]+");
  bool isANonce = true;
  String selectedAddress = '1NSL8tP3giTS3yGsxfTLqFdRdLRa8MMpbi';
  num selectedindex = double.infinity;
  List<String> addresses = [];
  final msgcontroller = TextEditingController();
  final noncecontroller = TextEditingController();
  final newaddress = TextEditingController();
  String guessed_hash = '-';
  String target_hash = '-';
  String reward = '-';
  String block = '-';
  bool rewardstate = false;
  bool show_icon = false;
  IconData icon = FontAwesomeIcons.frown;
  Color icon_color = Color(0xFFEE8B60);
  String rewardstate_txt = 'Unlucky, try again?';
  bool initstate = true;

  @override
  void initState() {
    super.initState();
    firstrun();
  }

  void firstrun() async {
    final prefs = await SharedPreferences.getInstance();
    Map block_template = await rpc_getblocktemplate();
    block = block_template['height'].toString();
    reward = (block_template['coinbasevalue'] / 100000000).toString();
    target_hash = hex.encode(block_bits2target(block_template['bits']));
    initstate = false;
    final pref_addresses = prefs.getStringList('addresses');
    final pref_index = prefs.getDouble('selected');
    if (pref_addresses != null) {
      addresses = pref_addresses;
    }
    if (pref_index != null && pref_index != double.infinity) {
      selectedindex = pref_index;
      selectedAddress = addresses[selectedindex.toInt()];
    }

    setState(() {});
  }

  Widget enterAddressDialog(thestate) {
    return AlertDialog(
      title: Text('Enter an Address'),
      content: TextField(
        controller: newaddress,
      ),
      actions: <Widget>[
        new TextButton(
          child: new Text('Add'),
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            addresses.add(newaddress.text);
            prefs.setStringList('addresses', addresses);
            selectedAddress = addresses[addresses.length - 1];
            selectedindex = addresses.length - 1;
            prefs.setDouble('selected', selectedindex.toDouble());
            Navigator.pop(context);
            thestate(() {});
            setState(() {});
          },
        )
      ],
    );
  }

  Widget setupAlertDialoadContainer() {
    return Container(
        height: MediaQuery.of(context).size.width *
            0.65, // Change as per your requirement
        width: MediaQuery.of(context).size.width *
            0.65, // Change as per your requirement
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: addresses.length,
          itemBuilder: (BuildContext context, int index) {
            return Column(children: [
              ListTile(
                  title: Text('${addresses[index]}'),
                  selected: selectedindex == index,
                  tileColor: Color(300),
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    selectedindex = index;
                    prefs.setDouble('selected', selectedindex.toDouble());
                    selectaddress(addresses[index]);
                  }),
              Divider(
                thickness: 3,
                //color: Color(0xFFEF5350),
              ),
            ]);
          },
        ));
  }

  void do_mine(String msg, String nonce) async {
    List mine_res = await start_miner(
        hex.encode(utf8.encode('ManMiner: ' + msg)),
        '1NSL8tP3giTS3yGsxfTLqFdRdLRa8MMpbi',
        int.parse(nonce));
    guessed_hash = mine_res[1];
    target_hash = mine_res[0];
    reward = (mine_res[2] / 100000000).toString();
    block = mine_res[3].toString();
    rewardstate = mine_res[4];

    if (rewardstate) {
      icon = FontAwesomeIcons.smile;
      icon_color = Colors.green;
      rewardstate_txt = "Congrats! You just won $reward BTC";
    } else {
      icon = FontAwesomeIcons.frown;
      icon_color = Color(0xFFEE8B60);
      rewardstate_txt = "Unlucky, try again?";
    }

    show_icon = true;
    setState(() {});
  }

  void setValidator(valid) {
    setState(() {
      isANonce = valid;
    });
  }

  @override
  Widget build(BuildContext context) {
    double c_width = MediaQuery.of(context).size.width * 0.65;
    return Scaffold(
        backgroundColor: Color(0xFFEEEEEE),
        body: SafeArea(
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              color: Color(0xFFEEEEEE),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(0, 30, 0, 0),
                        child: Text(
                          'Mining For',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                          ),
                        ),
                      )
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () {
                          showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return StatefulBuilder(
                                    builder: (context, setState) {
                                  return AlertDialog(
                                    title: Text('Saved Adresses'),
                                    content: setupAlertDialoadContainer(),
                                    actions: [
                                      TextButton(
                                        child: Text("Add New..."),
                                        onPressed: () => showDialog(
                                            context: context,
                                            builder: (BuildContext context) {
                                              return enterAddressDialog(
                                                  setState);
                                            }),
                                      ),
                                      TextButton(
                                        child: Text("Clear All"),
                                        onPressed: () {
                                          _clearaddresses();
                                          setState(() {});
                                        },
                                      ),
                                      TextButton(
                                        child: Text("Close"),
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                      ),
                                    ],
                                  );
                                });
                              });
                        },
                        child: Text(
                          selectedAddress,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.blue,
                          ),
                        ),
                      )
                    ],
                  ),
                  Divider(
                    thickness: 3,
                    indent: 90,
                    endIndent: 90,
                    color: Color(0xFFEF5350),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Current Block: ' + block,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                        ),
                      )
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Current Reward: ' + reward + ' BTC',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                        ),
                      )
                    ],
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 40, 0, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: Card(
                            clipBehavior: Clip.antiAliasWithSaveLayer,
                            color: Color(0xFFF5F5F5),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                              child: TextField(
                                controller: msgcontroller,
                                inputFormatters: [
                                  _Utf8LengthLimitingTextInputFormatter(90)
                                ],
                                obscureText: false,
                                decoration: InputDecoration(
                                  labelText: 'Coinbase Message',
                                  labelStyle: TextStyle(
                                    fontFamily: 'Poppins',
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.transparent,
                                      width: 1,
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4.0),
                                      topRight: Radius.circular(4.0),
                                    ),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.transparent,
                                      width: 1,
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4.0),
                                      topRight: Radius.circular(4.0),
                                    ),
                                  ),
                                ),
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 10, 0, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: Card(
                            clipBehavior: Clip.antiAliasWithSaveLayer,
                            color: Color(0xFFF5F5F5),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(20, 0, 20, 0),
                              child: TextField(
                                onChanged: (text) => validatenonce(text),
                                controller: noncecontroller,
                                keyboardType: TextInputType.number,
                                obscureText: false,
                                decoration: InputDecoration(
                                  errorText: isANonce
                                      ? null
                                      : "Please enter a number between 0 and 2,147,483,646",
                                  labelText: 'Nonce',
                                  labelStyle: TextStyle(
                                    fontFamily: 'Poppins',
                                  ),
                                  enabledBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.transparent,
                                      width: 1,
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4.0),
                                      topRight: Radius.circular(4.0),
                                    ),
                                  ),
                                  focusedBorder: UnderlineInputBorder(
                                    borderSide: BorderSide(
                                      color: Colors.transparent,
                                      width: 1,
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4.0),
                                      topRight: Radius.circular(4.0),
                                    ),
                                  ),
                                ),
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                ),
                              ),
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 30, 0, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Target Hash:",
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w200,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: c_width,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(0, 10, 0, 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            target_hash,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w200,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 20, 0, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Guess Hash:',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w200,
                          ),
                        )
                      ],
                    ),
                  ),
                  Container(
                    width: c_width,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(0, 10, 0, 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            guessed_hash,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w200,
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 50, 0, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              textStyle: const TextStyle(fontSize: 20)),
                          onPressed: () {
                            setState(() {
                              show_icon = false;
                            });
                            do_mine(msgcontroller.text, noncecontroller.text);
                          },
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
                            child: Text('Mine!'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(0, 30, 0, 0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Visibility(
                          visible: show_icon,
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  FaIcon(
                                    icon,
                                    color: icon_color,
                                    size: 150,
                                  )
                                ],
                              ),
                              Padding(
                                padding: EdgeInsets.fromLTRB(0, 20, 0, 0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Text(
                                      rewardstate_txt,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                      ),
                                    )
                                  ],
                                ),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ));
  }
}

class _Utf8LengthLimitingTextInputFormatter extends TextInputFormatter {
  _Utf8LengthLimitingTextInputFormatter(this.maxLength)
      : assert(maxLength == null || maxLength == -1 || maxLength > 0);

  final int maxLength;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (maxLength != null &&
        maxLength > 0 &&
        bytesLength(newValue.text) > maxLength) {
      // If already at the maximum and tried to enter even more, keep the old value.
      if (bytesLength(oldValue.text) == maxLength) {
        return oldValue;
      }
      return truncate(newValue, maxLength);
    }
    return newValue;
  }

  static TextEditingValue truncate(TextEditingValue value, int maxLength) {
    var newValue = '';
    if (bytesLength(value.text) > maxLength) {
      var length = 0;

      value.text.characters.takeWhile((char) {
        var nbBytes = bytesLength(char);
        if (length + nbBytes <= maxLength) {
          newValue += char;
          length += nbBytes;
          return true;
        }
        return false;
      });
    }
    return TextEditingValue(
      text: newValue,
      selection: value.selection.copyWith(
        baseOffset: min(value.selection.start, newValue.length),
        extentOffset: min(value.selection.end, newValue.length),
      ),
      composing: TextRange.empty,
    );
  }

  static int bytesLength(String value) {
    return utf8.encode(value).length;
  }
}
