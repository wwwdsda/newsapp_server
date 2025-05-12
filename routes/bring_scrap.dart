import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:intl/intl.dart';

const mongoUri = 'mongodb://localhost:27017/dart_frog_newsapp';
const collectionName = 'scrapNews';

final _headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.options) {
    return Response(headers: _headers);
  }

  final db = await Db.create(mongoUri);
  try {
    await db.open();
    final collection = db.collection(collectionName);

    final cursor = await collection.find();
    final scrappedNews = await cursor.toList();


    final formattedNews = scrappedNews.map((doc) {
      final newDoc = Map<String, dynamic>.from(doc);
      newDoc.remove('_id');

      if (newDoc.containsKey('date')) {
        final date = DateTime.parse(newDoc['date'].toString());
        newDoc['date'] = DateFormat('yyyy-MM-dd').format(date);
      }
      
      return newDoc;
    }).toList();

    return Response.json(
      body: formattedNews,
      headers: {
        ..._headers,
        'Content-Type': 'application/json',
      },
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
