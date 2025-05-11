import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';

const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Origin, Content-Type, Accept',
};

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.options) {
    return Response(
      statusCode: HttpStatus.ok,
      headers: headers,
    );
  }

  Db? db;
  try {
    final body = await context.request.body();

    if (body.isEmpty) {
      return Response.json(
        body: {'success': false, 'message': '요청 본문이 비어 있습니다'},
        statusCode: HttpStatus.badRequest,
        headers: headers,
      );
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    final category = data['category'] as String? ?? '';
    final date = data['date'] as String? ?? '';
    final title = data['title'] as String? ?? '';

    if (category.isEmpty || date.isEmpty || title.isEmpty) {
      return Response.json(
        body: {'success': false, 'message': '카테고리, 날짜 또는 제목이 비어 있습니다'},
        statusCode: HttpStatus.badRequest,
        headers: headers,
      );
    }

    db = await Db.create('mongodb://localhost:27017/dart_frog_newsapp');
    await db.open();
    final collection = db.collection('news');

    final doc = await collection.findOne({'date': date});
    if (doc == null) {
      return Response.json(
        body: {'success': false, 'message': '해당 날짜의 뉴스가 존재하지 않습니다'},
        statusCode: HttpStatus.notFound,
        headers: headers,
      );
    }

    final newsList = List<Map<String, dynamic>>.from(doc[category] ?? []);
    final index = newsList.indexWhere((item) => item['title'] == title);

    if (index == -1) {
      return Response.json(
        body: {'success': false, 'message': '해당 뉴스 제목을 찾을 수 없습니다'},
        statusCode: HttpStatus.notFound,
        headers: headers,
      );
    }

    final currentScrap = newsList[index]['isScrapped'] ?? 0;
    newsList[index]['isScrapped'] = currentScrap == 1 ? 0 : 1;

    // 카테고리 항목만 업데이트
    await collection.updateOne(
      {'date': date},
      {
        r'$set': {
          category: newsList,
        }
      },
    );

    await db.close();
    return Response.json(
      body: {
        'success': true,
        'newScrapValue': newsList[index]['isScrapped']
      },
      statusCode: HttpStatus.ok,
      headers: headers,
    );
  } catch (e, st) {
    await db?.close();
    return Response.json(
      body: {'success': false, 'error': e.toString(), 'stack': st.toString()},
      statusCode: HttpStatus.internalServerError,
      headers: headers,
    );
  }
}
