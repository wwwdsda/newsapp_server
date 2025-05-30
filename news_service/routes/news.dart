import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../lib/globals.dart';
const collectionName = 'news';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.options) {
    return Response(
      statusCode: HttpStatus.ok,
      headers: headers,
    );
  }

  final request = context.request;
  final dateParam = request.url.queryParameters['date'];

  if (dateParam == null || dateParam.isEmpty) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'success': false, 'message': '날짜를 입력해주세요.'},
      headers: headers,
    );
  }

  Db? db;
  try {
    db = await Db.create(mongoUri);
    await db.open();
    final newsCollection = db.collection(collectionName);

    final newsDoc = await newsCollection.findOne({'date': dateParam});

    if (newsDoc == null) {
      return Response.json(
        statusCode: HttpStatus.notFound,
        body: {'success': false, 'message': '해당 날짜의 뉴스가 없습니다.'},
        headers: headers,
      );
    }

    final newsMap = Map<String, dynamic>.from(newsDoc)
      ..remove('_id')
      ..remove('date');

    return Response.json(
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'date': dateParam,
        'news': newsMap,
      },
      headers: headers,
    );
  } catch (e) {
    db?.close();
    return Response.json(
      statusCode: HttpStatus.internalServerError,
      body: {'success': false, 'message': '서버 오류: ${e.toString()}'},
      headers: headers,
    );
  } finally {
    await db?.close();
  }
}
