// ignore_for_file: file_names
import 'dart:convert';
import 'dart:developer';

import 'package:http/http.dart' as http;

class TapServices {
  final String apiKey;
  final Map<String, dynamic> paymentData;
  String basePath = "https://api.tap.company/";
  String version = "v2";

  TapServices({
    required this.apiKey,
    required this.paymentData,
  });

  Future<Map<String, dynamic>> sendPayment() async {
    log("Sending payment", name: "TapServices.sendPayment");

    Uri domain = Uri.parse("$basePath$version/charges/");
    try {
      final headers = {
        'Authorization': 'Bearer $apiKey',
        'accept': 'application/json',
        'content-type': 'application/json',
      };
      var data = jsonEncode(paymentData);
      final response = await http.post(domain, headers: headers, body: data);
      final status = response.statusCode;
      var body = json.decode(response.body);
      if (status == 200) {
        log("Payment sent successfully", name: "TapServices.sendPayment");
        log("payment Sent Body: ${response.body}",
            name: "TapServices.sendPayment");
        return {'error': false, 'message': response.body};
      } else {
        log("Error: ${body.toString()}", name: "TapServices.sendPayment");
        return {'error': true, 'message': body.toString()};
      }
    } catch (e) {
      log("Error: ${e.toString()}", name: "TapServices.sendPayment");
      return {'error': true, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> confirmPayment(tapId) async {
    log("Confirming payment", name: "TapServices.confirmPayment");
    String domain = "$basePath$version/charges/$tapId";
    try {
      var response = await http.get(
        Uri.parse(domain),
        headers: {
          "content-type": "application/json",
          'Authorization': 'Bearer $apiKey'
        },
      );
      final body = jsonDecode(response.body);
      if (response.statusCode == 200) {
        log("Payment confirmed", name: "TapServices.confirmPayment");
        return {
          'error': false,
          'message': "Confirmed",
          'data': body,
        };
      } else {
        log("Payment inconclusive", name: "TapServices.confirmPayment");
        return {
          'error': true,
          'message': "Payment inconclusive.",
          'data': body,
        };
      }
    } catch (e) {
      log("Error: ${e.toString()}", name: "TapServices.confirmPayment");
      return {
        'error': true,
        'message': e.toString(),
        'exception': true,
        'data': null
      };
    }
  }
}
