import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../lib/globals.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.options) {
    return Response(statusCode: HttpStatus.ok, headers: headers);
  }

  final body = await context.request.body();
  final data = json.decode(body);

  final id = data['id'];
  final bias = data['bias'];

  if (id == null || bias == null) {
    return Response.json(
      statusCode: 400,
      body: {'success': false, 'message': 'id 또는 bias 누락'},
      headers: headers,
    );
  }

  final db = await Db.create(mongoUri);
  await db.open();

  await db.collection('users').updateOne(
        where.eq('id', id),
        modify.pull('뉴스 성향', bias),
      );

  await db.close();

  return Response.json(
    body: {'success': true, 'message': '뉴스 성향 삭제됨'},
    headers: headers,
  );
}
