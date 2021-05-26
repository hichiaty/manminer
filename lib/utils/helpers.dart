import "dart:typed_data";
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:bs58check/bs58check.dart' as bs58check;
import 'package:bech32/bech32.dart';
import 'package:http/http.dart' as http;
import 'dart:math';
import 'ENV_VARS.dart';
import 'dart:async';

Future<Map> rpc(String method, List params) async {
  Random rnd = Random();
  int rpc_id = rnd.nextInt(2 ^ 32);
  List<int> data = utf8
      .encode(json.encode({"id": rpc_id, "method": method, "params": params}));
  String auth = base64.encode(utf8.encode(RPC_USER + ':' + RPC_PASS));
  final response = await http.post(Uri.parse(RPC_URL),
      headers: {
        'Content-Type': "application/x-www-form-urlencoded",
        "Authorization": "Basic $auth",
        'Content-Length': data.length.toString()
      },
      body: data);
  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to communicate');
  }
}

Future<Map> rpc_getblocktemplate() async {
  Map result = await rpc("getblocktemplate", [
    {
      "rules": ["segwit"]
    }
  ]);
  return result['result'];
}

Future<String> rpc_submitblock(String block_submission) async {
  Map subres = await rpc("submitblock", [block_submission]);
  return subres['result'];
}

String int2lehex(int value, int width) {
  String hex32 = hex.encode(Uint8List(width + 8)
    ..buffer.asByteData().setUint32(0, value, Endian.little));
  return hex32.substring(0, hex32.length - 16);
}

String int2varinthex(int value) {
  if (value < 0xfd) {
    return int2lehex(value, 1);
  } else if (value <= 0xffff) {
    return "fd" + int2lehex(value, 2);
  } else if (value <= 0xffffffff) {
    return "fe" + int2lehex(value, 4);
  } else {
    return "ff" + int2lehex(value, 8);
  }
}

String tx_encode_coinbase_height(int height) {
  int width = (height.bitLength + 7) ~/ 8;
  return hex.encode(Uint8List(1)..buffer.asByteData().setUint8(0, width)) +
      int2lehex(height, width);
}

String tx_compute_hash(String tx) {
  var tx_bytes = hex.decode(tx);
  List<int> digest =
      sha256.convert(sha256.convert(tx_bytes).bytes).bytes.reversed.toList();

  return hex.encode(digest);
}

String tx_compute_merkle_root(List tx_hashes) {
  List<List<int>> decoded_hashes = [];
  for (var i = 0; i < tx_hashes.length; i++) {
    decoded_hashes.add(hex.decode(tx_hashes[i]).reversed.toList());
  }
  while (decoded_hashes.length > 1) {
    if (decoded_hashes.length % 2 != 0) {
      decoded_hashes.add(decoded_hashes[decoded_hashes.length - 1]);
    }

    List<List<int>> tx_hashes_new = [];

    for (var x = 0; x < (decoded_hashes.length ~/ 2);) {
      List<int> concat =
          decoded_hashes.removeAt(0) + decoded_hashes.removeAt(0);
      List<int> concat_hash =
          sha256.convert(sha256.convert(concat).bytes).bytes;
      tx_hashes_new.add(concat_hash);
    }

    decoded_hashes = tx_hashes_new;
  }
  return hex.encode(decoded_hashes[0].reversed.toList());
}

String bitcoinaddress2PKS(String address) {
  if (address.startsWith('bc1')) {
    return segwit.decode(address).scriptPubKey;
  } else if (address.startsWith('3')) {
    String b58 = hex.encode(bs58check.decode(address)).substring(2);
    return "a9" + "14" + b58 + "87";
  } else if (address.startsWith('1')) {
    String b58 = hex.encode(bs58check.decode(address)).substring(2);
    return "76" + "a9" + "14" + b58 + "88" + "ac";
  } else {
    return "Invalid address";
  }
}

