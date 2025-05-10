import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';

const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
  };

final mongoUri = 'mongodb://localhost:27017/dart_frog_newsapp';
const newsCollectionName = 'news';
Db? _db;

Future<Db> getDatabase() async {
  if (_db == null || !_db!.isConnected) {
    _db = await Db.create(mongoUri);
    await _db!.open();
  }
  return _db!;
}

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
    );
  }

  try {
    final db = await getDatabase();
    final newsCollection = db.collection(newsCollectionName);

    final newsDoc = await newsCollection.findOne({dateParam: {'\$exists': true}});

    if (newsDoc == null) {
      return Response.json(
        statusCode: HttpStatus.notFound,
        body: {'success': false, 'message': '해당 날짜의 뉴스가 없습니다.'},
      );
    }

    return Response.json(
      statusCode: HttpStatus.ok,
      body: {
        'success': true,
        'date': dateParam,
        'news': newsDoc[dateParam],
      },
      headers: headers,
    );
  } catch (e) {
    print("서버 오류: $e");
    return Response.json(
      statusCode: HttpStatus.internalServerError,
      body: {'success': false, 'message': '서버 오류가 발생했습니다.'},
    );
  }
}