import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ApiService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: const String.fromEnvironment('API_BASE_URL', defaultValue: 'https://jugaad-api-gateway.com'), 
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  static void initialize() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          // Force refresh if token is close to expiry or just get cached
          final token = await user.getIdToken();
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          // Token expired, handle re-auth or logout
          print("Unauthorized request - potentially expired token");
        }
        return handler.next(e);
      },
    ));
  }

  static Dio get client => _dio;
  static String get baseUrl => _dio.options.baseUrl;

  Future<Map<String, dynamic>> getJob(String jobId) async {
    final response = await _dio.get('/v1/jobs/$jobId');
    return response.data;
  }

  Future<void> acceptJob(String jobId, int expectedVersion) async {
    await _dio.post('/v1/jobs/$jobId/accept', data: {'expected_version': expectedVersion});
  }

  Future<void> declineJob(String jobId) async {
    await _dio.post('/v1/jobs/$jobId/pass');
  }

  Future<void> ackJob(String jobId) async {
    await _dio.post('/v1/jobs/$jobId/ack');
  }

  Future<void> completeJob(String jobId) async {
    await _dio.post('/v1/jobs/$jobId/complete');
  }

  Future<Map<String, dynamic>> createJob(Map<String, dynamic> data) async {
    final response = await _dio.post('/v1/jobs', data: data);
    return response.data;
  }

  Future<Map<String, dynamic>> createRazorpayOrder(String jobId) async {
    final response = await _dio.post('/v1/jobs/$jobId/create-order');
    return response.data;
  }

  Future<void> deleteJob(String jobId) async {
    await _dio.delete('/v1/jobs/$jobId');
  }
}