String tx_make_coinbase(
    String coinbase_script, String address, int value, int height) {
  coinbase_script = tx_encode_coinbase_height(height) + coinbase_script;
  String pubkey_script = bitcoinaddress2PKS(address);
  String tx = "";

  tx += "01000000";

  tx += "01";

  tx += "0" * 64;

  tx += "ffffffff";

  tx += int2varinthex(coinbase_script.length ~/ 2);

  tx += coinbase_script;

  tx += "ffffffff";

  tx += "01";

  tx += int2lehex(value, 8);

  tx += int2varinthex(pubkey_script.length ~/ 2);

  tx += pubkey_script;

  tx += "00000000";
  return tx;
}

//536870912
List<int> block_make_header(Map block) {
  List<int> header = [];
  header += Uint8List(4)
    ..buffer.asByteData().setInt32(0, block['version'], Endian.little);
  header += hex.decode(block['previousblockhash']).reversed.toList();
  header += hex.decode(block['merkleroot']).reversed.toList();
  header += Uint8List(4)
    ..buffer.asByteData().setInt32(0, block['curtime'], Endian.little);
  header += hex.decode(block['bits']).reversed.toList();
  header += Uint8List(4)
    ..buffer.asByteData().setInt32(0, block['nonce'], Endian.little);

  return header;
}

List<int> block_compute_raw_hash(List<int> header) {
  return sha256.convert(sha256.convert(header).bytes).bytes.reversed.toList();
}

List<int> block_bits2target(String bits) {
  List<int> bits_decoded = hex.decode(bits);
  int shift = bits_decoded[0] - 3;
  List<int> value = bits_decoded.sublist(1);
  List<int> target = value + Uint8List(shift);
  target = Uint8List(32 - target.length) + target;
  return target;
}

String block_make_submit(Map block) {
  String submission = "";
  submission += hex.encode(block_make_header(block));
  submission += int2varinthex(block['transactions'].length);
  for (var i = 0; i < block['transactions'].length; i++) {
    submission += block['transactions'][i]['data'];
  }
  return submission;
}

List mine_guess(Map block_template, String coinbase_message, String address,
    int nonce_guess) {
  Map coinbase_tx = {};
  block_template['transactions'].insert(0, coinbase_tx);
  block_template['nonce'] = 0;
  List<int> target_hash = block_bits2target(block_template['bits']);
  if (nonce_guess <= 0xffffffff) {
    block_template['nonce'] = nonce_guess;
    String coinbase_script = coinbase_message + int2lehex(0, 4);
    coinbase_tx['data'] = tx_make_coinbase(coinbase_script, address,
        block_template['coinbasevalue'], block_template['height']);
    coinbase_tx['hash'] = tx_compute_hash(coinbase_tx['data']);
    List merkle_hashes = [];
    for (var i = 0; i < block_template['transactions'].length; i++) {
      merkle_hashes.add(block_template['transactions'][i]['hash']);
    }
    block_template['merkleroot'] = tx_compute_merkle_root(merkle_hashes);
    List<int> block_header = block_make_header(block_template);
    List<int> block_hash = block_compute_raw_hash(block_header);
    // compare hashes
    BigInt bhash = BigInt.parse(hex.encode(block_hash), radix: 16);
    BigInt thash = BigInt.parse(hex.encode(target_hash), radix: 16);

    if (bhash < thash) {
      block_template['hash'] = hex.encode(block_hash);
      return [
        block_template,
        hex.encode(target_hash),
        hex.encode(block_hash),
        block_template['coinbasevalue']
      ];
    }
    return [
      {},
      hex.encode(target_hash),
      hex.encode(block_hash),
      block_template['coinbasevalue']
    ];
  }
  return [{}];
}

Future<List> start_miner(
    String coinbase_message, String address, int nonce) async {
  Map block_template = await rpc_getblocktemplate();

  String target_hash = hex.encode(block_bits2target(block_template['bits']));
  List mine_result =
      mine_guess(block_template, coinbase_message, address, nonce);

  Map mined_block = mine_result[0];

  if (mined_block.isNotEmpty) {
    String submission = block_make_submit(mined_block);
    String response = await rpc_submitblock(submission);

    if (response != '') {
    } else {
      return mine_result.sublist(1) + [block_template['height']] + [true];
    }
  }
  return mine_result.sublist(1) + [block_template['height']] + [false];
}
