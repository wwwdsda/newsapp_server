import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../lib/globals.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.options) {
    return Response(
      statusCode: HttpStatus.ok,
      headers: headers,
    );
  }
  final id = context.request.uri.queryParameters['id'];
  final password = context.request.uri.queryParameters['password'];

  final db = await Db.create(mongoUri);
  await db.open();

  final user = await db.collection('users').findOne({
    'id': id,
    'password': password,
  });

  final keyword = (user?['키워드'] ?? []) as List<dynamic>;

  await db.close();
  return Response.json(
    body: {
      'success': true,
      'message': '키워드 조회 성공',
      'keyword': keyword,
    },
    headers: headers,
  );
}
