import 'dart:convert';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_tap_payment/src/errors/network_error.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '../TapServices.dart';

class CompletePayment extends StatefulWidget {
  final Function onSuccess, onError;
  final TapServices services;
  final String url;
  const CompletePayment({
    super.key,
    required this.onSuccess,
    required this.onError,
    required this.services,
    required this.url,
  });

  @override
  // ignore: library_private_types_in_public_api
  _CompletePaymentState createState() => _CompletePaymentState();
}

class _CompletePaymentState extends State<CompletePayment> {
  bool loading = true;
  bool loadingError = false;

  String getMessage(data) {
    String message = "";
    switch (data['status']) {
      case "CAPTURED":
        message = "The transaction completed successfully";
        break;
      case "ABANDONED":
        message = "The transaction has been abandoned";
        break;
      case "CANCELLED":
        message = "The transaction has been cancelled";
        break;
      case "FAILED":
        message = "The transaction has failed";
        break;
      case "DECLINED":
        message = "The transaction has been declined";
        break;
      case "RESTRICTED":
        message = "The transaction is restricted";
        break;
      case "VOID":
        message = "The transaction is voided";
        break;
      case "TIMEDOUT":
        message = "The transaction is timedout";
        break;
      case "UNKNOWN":
        message = "The transaction is unknown";
        break;
      default:
        message = "The transaction cannot be completed";
    }
    return message;
  }

  void complete() async {
    final uri = Uri.parse(widget.url);
    final tapID = uri.queryParameters['tap_id'];
    if (tapID != null) {
      if (mounted) {
        setState(() {
          loading = true;
          loadingError = false;
        });
      }

      Map<String, dynamic> resp = await widget.services.confirmPayment(tapID);
      log("Response: $resp", name: "CompletePayment.complete");
      if (resp['error'] == false) {
        log("resp error: ${resp['error']}", name: "CompletePayment.complete");
        log("resp data: ${resp['data']}", name: "CompletePayment.complete");
        log("resp['data'] datatype: ${resp['data'].runtimeType}",
            name: "CompletePayment.complete");
        Map<String, dynamic> data = resp['data'];
        String status = data['status'];
        if (status == "CAPTURED") {
          log("resp data: $data", name: "CompletePayment.complete");

          data['message'] = getMessage(resp['data']);
          log("resp data: $data", name: "CompletePayment.complete");
          await widget.onSuccess(data);

          if (mounted) {
            setState(() {
              loading = false;
              loadingError = false;
            });
            Navigator.pop(context);
          }
        } else {
          data['message'] = getMessage(resp['data']);
          widget.onError(data);
          if (mounted) {
            setState(() {
              loading = false;
              loadingError = false;
            });
            Navigator.pop(context);
          }
        }
      } else {
        if (resp['exception'] != null && resp['exception'] == true) {
          widget.onError({"message": resp['message']});
          if (mounted) {
            setState(() {
              loading = false;
              loadingError = true;
            });
          }
        } else {
          await widget.onError(resp['data']);
          if (mounted) {
            Navigator.of(context).pop();
          }
        }
      }
      //return NavigationDecision.prevent;
    } else {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    complete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: loading
            ? const Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SpinKitFadingCube(
                        color: Color(0xFFEB920D),
                        size: 30.0,
                      ),
                    ),
                  ),
                ],
              )
            : loadingError
                ? Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: NetworkError(
                              loadData: complete,
                              message: "Something went wrong,"),
                        ),
                      ),
                    ],
                  )
                : const Center(
                    child: Text("Payment Completed"),
                  ),
      ),
    );
  }
}
