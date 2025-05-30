import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../lib/globals.dart';

Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method == HttpMethod.options) {
    return Response(statusCode: HttpStatus.ok, headers: headers);
  }

  String? id;
  String? password;

  if (request.method == HttpMethod.post) {
    final body = await request.body();
    if (body.isEmpty) {
      return Response.json(
        statusCode: HttpStatus.badRequest,
        body: {'success': false, 'message': '요청 바디가 비어있습니다.'},
        headers: headers,
      );
    }
    try {
      final data = jsonDecode(body);
      id = data['id'];
      password = data['password'];
    } catch (e) {
      return Response.json(
        statusCode: HttpStatus.badRequest,
        body: {'success': false, 'message': '잘못된 JSON 형식입니다.'},
        headers: headers,
      );
    }
  } else if (request.method == HttpMethod.get) {
    id = request.uri.queryParameters['id'];
    password = request.uri.queryParameters['password'];
  }

  if (id == null || password == null) {
    return Response.json(
      statusCode: 400,
      body: {'success': false, 'message': 'id 또는 password가 누락되었습니다.'},
      headers: headers,
    );
  }

  final db = await Db.create(mongoUri);
  await db.open();

  final user = await db.collection('users').findOne({
    'id': id,
    'password': password,
  });

  dynamic rawBias = user?['뉴스 성향'];

  List<dynamic> newsBias;
  if (rawBias is List) {
    newsBias = rawBias;
  } else if (rawBias != null) {
    newsBias = [rawBias];
  } else {
    newsBias = [];
  }

  await db.close();

  return Response.json(
    body: {
      'success': true,
      'message': '뉴스 성향 조회 성공',
      'biases': newsBias,
    },
    headers: headers,
  );
}
