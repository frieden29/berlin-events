import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BerlinEventsApp());
}

class BerlinEvent {
  final String id;
  final String name;
  final DateTime date;
  final String? time;
  final String? venue;
  final double? latitude;
  final double? longitude;
  final String? url;

  const BerlinEvent({
    required this.id,
    required this.name,
    required this.date,
    this.time,
    this.venue,
    this.latitude,
    this.longitude,
    this.url,
  });

  static BerlinEvent? fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString().trim() ?? '';
    final date = DateTime.tryParse(
      json['date']?.toString() ?? '',
    );

    if (name.isEmpty || date == null) {
      return null;
    }

    return BerlinEvent(
      id: json['id']?.toString() ?? '',
      name: name,
      date: date,
      time: json['time']?.toString(),
      venue: json['venue']?.toString(),
      latitude: double.tryParse(
        json['latitude']?.toString() ?? '',
      ),
      longitude: double.tryParse(
        json['longitude']?.toString() ?? '',
      ),
      url: json['url']?.toString(),
    );
  }

  bool get hasLocation =>
      latitude != null &&
      longitude != null &&
      latitude! >= -90 &&
      latitude! <= 90 &&
      longitude! >= -180 &&
      longitude! <= 180;
}

class BerlinEventsApp extends StatelessWidget {
  const BerlinEventsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Berlin Events',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
      ),
      home: const EventsPage(),
    );
  }
}

// ثلاثة خيارات فقط للتصفية.
enum EventFilter {
  today,
  tomorrow,
  dayAfterTomorrow,
}

class EventsPage extends StatefulWidget {
  const EventsPage({super.key});

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  List<BerlinEvent> events = [];

  bool loading = true;
  String? error;

  // عرض فعاليات اليوم افتراضيًا.
  EventFilter selectedFilter = EventFilter.today;

  @override
  void initState() {
    super.initState();
    loadEvents();
  }

  Future<void> loadEvents() async {
    try {
      final text = await rootBundle.loadString(
        'web/events.json',
      );

      final decoded = jsonDecode(text);

      final rawEvents =
          decoded['events'] as List<dynamic>? ?? [];

      final loaded = <BerlinEvent>[];

      for (final item in rawEvents) {
        if (item is! Map<String, dynamic>) {
          continue;
        }

        final event = BerlinEvent.fromJson(item);

        if (event != null) {
          loaded.add(event);
        }
      }

      loaded.sort(
        (a, b) => a.date.compareTo(b.date),
      );

      if (!mounted) return;

      setState(() {
        events = loaded;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        loading = false;
        error = 'Veranstaltungen konnten nicht geladen werden.';
      });
    }
  }

  DateTime dateOnly(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  // تصفية الفعاليات حسب اليوم المحدد فقط.
  List<BerlinEvent> get filteredEvents {
    final today = dateOnly(DateTime.now());

    late final DateTime target;

    switch (selectedFilter) {
      case EventFilter.today:
        target = today;
        break;

      case EventFilter.tomorrow:
        target = DateTime(
          today.year,
          today.month,
          today.day + 1,
        );
        break;

      case EventFilter.dayAfterTomorrow:
        target = DateTime(
          today.year,
          today.month,
          today.day + 2,
        );
        break;
    }

    return events.where((event) {
      return dateOnly(event.date) == target;
    }).toList();
  }

  Future<void> openNavigation(BerlinEvent event) async {
    if (!event.hasLocation) {
      showMessage('Kein Standort verfügbar.');
      return;
    }

    final lat = event.latitude!;
    final lon = event.longitude!;

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$lat,$lon',
    );

    await openLink(uri);
  }

  Future<void> openEvent(BerlinEvent event) async {
    if (event.url == null || event.url!.isEmpty) {
      showMessage('Kein Veranstaltungslink verfügbar.');
      return;
    }

    final uri = Uri.tryParse(event.url!);

    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      showMessage('Ungültiger Veranstaltungslink.');
      return;
    }

    await openLink(uri);
  }

  Future<void> openLink(Uri uri) async {
    try {
      final success = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!success) {
        showMessage('Link konnte nicht geöffnet werden.');
      }
    } catch (_) {
      showMessage('Link konnte nicht geöffnet werden.');
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day.$month.${date.year}';
  }

  Widget filterButton(
    String label,
    EventFilter filter,
  ) {
    return ChoiceChip(
      label: Text(label),
      selected: selectedFilter == filter,
      onSelected: (_) {
        setState(() {
          selectedFilter = filter;
        });
      },
    );
  }

  Widget eventCard(BerlinEvent event) {
    final venue = event.venue == null ||
            event.venue!.trim().isEmpty
        ? 'Veranstaltungsort nicht angegeben'
        : event.venue!;

    final time = event.time == null ||
            event.time!.trim().isEmpty
        ? 'Uhrzeit nicht angegeben'
        : '${event.time!.substring(0, 5)} Uhr';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              event.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(Icons.calendar_month, size: 18),
                const SizedBox(width: 8),
                Text(formatDate(event.date)),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(Icons.access_time, size: 18),
                const SizedBox(width: 8),
                Text(time),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(venue)),
              ],
            ),

            const SizedBox(height: 16),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: event.hasLocation
                      ? () => openNavigation(event)
                      : null,
                  icon: const Icon(Icons.navigation),
                  label: const Text('Navigation starten'),
                ),

                OutlinedButton.icon(
                  onPressed: () => openEvent(event),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Veranstaltung öffnen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleEvents = filteredEvents;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Berlin Events'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                loading = true;
              });

              loadEvents();
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Aktualisieren',
          ),
        ],
      ),

      body: loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : error != null
              ? Center(
                  child: Text(error!),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Veranstaltungen in Berlin',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 8),

                          Text(
                            '${visibleEvents.length} Veranstaltungen',
                          ),

                          const SizedBox(height: 16),

                          // الأزرار الثلاثة فقط.
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              filterButton(
                                'Heute',
                                EventFilter.today,
                              ),
                              filterButton(
                                'Morgen',
                                EventFilter.tomorrow,
                              ),
                              filterButton(
                                'Übermorgen',
                                EventFilter.dayAfterTomorrow,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: visibleEvents.isEmpty
                          ? const Center(
                              child: Text(
                                'Keine Veranstaltungen gefunden.',
                              ),
                            )
                          : ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              itemCount: visibleEvents.length,
                              itemBuilder: (context, index) {
                                return eventCard(
                                  visibleEvents[index],
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}