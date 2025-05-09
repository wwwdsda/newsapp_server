import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.options) {
    return Response(
      statusCode: HttpStatus.ok,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
      },
    );
  }

  final headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
  };

  try {
    final body = await context.request.body();
    print('받은 요청 본문: $body');

    if (body.isEmpty) {
      return Response.json(
        body: {'success': false, 'message': '요청 본문이 비어 있습니다'},
        statusCode: HttpStatus.badRequest,
        headers: headers,
      );
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    final username = data['username'] as String? ?? '';
    final password = data['password'] as String? ?? '';

    if (username.isEmpty || password.isEmpty) {
      return Response.json(
        body: {'success': false, 'message': '아이디 또는 비밀번호가 비어 있습니다'},
        statusCode: HttpStatus.badRequest,
        headers: headers,
      );
    }

    if (username == 'admin' && password == 'password') {
      return Response.json(
        body: {
          'success': true,
          'message': '로그인 성공',
          'token': 'admin_token',
        },
        headers: headers,
      );
    }

    return Response.json(
      body: {'success': false, 'message': '잘못된 로그인 정보입니다'},
      statusCode: HttpStatus.unauthorized,
      headers: headers,
    );
  } catch (e) {
    return Response.json(
      body: {'success': false, 'message': '서버 오류: ${e.toString()}'},
      statusCode: HttpStatus.internalServerError,
      headers: headers,
    );
  }
}