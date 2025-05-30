import 'dart:io';
final mongoUri = Platform.environment['MONGO_URI'] ?? 'mongodb://localhost:27017/dart_frog_newsapp';


const apiKey = 'AIzaSyCQ9ZL2HCI0zuc0_6oFtqDaaDATc3M7B50';

final headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type',
};