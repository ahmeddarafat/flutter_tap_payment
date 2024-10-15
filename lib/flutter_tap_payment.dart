library flutter_tap_payment;

import 'dart:convert';
import 'dart:core';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:webview_flutter/webview_flutter.dart';
// Import for Android features.
import 'package:webview_flutter_android/webview_flutter_android.dart';
// Import for iOS features.
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import 'src/TapServices.dart';
import 'src/errors/network_error.dart';

class TapPayment extends StatefulWidget {
  final Function onSuccess, onError;
  final String apiKey, redirectUrl, postUrl;
  final Map<String, dynamic> paymentData;

  const TapPayment({
    super.key,
    required this.onSuccess,
    required this.onError,
    required this.apiKey,
    required this.redirectUrl,
    required this.postUrl,
    required this.paymentData,
  });

  @override
  State<StatefulWidget> createState() {
    return TapPaymentState();
  }
}

class TapPaymentState extends State<TapPayment> {
  late final WebViewController _controller;
  late TapServices services;

  String checkoutUrl = 'https://tap.company';
  String navUrl = 'tap.company';
  bool loading = true;
  bool pageLoading = true;
  bool loadingError = false;
  int pressed = 0;

  @override
  void initState() {
    super.initState();
    var formData = {};
    formData['post'] = {"url": widget.postUrl};
    formData['redirect'] = {"url": widget.redirectUrl};
    services = TapServices(
      apiKey: widget.apiKey,
      paymentData: {...widget.paymentData, ...formData},
    );

    if (mounted) {
      setState(() {
        navUrl = 'checkout.payments.tap.company';
      });
    }
    _loadPayment();

    // #docregion platform_features
    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is WebKitWebViewPlatform) {
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final WebViewController controller =
        WebViewController.fromPlatformCreationParams(params);
    // #enddocregion platform_features

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            debugPrint('WebView is loading (progress : $progress%)');
          },
          onPageStarted: (String url) {
            if (mounted) {
              setState(() {
                pageLoading = true;
                loadingError = false;
              });
            }
            debugPrint('Page started loading: $url');
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                navUrl = url;
                pageLoading = false;
              });
            }
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('''
              Page resource error:
              code: ${error.errorCode}
              description: ${error.description}
              errorType: ${error.errorType}
              isForMainFrame: ${error.isForMainFrame}
          ''');
          },
          onNavigationRequest: (NavigationRequest request) {
            if (request.url.startsWith('https://www.youtube.com/')) {
              debugPrint('blocking navigation to ${request.url}');
              return NavigationDecision.prevent;
            }
            if (request.url.contains(widget.redirectUrl)) {
              final uri = Uri.parse(request.url);
              debugPrint("Got back: ${uri.queryParameters}");
              if (mounted) {
                _completePayment(request.url);
              }
            }
            debugPrint('allowing navigation to ${request.url}');
            return NavigationDecision.navigate;
          },
          onUrlChange: (UrlChange change) {
            debugPrint('url change to ${change.url}');
          },
        ),
      )
      ..addJavaScriptChannel(
        'Toaster',
        onMessageReceived: (JavaScriptMessage message) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message.message)),
            );
          }
        },
      );

    // #docregion platform_features
    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(true);
      (controller.platform as AndroidWebViewController)
          .setMediaPlaybackRequiresUserGesture(false);
    }
    // #enddocregion platform_features

    _controller = controller;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (pressed < 2) {
          if (mounted) {
            setState(() {
              pressed++;
            });
          }
          final snackBar = SnackBar(
              content: Text(
                  'Press back ${3 - pressed} more times to cancel transaction'));
          ScaffoldMessenger.of(context).showSnackBar(snackBar);
          return false;
        } else {
          return true;
        }
      },
      child: Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF272727),
            leading: GestureDetector(
              child: const Icon(
                Icons.arrow_back_ios,
                color: Colors.white70,
              ),
              onTap: () => Navigator.pop(context),
            ),
            title: Row(
              children: [
                Expanded(
                    child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline,
                        color: Uri.parse(navUrl).hasScheme
                            ? Colors.green
                            : Colors.blue,
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          navUrl,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, color: Colors.white70),
                        ),
                      ),
                      SizedBox(width: pageLoading ? 5 : 0),
                      pageLoading
                          ? const SpinKitFadingCube(
                              color: Color(0xFFEB920D),
                              size: 10.0,
                            )
                          : const SizedBox()
                    ],
                  ),
                ))
              ],
            ),
            elevation: 0,
          ),
          body: SizedBox(
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            child: loading ||
                    (checkoutUrl == 'https://tap.company' &&
                        loadingError == false)
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
                                  loadData: _loadPayment,
                                  message: "Something went wrong,"),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Expanded(
                            child: WebViewWidget(controller: _controller),
                          ),
                        ],
                      ),
          )),
    );
  }

  void _loadPayment() async {
    if (mounted) {
      setState(() {
        loading = true;
      });
    }
    try {
      Map getPayment = await services.sendPayment();

      final data = json.decode(getPayment['message']);
      if (getPayment['error'] == false &&
          data?['transaction']?["url"] != null) {
        if (mounted) {
          setState(() {
            checkoutUrl = data['transaction']["url"].toString();
            navUrl = data['transaction']["url"].toString();
            loading = false;
            pageLoading = false;
            loadingError = false;
          });
        }
        _controller.loadRequest(Uri.parse(checkoutUrl));
      } else {
        widget.onError(getPayment);
        if (mounted) {
          setState(() {
            loading = false;
            pageLoading = false;
            loadingError = true;
          });
        }
      }
    } catch (e) {
      widget.onError(e);
      if (mounted) {
        setState(() {
          loading = false;

          pageLoading = false;
          loadingError = true;
        });
      }
    }
  }

  void _completePayment(String url) async {
    final uri = Uri.parse(url);
    final tapID = uri.queryParameters['tap_id'];
    if (tapID != null) {
      Map<String, dynamic> resp = await services.confirmPayment(tapID);
      if (resp['error'] == false) {
        Map<String, dynamic> data = resp['data'];
        String status = data['status'];
        if (status == "CAPTURED") {
          data['message'] = _getMessage(resp['data']);
          await widget.onSuccess(data);
        } else {
          data['message'] = _getMessage(resp['data']);
          widget.onError(data);
        }
      } else {
        if (resp['exception'] != null && resp['exception'] == true) {
          widget.onError({"message": resp['message']});
        } else {
          await widget.onError(resp['data']);
        }
      }
    }
  }

  String _getMessage(data) {
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
}
