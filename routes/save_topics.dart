import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';

const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
};
const mongoUri = 'mongodb://localhost:27017/dart_frog_newsapp';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.options) {
    return Response(statusCode: HttpStatus.ok, headers: headers);
  }

  final body = await context.request.body();
  final data = json.decode(body);

  final id = data['id'];
  final topics = data['topics'];

  if (id == null || topics == null || topics is! List) {
    return Response.json(
      statusCode: 400,
      body: {'success': false, 'message': 'id 또는 topics 누락'},
      headers: headers,
    );
  }

  final db = await Db.create(mongoUri);
  await db.open();

  await db.collection('users').updateOne(
    where.eq('id', id),
    modify.set('뉴스 주제', topics),
  );

  await db.close();

  return Response.json(
    body: {'success': true, 'message': '뉴스 주제 전체 저장됨'},
    headers: headers,
  );
}
