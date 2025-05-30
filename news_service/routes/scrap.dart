import 'dart:convert';
import 'dart:io';
import 'package:dart_frog/dart_frog.dart';
import 'package:mongo_dart/mongo_dart.dart';
import '../lib/globals.dart';

Future<Response> onRequest(RequestContext context) async {
  if (context.request.method == HttpMethod.options) {
    return Response(statusCode: HttpStatus.ok, headers: headers);
  }

  Db? db;
  try {
    final body = await context.request.body();
    final data = jsonDecode(body) as Map<String, dynamic>;

    final userId = data['userid'] as String? ?? '';
    final category = data['category'] as String? ?? '';
    final date = data['date'] as String? ?? '';
    final title = data['title'] as String? ?? '';
    final summary = data['summary'] as String? ?? '';

    if ([userId, category, date, title, summary].any((e) => e.isEmpty)) {
      return Response.json(
        body: {'success': false, 'message': '필수 필드가 비어 있습니다'},
        statusCode: HttpStatus.badRequest,
        headers: headers,
      );
    }

    db = await Db.create(mongoUri);
    await db.open();
    final newsCollection = db.collection('news');
    final scrapCollection = db.collection('scrapNews');

    final newsDoc = await newsCollection.findOne({'date': date});
    if (newsDoc == null) {
      return Response.json(
        body: {'success': false, 'message': '해당 날짜의 뉴스가 존재하지 않습니다'},
        statusCode: HttpStatus.notFound,
        headers: headers,
      );
    }

    final newsList = List<Map<String, dynamic>>.from(newsDoc[category] ?? []);
    final index = newsList.indexWhere((item) => item['title'] == title);
    if (index == -1) {
      return Response.json(
        body: {'success': false, 'message': '해당 뉴스 제목을 찾을 수 없습니다'},
        statusCode: HttpStatus.notFound,
        headers: headers,
      );
    }

    List<String> scrapList;
    if (newsList[index]['isScrapped'] is List) {
      scrapList = List<String>.from(newsList[index]['isScrapped']);
    } else {
      scrapList = [];
    }

    final alreadyScrapped = scrapList.contains(userId);

    if (alreadyScrapped) {
      scrapList.remove(userId);
      await scrapCollection.deleteOne({'userid': userId, 'title': title});
    } else {
      scrapList.add(userId);
      await scrapCollection.insertOne({
        'userid': userId,
        'date': date,
        'title': title,
        'summary': summary,
        'category': category,
      });
    }

    newsList[index]['isScrapped'] = scrapList;

    await newsCollection.updateOne(
      {'date': date},
      {
        r'$set': {category: newsList},
      },
    );

    return Response.json(body: {'success': true}, headers: headers);
  } catch (e) {
    await db?.close();
    return Response.json(
      body: {'success': false, 'error': e.toString()},
      statusCode: HttpStatus.internalServerError,
      headers: headers,
    );
  } finally {
    await db?.close();
  }
}
