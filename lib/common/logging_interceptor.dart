import 'package:http/http.dart';
import 'package:http_interceptor/models/interceptor_contract.dart';
import 'package:munich_ways/common/logger_setup.dart';

class LoggingInterceptor implements InterceptorContract {
  @override
  Future<bool> shouldInterceptRequest() async {
    return true;
  }

  @override
  Future<BaseRequest> interceptRequest({required BaseRequest request}) async {
    log.d("REQUEST");
    log.d(request.url);
    log.d(request.headers);
    log.d(request.method);
    log.d(request.toString());
    return request;
  }

  @override
  Future<bool> shouldInterceptResponse() async {
    return true;
  }

  @override
  Future<BaseResponse> interceptResponse(
      {required BaseResponse response}) async {
    log.d("RESPONSE");
    log.d(response.statusCode);
    log.d(response.headers);
    log.d(response.toString());
    return response;
  }
}
