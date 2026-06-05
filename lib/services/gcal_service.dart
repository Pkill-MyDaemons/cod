import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/calendar_model.dart';
import 'gmail_service.dart';

const _base = 'https://www.googleapis.com/calendar/v3';

class GCalService {
  static final GCalService instance = GCalService._();
  GCalService._();

  Future<List<CalendarEvent>> listEvents({
    DateTime? from,
    DateTime? to,
    int max = 100,
  }) async {
    final token = await GmailService.instance.accessToken;
    final uri = Uri.parse('$_base/calendars/primary/events').replace(
      queryParameters: {
        'timeMin': (from ?? DateTime.now().subtract(const Duration(days: 1)))
            .toUtc()
            .toIso8601String(),
        'timeMax': (to ?? DateTime.now().add(const Duration(days: 60)))
            .toUtc()
            .toIso8601String(),
        'maxResults': '$max',
        'singleEvents': 'true',
        'orderBy': 'startTime',
      },
    );

    final r = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
    if (r.statusCode != 200) {
      throw Exception('Calendar list failed ${r.statusCode}: ${r.body}');
    }

    final items = (jsonDecode(r.body)['items'] as List<dynamic>?) ?? [];
    return items
        .map((e) => CalendarEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CalendarEvent> createEvent(CalendarEvent event) async {
    final token = await GmailService.instance.accessToken;
    final r = await http.post(
      Uri.parse('$_base/calendars/primary/events'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(event.toJson()),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('Create event failed ${r.statusCode}');
    }
    return CalendarEvent.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteEvent(String eventId) async {
    final token = await GmailService.instance.accessToken;
    await http.delete(
      Uri.parse('$_base/calendars/primary/events/$eventId'),
      headers: {'Authorization': 'Bearer $token'},
    );
  }
}
