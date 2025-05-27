import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';

const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
};

const mongoUri = 'mongodb://localhost:27017/dart_frog_newsapp';

Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method == HttpMethod.options) {
    return Response(statusCode: HttpStatus.ok, headers: headers);
  }

  String? id;
  String? password;

  if (request.method == HttpMethod.post) {
    final body = await request.body();
    final data = jsonDecode(body);
    id = data['id'];
    password = data['password'];
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

  final newsBias = (user?['뉴스 성향'] as List<dynamic>?) ?? [];

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
