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

  final db = await Db.create(mongoUri);
  await db.open();

  final data = jsonDecode(await context.request.body()) as Map;
  final id = data['id'];
  final password = data['password'];
  final keyword = data['keyword'];

  final userCollection = db.collection('users');
  final user = await userCollection.findOne({'id': id, 'password': password});
  if (user == null) {
    await db.close();
    return Response.json(
        statusCode: 401, body: {'message': '인증 실패'}, headers: headers);
  }

  final existing = List<String>.from(user['키워드'] ?? []);
  existing.remove(keyword);

  await userCollection.updateOne(
    where.eq('id', id),
    modify.set('키워드', existing),
  );

  await db.close();
  return Response.json(body: {'message': '키워드 삭제 완료'}, headers: headers);
}
