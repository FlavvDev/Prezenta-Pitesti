import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityIndicator extends StatefulWidget {
  const ConnectivityIndicator({Key? key}) : super(key: key);

  @override
  _ConnectivityIndicatorState createState() => _ConnectivityIndicatorState();
}

class _ConnectivityIndicatorState extends State<ConnectivityIndicator> {
  String _status = "Online";
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      ConnectivityResult result = results.isNotEmpty ? results.first : ConnectivityResult.none;
      setState(() {
        _status = (result == ConnectivityResult.none) ? "Offline" : "Online";
      });
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_status == "Online") return const SizedBox.shrink();
    return Container(
      height: 20,
      color: Colors.red,
      child: const Center(
        child: Text(
          "Offline",
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            decoration: TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
