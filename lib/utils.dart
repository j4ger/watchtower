import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:get/get.dart';

/// shows a snackbar
/// should be used for infos
void snackbar(String title, String message) {
  Get.showSnackbar(
    GetSnackBar(
      title: title,
      message: message,
      duration: const Duration(seconds: 1),
    ),
  );
}

/// shows an overlay covering the entire screen
/// blocks user interaction with ui below
/// the overlay disappears when the `asyncFunction` returns
Future<T> awaitWithOverlay<T>(
  Future<T> Function() asyncFunction,
) async =>
    Get.showOverlay(
        asyncFunction: asyncFunction,
        opacity: 0.5,
        opacityColor: Colors.black,
        loadingWidget: const SpinKitRing(color: Colors.white));
