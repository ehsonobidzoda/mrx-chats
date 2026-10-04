// Паёмбар v2: ID-и шахсӣ + паём бе интернет + релей (паём аз телефони миёна мегузарад)
// pubspec.yaml: nearby_connections: ^4.0.0
// Иҷозатҳоро дар AndroidManifest.xml гузоред (дар файли main.dart-и пешина навишта шудаанд)
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nearby_connections/nearby_connections.dart';

void main() => runApp(const MaterialApp(home: ChatPage()));

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  static const serviceId = 'tj.paymbar';
  final strategy = Strategy.P2P_CLUSTER;
  final myId = (100000 + Random().nextInt(900000)).toString();
  final toCtrl = TextEditingController();
  final textCtrl = TextEditingController();
  final log = <String>[];
  final peers = <String, String>{}; // endpointId -> ID-и корбар
  final seen = <String>{}; // паёмҳои аллакай дидашуда (барои такрор нашудан)
  String status = 'Тугмаи 📡-ро пахш кунед';

  Future<void> start() async {
    await Nearby().askLocationPermission();
    await Nearby().askBluetoothPermission();
    await Nearby().askNearbyWifiDevicesPermission();

    await Nearby().startAdvertising(myId, strategy,
        serviceId: serviceId,
        onConnectionInitiated: onInit,
        onConnectionResult: onResult,
        onDisconnected: onDisc);

    await Nearby().startDiscovery(myId, strategy,
        serviceId: serviceId,
        onEndpointFound: (ep, name, _) {
          // танҳо як тараф дархост мефиристад
          if (myId.compareTo(name) < 0) {
            Nearby().requestConnection(myId, ep,
                onConnectionInitiated: onInit,
                onConnectionResult: onResult,
                onDisconnected: onDisc);
          }
        },
        onEndpointLost: (_) {});
    setState(() => status = 'Ҷустуҷӯ...');
  }

  void onInit(String ep, ConnectionInfo info) {
    peers[ep] = info.endpointName; // номи ҳамсоя = ID-и ӯ
    Nearby().acceptConnection(ep,
        onPayLoadRecieved: (from, p) {
          if (p.type == PayloadType.BYTES) onData(from, utf8.decode(p.bytes!));
        },
        onPayloadTransferUpdate: (_, __) {});
  }

  void onResult(String ep, Status s) {
    if (s != Status.CONNECTED) peers.remove(ep);
    setState(() => status = 'Ҳамсояҳо: ${peers.length}');
  }

  void onDisc(String ep) {
    peers.remove(ep);
    setState(() => status = 'Ҳамсояҳо: ${peers.length}');
  }

  // Қабули паём
  void onData(String fromEp, String raw) {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    if (!seen.add(m['mid'])) return; // аллакай дидаем
    if (m['to'] == myId) {
      setState(() => log.add('Аз ${m['from']}: ${m['text']}'));
    } else {
      relay(raw, except: fromEp); // ба дигар ҳамсояҳо мегузаронем
    }
  }

  void relay(String raw, {String? except}) {
    final bytes = Uint8List.fromList(utf8.encode(raw));
    for (final ep in peers.keys) {
      if (ep != except) Nearby().sendBytesPayload(ep, bytes);
    }
  }

  void sendMsg() {
    final to = toCtrl.text.trim();
    final text = textCtrl.text.trim();
    if (to.length != 6 || text.isEmpty) return;
    final mid = '$myId-${DateTime.now().microsecondsSinceEpoch}';
    seen.add(mid);
    relay(jsonEncode({'mid': mid, 'from': myId, 'to': to, 'text': text}));
    setState(() => log.add('Ба $to: $text'));
    textCtrl.clear();
  }

  @override
  void dispose() {
    Nearby().stopAdvertising();
    Nearby().stopDiscovery();
    Nearby().stopAllEndpoints();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ID-и шумо: $myId'),
        actions: [
          IconButton(icon: const Icon(Icons.wifi_tethering), onPressed: start)
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(spacing: 8, children: [
            Text(status),
            for (final id in peers.values)
              ActionChip(label: Text(id), onPressed: () => toCtrl.text = id),
          ]),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: log.length,
            itemBuilder: (_, i) => ListTile(title: Text(log[i])),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            SizedBox(
              width: 110,
              child: TextField(
                controller: toCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(hintText: 'ID', counterText: ''),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: textCtrl,
                decoration: const InputDecoration(hintText: 'Паём...'),
              ),
            ),
            IconButton(icon: const Icon(Icons.send), onPressed: sendMsg),
          ]),
        ),
      ]),
    );
  }
}