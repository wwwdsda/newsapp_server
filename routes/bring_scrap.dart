import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:intl/intl.dart';

const mongoUri = 'mongodb://localhost:27017/dart_frog_newsapp';
const collectionName = 'scrapNews';

final _headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

Future<Response> onRequest(RequestContext context) async {
  final request = context.request;

  if (request.method == HttpMethod.options) {
    return Response(headers: _headers);
  }

  String? userId;

  if (request.method == HttpMethod.post) {
    final body = await request.body();
    if (body.isEmpty) {
      return Response.json(
        statusCode: HttpStatus.badRequest,
        body: {'success': false, 'message': '요청 바디가 비어있습니다.'},
        headers: _headers,
      );
    }
    try {
      final data = jsonDecode(body) as Map<String, dynamic>;
      userId = data['userid'] as String?;
    } catch (e) {
      return Response.json(
        statusCode: HttpStatus.badRequest,
        body: {'success': false, 'message': '잘못된 JSON 형식입니다.'},
        headers: _headers,
      );
    }
  } else if (request.method == HttpMethod.get) {
    userId = request.uri.queryParameters['userid'];
  }

  if (userId == null || userId.isEmpty) {
    return Response.json(
      statusCode: HttpStatus.badRequest,
      body: {'success': false, 'message': 'userid가 필요합니다.'},
      headers: _headers,
    );
  }

  final db = await Db.create(mongoUri);
  try {
    await db.open();
    final collection = db.collection(collectionName);

    final scrappedNews = await collection.find({'userid': userId}).toList();

    final formattedNews =
        scrappedNews.map((doc) {
          final newDoc = Map<String, dynamic>.from(doc);
          newDoc.remove('_id');
          if (newDoc.containsKey('date')) {
            final date = DateTime.tryParse(newDoc['date'].toString());
            if (date != null) {
              newDoc['date'] = DateFormat('yyyy-MM-dd').format(date);
            }
          }
          return newDoc;
        }).toList();

    return Response.json(
      body: formattedNews,
      headers: {..._headers, 'Content-Type': 'application/json'},
    );
  } catch (e, st) {
    print('Error fetching scrap news: $e\n$st');
    return Response.json(
      statusCode: HttpStatus.internalServerError,
      body: {'error': '서버 내부 오류 발생'},
      headers: _headers,
    );
  } finally {
    await db.close();
  }
}
