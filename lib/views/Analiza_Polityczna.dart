import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart' as csv;
import 'dart:math' as math;
import 'dart:async';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';

// Kontrolery i klasy pomocnicze (Twoje autorskie)
import '../controllers/seatsCalculator.dart';
import '../controllers/electionCalc.dart';

// Tutaj importujemy plik z SejmAPI
import '../api_wrappers/clubs.dart'; // <-- zmień ścieżkę na właściwą

const Map<String, String> clubNameShortcuts = {
  'Klub Parlamentarny Prawo i Sprawiedliwość': 'PiS',
  'Klub Parlamentarny Koalicja Obywatelska - Platforma Obywatelska, Nowoczesna, Inicjatywa Polska, Zieloni':
      'KO',
  'Klub Parlamentarny Polskie Stronnictwo Ludowe - Trzecia Droga': 'PSL-TD',
  'Klub Parlamentarny Polska 2050 - Trzecia Droga': 'Polska2050-TD',
  'Koło Poselskie Razem': 'Razem',
  'Koalicyjny Klub Parlamentarny Lewicy (Nowa Lewica, PPS, Unia Pracy)':
      'Lewica',
  'Klub Poselski Konfederacja': 'Konfederacja',
};

/// Główny widget ekranu z zakładkami
class View3 extends StatefulWidget {
  const View3({Key? key}) : super(key: key);

  @override
  _View3State createState() => _View3State();
}

class _View3State extends State<View3> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  int termNumber = 10;

  // Poprawiamy typ na List<List<Map<String, dynamic>>>
  List<List<Map<String, dynamic>>> coalitions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Ładujemy koalicje na start
    _loadCoalitions();
  }

  void _loadCoalitions() async {
    // Wywołujemy SejmAPI().findMinimalCoalitions(...)
    final fetchedCoalitions =
        await SejmAPI().findMinimalCoalitions(term: termNumber);
    setState(() {
      coalitions = fetchedCoalitions;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Zakładka "Potencjalne Koalicje"
  Widget _buildPotentialCoalitionTab() {
    // Zamiast FutureBuilder możemy też skorzystać z data, które już mamy w polu `coalitions`.
    // Jeśli jednak zależy nam na dynamicznym odświeżeniu, można zostawić FutureBuilder:
    return FutureBuilder<List<List<Map<String, dynamic>>>>(
      future: SejmAPI().findMinimalCoalitions(term: termNumber),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Błąd: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('Brak danych'));
        }

        // Dane poprawnie pobrane
        final fetchedCoalitions = snapshot.data ?? [];

        // Mapowanie danych do wyświetlenia w tabeli
        // Mapowanie danych do wyświetlenia w tabeli
        final coalitionData = fetchedCoalitions.map((coalition) {
          final totalMembers = coalition
              .map((club) => club['membersCount'] as int)
              .reduce((a, b) => a + b);

          final largestMembers = coalition
              .map((club) => club['membersCount'] as int)
              .reduce(math.max);

          final ratio =
              totalMembers > 0 ? (largestMembers / totalMembers) * 100.0 : 0.0;

          // Skracanie nazw klubów
          final clubNames = coalition.map((club) {
            final fullName = club['name'] as String;
            return clubNameShortcuts[fullName] ?? fullName;
          }).join(', ');

          return {
            'ProcentNajwiekszyKlub': ratio.toStringAsFixed(2),
            'Kluby': clubNames,
            'LacznaIloscPoslow': totalMembers,
            'IloscKlubow': coalition.length,
          };
        }).toList();

        return Column(
          children: [
            // Tabela
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: _buildDataTable(coalitionData),
                ),
              ),
            ),
            // Metryki
            _buildMetrics(coalitionData),
            // Selektor koalicji (np. do BottomSheet)
            _buildCoalitionSelector(context, fetchedCoalitions),
          ],
        );
      },
    );
  }

  /// TABELA
  Widget _buildDataTable(List<Map<String, dynamic>> coalitionData) {
    return DataTable(
      columnSpacing: 16.0,
      columns: const [
        DataColumn(
          label: Expanded(
            child: Text(
              'Procent Największy Klub',
              softWrap: true,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text(
              'Kluby',
              softWrap: true,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text(
              'Łączna Ilość Posłów',
              softWrap: true,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        DataColumn(
          label: Expanded(
            child: Text(
              'Ilość Klubów',
              softWrap: true,
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
      rows: coalitionData.map((data) {
        return DataRow(cells: [
          DataCell(Center(
            child: Text(
              data['ProcentNajwiekszyKlub'],
              textAlign: TextAlign.center,
            ),
          )),
          DataCell(SizedBox(
            width: 200.0,
            child: Text(
              data['Kluby'],
              softWrap: true,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          )),
          DataCell(Center(
            child: Text(
              data['LacznaIloscPoslow'].toString(),
              textAlign: TextAlign.center,
            ),
          )),
          DataCell(Center(
            child: Text(
              data['IloscKlubow'].toString(),
              textAlign: TextAlign.center,
            ),
          )),
        ]);
      }).toList(),
    );
  }

  /// Metryki: liczba koalicji, min i max posłów
  Widget _buildMetrics(List<Map<String, dynamic>> coalitionData) {
    if (coalitionData.isEmpty) {
      return const SizedBox();
    }

    int totalCoalitions = coalitionData.length;
    int minPoslow = coalitionData
        .map((data) => data['LacznaIloscPoslow'] as int)
        .reduce(math.min);
    int maxPoslow = coalitionData
        .map((data) => data['LacznaIloscPoslow'] as int)
        .reduce(math.max);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildMetricTile(
              'Ilość potencjalnych koalicji',
              totalCoalitions.toString(),
              fontSize: 4.0,
            ),
            _buildMetricTile(
              'Minimalna ilość posłów',
              minPoslow.toString(),
              fontSize: 4.0,
            ),
            _buildMetricTile(
              'Maksymalna ilość posłów',
              maxPoslow.toString(),
              fontSize: 4.0,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String title, String value,
      {required double fontSize}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 20)),
        ],
      ),
    );
  }

  /// Dropdown do wyboru koalicji i pokazania szczegółów (BottomSheet)
  Widget _buildCoalitionSelector(
    BuildContext context,
    List<List<Map<String, dynamic>>> potentialCoalitions,
  ) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          const Text(
            "Szczegóły Koalicji",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          DropdownButton<int>(
            items: List.generate(
              potentialCoalitions.length,
              (index) => DropdownMenuItem(
                value: index,
                child: Text('Koalicja nr ${index + 1}'),
              ),
            ),
            onChanged: (value) {
              if (value != null) {
                _showCoalitionDetails(context, potentialCoalitions[value]);
              }
            },
            hint: const Text("Wybierz koalicję"),
          ),
        ],
      ),
    );
  }

  /// BottomSheet z wykresem kołowym
  void _showCoalitionDetails(
    BuildContext context,
    List<Map<String, dynamic>> coalition,
  ) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Można wstawić wykres słupkowy, jeśli potrzebny
            // Expanded(child: _buildBarChart(coalition)),

            const SizedBox(height: 16),
            Expanded(child: _buildPieChart(coalition)),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(List<Map<String, dynamic>> coalition) {
    final totalMembers = coalition.fold<int>(
      0,
      (sum, club) => sum + (club['membersCount'] as int),
    );

    final List<Color> expandedColors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
      Colors.teal,
      Colors.amber,
      Colors.pink,
      Colors.brown,
      Colors.cyan,
      Colors.deepOrange,
      Colors.indigo,
      Colors.lightBlue,
      Colors.lime,
      Colors.deepPurple,
      Colors.yellowAccent,
      Colors.lightGreen,
    ];

    int colorIndex = 0;
    List<PieChartSectionData> pieData = coalition.map((club) {
      final double percentage = (club['membersCount'] / totalMembers) * 100;
      return PieChartSectionData(
        value: club['membersCount'].toDouble(),
        title: "${percentage.toStringAsFixed(1)}%",
        color: expandedColors[colorIndex++ % expandedColors.length],
        radius: 50,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        //badgeWidget: Text(
        //club['name'],
        //style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        //),
        badgePositionPercentageOffset: 1.5,
      );
    }).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: AspectRatio(
              aspectRatio: 1,
              child: PieChart(
                PieChartData(
                  sections: pieData,
                  centerSpaceRadius: 40,
                  sectionsSpace: 3,
                  borderData: FlBorderData(show: false),
                  startDegreeOffset: 270,
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: coalition.map((club) {
                final idx = coalition.indexOf(club);
                final color = expandedColors[idx % expandedColors.length];
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      color: color,
                    ),
                    SizedBox(width: 8),
                    Text(
                      '${club['name']} (${club['membersCount']} posłów)',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// -------------------------------------------------------
  /// Pozostałe zakładki: "Kalkulator Wyborczy"
  /// -------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Padding(
          padding: const EdgeInsets.only(top: 18.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.bar_chart, size: 32),
              SizedBox(width: 8),
              Text(
                'Analiza Polityczna',
                style: TextStyle(fontSize: 24),
              ),
            ],
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.red,
          tabs: const [
            Tab(
              child: Text(
                'Potencjalne Koalicje',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
            Tab(
              child: Text(
                'Kalkulator Wyborczy',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPotentialCoalitionTab(),
          _buildElectionCalculatorTab(),
        ],
      ),
    );
  }

  /// Zakładka "Kalkulator Wyborczy" z dwoma podzakładkami: "Własne" i "Rzeczywiste"
  Widget _buildElectionCalculatorTab() {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            labelColor: Colors.red,
            tabs: [
              Tab(text: "Własne"),
              Tab(text: "Rzeczywiste"),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                // 1) WŁASNE
                ElectionCalculatorTab(
                  dataJson: dataJson,
                  votesJson: votesJson,
                  onDataJsonChanged: (updated) {
                    setState(() {
                      dataJson = updated;
                    });
                  },
                  onVotesJsonChanged: (updated) {
                    setState(() {
                      votesJson = updated;
                    });
                  },
                ),
                // 2) RZECZYWISTE
                //const RealElectionCalculatorTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------
  // Dane testowe "dataJson" i "votesJson" (dla zakładki "Własne")
  // -------------------------------------------------------
  Map<String, dynamic> dataJson = {
    "Legnica": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 12,
      "Uzupełniono": false,
    },
    "Wałbrzych": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 8,
      "Uzupełniono": false,
    },
    "Wrocław": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 14,
      "Uzupełniono": false,
    },
    "Bydgoszcz": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 12,
      "Uzupełniono": false,
    },
    "Toruń": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 13,
      "Uzupełniono": false,
    },
    "Lublin": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 15,
      "Uzupełniono": false,
    },
    "Chełm": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 12,
      "Uzupełniono": false,
    },
    "Zielona Góra": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 12,
      "Uzupełniono": false,
    },
    "Łódź": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 10,
      "Uzupełniono": false,
    },
    "Piotrków Trybunalski": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 9,
      "Uzupełniono": false,
    },
    "Sieradz": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 12,
      "Uzupełniono": false,
    },
    "Chrzanów": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 8,
      "Uzupełniono": false,
    },
    "Kraków": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 14,
      "Uzupełniono": false,
    },
    "Nowy Sącz": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 10,
      "Uzupełniono": false,
    },
    "Tarnów": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 9,
      "Uzupełniono": false,
    },
    "Płock": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 10,
      "Uzupełniono": false,
    },
    "Radom": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 9,
      "Uzupełniono": false,
    },
    "Siedlce": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 12,
      "Uzupełniono": false,
    },
    "Warszawa": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 20,
      "Uzupełniono": false,
    },
    "Warszawa 2": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 12,
      "Uzupełniono": false,
    },
    "Opole": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 12,
      "Uzupełniono": false,
    },
    "Krosno": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 11,
      "Uzupełniono": false,
    },
    "Rzeszów": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 15,
      "Uzupełniono": false,
    },
    "Białystok": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 14,
      "Uzupełniono": false,
    },
    "Gdańsk": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 12,
      "Uzupełniono": false,
    },
    "Słupsk": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 14,
      "Uzupełniono": false,
    },
    "Bielsko-Biała": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 9,
      "Uzupełniono": false,
    },
    "Częstochowa": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 7,
      "Uzupełniono": false,
    },
    "Gliwice": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 9,
      "Uzupełniono": false,
    },
    "Rybnik": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 9,
      "Uzupełniono": false,
    },
    "Katowice": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 12,
      "Uzupełniono": false,
    },
    "Sosnowiec": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 9,
      "Uzupełniono": false,
    },
    "Kielce": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 16,
      "Uzupełniono": false,
    },
    "Elbląg": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 8,
      "Uzupełniono": false,
    },
    "Olsztyn": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 10,
      "Uzupełniono": false,
    },
    "Kalisz": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 12,
      "Uzupełniono": false,
    },
    "Konin": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 9,
      "Uzupełniono": false,
    },
    "Piła": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 9,
      "Uzupełniono": false,
    },
    "Poznań": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 10,
      "Uzupełniono": false,
    },
    "Koszalin": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 8,
      "Uzupełniono": false,
    },
    "Szczecin": {
      "PiS": 0,
      "KO": 0,
      "Trzecia Droga": 0,
      "Lewica": 0,
      "Konfederacja": 0,
      "Frekwencja": 0.0,
      "Miejsca do zdobycia": 12,
      "Uzupełniono": false,
    },
  };

// votesJson
  Map<String, dynamic> votesJson = {
    "Legnica": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Wałbrzych": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Wrocław": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Bydgoszcz": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Toruń": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Lublin": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Chełm": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Zielona Góra": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Łódź": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Piotrków Trybunalski": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Sieradz": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Chrzanów": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Kraków": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Nowy Sącz": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Tarnów": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Płock": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Radom": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Siedlce": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Warszawa": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Warszawa 2": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Opole": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Krosno": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Rzeszów": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Białystok": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Gdańsk": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Słupsk": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Bielsko-Biała": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Częstochowa": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Gliwice": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Rybnik": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Katowice": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Sosnowiec": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Kielce": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Elbląg": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Olsztyn": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Kalisz": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Konin": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Piła": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Poznań": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Koszalin": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
    "Szczecin": {
      "PiS": 0.0,
      "KO": 0.0,
      "Trzecia Droga": 0.0,
      "Lewica": 0.0,
      "Konfederacja": 0.0,
    },
  };
}

/// ----------------------------------------------------------
/// Widget `ElectionCalculatorTab` ("Własne" dane użytkownika)
/// ----------------------------------------------------------
class ElectionCalculatorTab extends StatefulWidget {
  final Map<String, dynamic> dataJson;
  final Map<String, dynamic> votesJson;
  final ValueChanged<Map<String, dynamic>> onDataJsonChanged;
  final ValueChanged<Map<String, dynamic>> onVotesJsonChanged;

  const ElectionCalculatorTab({
    Key? key,
    required this.dataJson,
    required this.votesJson,
    required this.onDataJsonChanged,
    required this.onVotesJsonChanged,
  }) : super(key: key);

  @override
  _ElectionCalculatorTabState createState() => _ElectionCalculatorTabState();
}

class _ElectionCalculatorTabState extends State<ElectionCalculatorTab> {
  String _type = "ilościowy"; // "ilościowy" lub "procentowy"
  String _method = "d'Hondt";
  late String _selectedDistrict;

  double _pis = 0.0;
  double _ko = 0.0;
  double _td = 0.0;
  double _lewica = 0.0;
  double _konfederacja = 0.0;
  double _frequency = 0.0;
  int _seatsNum = 0;

  Map<String, int> _resultSeats = {};

  late TextEditingController _pisController;
  late TextEditingController _koController;
  late TextEditingController _tdController;
  late TextEditingController _lewicaController;
  late TextEditingController _konfController;
  late TextEditingController _frequencyController;
  late TextEditingController _seatsController;

  @override
  void initState() {
    super.initState();
    _selectedDistrict = widget.dataJson.keys.first;
    _loadDistrictValues(_selectedDistrict);

    _pisController = TextEditingController();
    _koController = TextEditingController();
    _tdController = TextEditingController();
    _lewicaController = TextEditingController();
    _konfController = TextEditingController();
    _frequencyController = TextEditingController();
    _seatsController = TextEditingController();

    _setControllersValues();
  }

  @override
  void dispose() {
    _pisController.dispose();
    _koController.dispose();
    _tdController.dispose();
    _lewicaController.dispose();
    _konfController.dispose();
    _frequencyController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  void _loadDistrictValues(String district) {
    final distData = widget.dataJson[district];
    final distVotes = widget.votesJson[district];
    if (distData != null && distVotes != null) {
      _pis = (distVotes["PiS"] as num?)?.toDouble() ?? 0.0;
      _ko = (distVotes["KO"] as num?)?.toDouble() ?? 0.0;
      _td = (distVotes["Trzecia Droga"] as num?)?.toDouble() ?? 0.0;
      _lewica = (distVotes["Lewica"] as num?)?.toDouble() ?? 0.0;
      _konfederacja = (distVotes["Konfederacja"] as num?)?.toDouble() ?? 0.0;

      _frequency = (distData["Frekwencja"] as num?)?.toDouble() ?? 0.0;
      _seatsNum = distData["Miejsca do zdobycia"] ?? 0;
    }
  }

  void _setControllersValues() {
    _pisController.text = _pis == 0.0 ? '' : _pis.toString();
    _koController.text = _ko == 0.0 ? '' : _ko.toString();
    _tdController.text = _td == 0.0 ? '' : _td.toString();
    _lewicaController.text = _lewica == 0.0 ? '' : _lewica.toString();
    _konfController.text = _konfederacja == 0.0 ? '' : _konfederacja.toString();
    _frequencyController.text = _frequency == 0.0 ? '' : _frequency.toString();
    _seatsController.text = _seatsNum == 0 ? '' : _seatsNum.toString();
  }

  void _updateTempValuesFromControllers() {
    _pis = _parseDouble(_pisController.text);
    _ko = _parseDouble(_koController.text);
    _td = _parseDouble(_tdController.text);
    _lewica = _parseDouble(_lewicaController.text);
    _konfederacja = _parseDouble(_konfController.text);
    _frequency = _parseDouble(_frequencyController.text);
    _seatsNum = int.tryParse(_seatsController.text) ?? 0;
  }

  double _parseDouble(String val) {
    return double.tryParse(val.replaceAll(',', '.')) ?? 0.0;
  }

  void _calculateSeats() {
    _updateTempValuesFromControllers();

    if (_seatsNum <= 0) {
      _showErrorDialog("Liczba mandatów musi być większa niż 0.");
      return;
    }

    final sumVotes = _pis + _ko + _td + _lewica + _konfederacja;
    if (sumVotes == 0) {
      _showErrorDialog("Wprowadź co najmniej jedną partię z głosami > 0.");
      return;
    }

    if (_type == "procentowy" && (sumVotes - 100.0).abs() > 0.0001) {
      _showErrorDialog(
          "Suma procentów musi wynosić dokładnie 100% (obecnie: $sumVotes).");
      return;
    }

    double totalVotes = _frequency;
    double actualPis = _type == "procentowy" ? (_pis / 100) * totalVotes : _pis;
    double actualKo = _type == "procentowy" ? (_ko / 100) * totalVotes : _ko;
    double actualTd = _type == "procentowy" ? (_td / 100) * totalVotes : _td;
    double actualLewica =
        _type == "procentowy" ? (_lewica / 100) * totalVotes : _lewica;
    double actualKonf = _type == "procentowy"
        ? (_konfederacja / 100) * totalVotes
        : _konfederacja;

    widget.votesJson[_selectedDistrict]["PiS"] = actualPis;
    widget.votesJson[_selectedDistrict]["KO"] = actualKo;
    widget.votesJson[_selectedDistrict]["Trzecia Droga"] = actualTd;
    widget.votesJson[_selectedDistrict]["Lewica"] = actualLewica;
    widget.votesJson[_selectedDistrict]["Konfederacja"] = actualKonf;

    widget.dataJson[_selectedDistrict]["Frekwencja"] = _frequency;
    widget.dataJson[_selectedDistrict]["Miejsca do zdobycia"] = _seatsNum;

    widget.onVotesJsonChanged(widget.votesJson);
    widget.onDataJsonChanged(widget.dataJson);

    final result = SeatsCalculator.chooseMethods(
      PiS: actualPis,
      KO: actualKo,
      TD: actualTd,
      Lewica: actualLewica,
      Konfederacja: actualKonf,
      Freq: totalVotes,
      seatsNum: _seatsNum,
      method: _method,
    );

    final seatsMap = result[0] as Map<String, int>;

    setState(() {
      _resultSeats = seatsMap;
    });
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Błąd"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Widget _buildNumberField({
    required String label,
    required TextEditingController controller,
  }) {
    return TextField(
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
      controller: controller,
    );
  }

  Widget _buildResultsTable() {
    if (_resultSeats.isEmpty) {
      return const Text("", style: TextStyle(color: Colors.grey));
    }

    return DataTable(
      columns: const [
        DataColumn(label: Text('Komitet')),
        DataColumn(label: Text('Mandaty')),
      ],
      rows: _resultSeats.entries.map((entry) {
        return DataRow(
          cells: [
            DataCell(Text(entry.key)),
            DataCell(Text(entry.value.toString())),
          ],
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Wybierz okręg:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          DropdownButton<String>(
            value: _selectedDistrict,
            items: widget.dataJson.keys.map<DropdownMenuItem<String>>((dist) {
              return DropdownMenuItem<String>(
                value: dist,
                child: Text(dist),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedDistrict = value;
                  _loadDistrictValues(value);
                  _setControllersValues();
                });
              }
            },
          ),
          const Divider(),
          const Text('Rodzaj głosów:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          DropdownButton<String>(
            value: _type,
            items: const [
              DropdownMenuItem(value: "ilościowy", child: Text("Ilościowy")),
              DropdownMenuItem(value: "procentowy", child: Text("Procentowy")),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _type = value;
                });
              }
            },
          ),
          const Divider(),
          _buildNumberField(label: 'PiS', controller: _pisController),
          _buildNumberField(label: 'KO', controller: _koController),
          _buildNumberField(label: 'Trzecia Droga', controller: _tdController),
          _buildNumberField(label: 'Lewica', controller: _lewicaController),
          _buildNumberField(label: 'Konfederacja', controller: _konfController),
          _buildNumberField(
              label: 'Frekwencja (%)', controller: _frequencyController),
          TextField(
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: 'Liczba mandatów w okręgu'),
            controller: _seatsController,
          ),
          const SizedBox(height: 16),
          const Text('Wybierz metodę:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          DropdownButton<String>(
            value: _method,
            items: [
              "d'Hondt",
              "Sainte-Laguë",
              "Kwota Hare’a (metoda największych reszt)",
              "Kwota Hare’a (metoda najmniejszych reszt)",
            ].map((m) {
              return DropdownMenuItem<String>(value: m, child: Text(m));
            }).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  _method = val;
                });
              }
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _calculateSeats,
            child: const Text('Oblicz podział mandatów'),
          ),
          const SizedBox(height: 16),
          const Text('Wynik podziału mandatów:',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildResultsTable(),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

/// ----------------------------------------------------------
/// Widget "Rzeczywiste" – wczytuje dane z CSV (przykład)
/// ----------------------------------------------------------
// class RealElectionCalculatorTab extends StatefulWidget {
//   const RealElectionCalculatorTab({Key? key}) : super(key: key);
//
//   @override
//   _RealElectionCalculatorTabState createState() =>
//       _RealElectionCalculatorTabState();
// }
//
// class _RealElectionCalculatorTabState extends State<RealElectionCalculatorTab> {
//   final List<int> _availableYears = [2001, 2005, 2007, 2011, 2015, 2019];
//   int? _selectedYear;
//
//   double _threshold = 5.0; // zwykły próg
//   double _thresholdCoalition = 8.0; // próg dla koalicji
//
//   // Nazwy partii znalezione w CSV (kolumny)
//   List<String> _possibleParties = [];
//   // Partie zwolnione z progu
//   List<String> _exemptedParties = [];
//
//   // Surowe dane CSV
//   List<List<dynamic>> _csvRaw = [];
//
//   // Wynik: okręg -> metoda -> partia -> mandaty
//   Map<String, Map<String, Map<String, int>>> _results = {};
//
//   /// Mapa: "1" -> 12, "2" -> 8, itd. (liczba mandatów na okręg)
//   final Map<String, int> seatsPerDistrict = {
//     "1": 12,
//     "2": 8,
//     "3": 14,
//     "4": 12,
//     "5": 13,
//     "6": 15,
//     "7": 12,
//     "8": 12,
//     "9": 10,
//     "10": 9,
//     "11": 12,
//     "12": 8,
//     "13": 14,
//     "14": 10,
//     "15": 9,
//     "16": 10,
//     "17": 9,
//     "18": 12,
//     "19": 20,
//     "20": 12,
//     "21": 12,
//     "22": 11,
//     "23": 15,
//     "24": 14,
//     "25": 12,
//     "26": 14,
//     "27": 9,
//     "28": 7,
//     "29": 9,
//     "30": 9,
//     "31": 12,
//     "32": 9,
//     "33": 16,
//     "34": 8,
//     "35": 10,
//     "36": 12,
//     "37": 9,
//     "38": 9,
//     "39": 10,
//     "40": 8,
//     "41": 12
//   };
//
//   @override
//   Widget build(BuildContext context) {
//     return SingleChildScrollView(
//       padding: const EdgeInsets.all(16),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           const Text("Wybierz rok:",
//               style: TextStyle(fontWeight: FontWeight.bold)),
//           DropdownButton<int>(
//             value: _selectedYear,
//             hint: const Text("Rok"),
//             items: _availableYears.map((y) {
//               return DropdownMenuItem<int>(
//                 value: y,
//                 child: Text(y.toString()),
//               );
//             }).toList(),
//             onChanged: (val) {
//               setState(() {
//                 _selectedYear = val;
//                 if (val != null) {
//                   _loadCsv();
//                 }
//               });
//             },
//           ),
//           const SizedBox(height: 16),
//           const Text("Próg wyborczy (%)",
//               style: TextStyle(fontWeight: FontWeight.bold)),
//           TextField(
//             keyboardType: const TextInputType.numberWithOptions(decimal: true),
//             decoration: const InputDecoration(hintText: ""),
//             onChanged: (val) {
//               final d = double.tryParse(val.replaceAll(',', '.'));
//               if (d != null) setState(() => _threshold = d);
//             },
//           ),
//           const SizedBox(height: 16),
//           const Text("Próg dla koalicji (%)",
//               style: TextStyle(fontWeight: FontWeight.bold)),
//           TextField(
//             keyboardType: const TextInputType.numberWithOptions(decimal: true),
//             decoration: const InputDecoration(hintText: ""),
//             onChanged: (val) {
//               final d = double.tryParse(val.replaceAll(',', '.'));
//               if (d != null) setState(() => _thresholdCoalition = d);
//             },
//           ),
//           const SizedBox(height: 16),
//           const Text("Partie zwolnione z progu (opcjonalne):",
//               style: TextStyle(fontWeight: FontWeight.bold)),
//           _buildExemptedPartiesWidget(),
//           const SizedBox(height: 20),
//           ElevatedButton(
//             onPressed: _calculateResults,
//             child: const Text("Oblicz"),
//           ),
//           const SizedBox(height: 20),
//           _buildResultsTable(),
//         ],
//       ),
//     );
//   }
//
//   /// Wczytuje plik CSV
//   Future<void> _loadCsv() async {
//     if (_selectedYear == null) return;
//
//     try {
//       final filename =
//           'wyniki_gl_na_listy_po_okregach_sejm_utf8_$_selectedYear.csv';
//       final rawString = await rootBundle.loadString('Data/$filename');
//
//       // Starsze lata często ','; nowsze – ';'
//       final separator = (_selectedYear! < 2015) ? ',' : ';';
//
//       final listData = const csv.CsvToListConverter().convert(
//         rawString,
//         fieldDelimiter: separator,
//       );
//
//       setState(() {
//         _csvRaw = listData;
//         _possibleParties = _extractPartyHeaders(listData);
//         _exemptedParties.clear();
//       });
//     } catch (e) {
//       debugPrint("Błąd wczytywania pliku CSV: $e");
//       _csvRaw = [];
//     }
//   }
//
//   /// Szuka kolumn zawierających "Komitet Wyborczy" lub "Koalicyjny"
//   List<String> _extractPartyHeaders(List<List<dynamic>> data) {
//     if (data.isEmpty) return [];
//     final headers = data.first.map((e) => e.toString()).toList();
//
//     return headers.where((colName) {
//       final lower = colName.toLowerCase();
//       return lower.contains("komitet wyborczy") || lower.contains("koalicyjny");
//     }).toList();
//   }
//
//   /// Główna logika obliczeń
//   void _calculateResults() {
//     if (_csvRaw.isEmpty || _selectedYear == null) return;
//
//     final modifiedSeatsPerDistrict = Map<String, int>.from(seatsPerDistrict);
//
//     // Korekty historyczne liczby mandatów (2001–2007)
//     if (_selectedYear! <= 2007) {
//       _adjustSeatsForYear(modifiedSeatsPerDistrict, _selectedYear!);
//     }
//
//     final headerRow = _csvRaw.first.map((e) => e.toString()).toList();
//     final districtIndex = headerRow.indexWhere(
//       (col) => col.toLowerCase() == "okręg",
//     );
//     if (districtIndex < 0) {
//       debugPrint("Nie znaleziono kolumny 'Okręg' w nagłówku CSV.");
//       return;
//     }
//
//     final Map<String, Map<String, double>> votesPerDistrict = {};
//
//     for (var row in _csvRaw.skip(1)) {
//       if (row.length <= districtIndex) continue;
//
//       final districtNumber = row[districtIndex].toString();
//       if (!votesPerDistrict.containsKey(districtNumber)) {
//         votesPerDistrict[districtNumber] = {};
//       }
//
//       for (var partyHeader in _possibleParties) {
//         final colIndex = headerRow.indexOf(partyHeader);
//         if (colIndex < 0 || colIndex >= row.length) continue;
//
//         final value = row[colIndex]?.toString().trim() ?? '';
//         final parsed = double.tryParse(value);
//         final votes = parsed ?? 0.0;
//
//         votesPerDistrict[districtNumber]![partyHeader] =
//             (votesPerDistrict[districtNumber]![partyHeader] ?? 0) + votes;
//       }
//     }
//
//     _results.clear();
//
//     votesPerDistrict.forEach((dist, partiesMap) {
//       final seatsNum = modifiedSeatsPerDistrict[dist] ?? 0;
//       if (seatsNum <= 0) {
//         debugPrint(
//             "Ostrzeżenie: brak liczby mandatów w seatsPerDistrict dla okręgu $dist");
//         return;
//       }
//
//       final totalVotes = partiesMap.values.fold(0.0, (a, b) => a + b);
//       final Map<String, double> filtered = {};
//
//       // Filtrowanie wg progu
//       partiesMap.forEach((partyName, count) {
//         final p = (totalVotes == 0) ? 0 : (count / totalVotes) * 100.0;
//         final isCoalition = partyName.toLowerCase().contains("koalicyjny");
//         final neededThreshold = isCoalition ? _thresholdCoalition : _threshold;
//
//         if (_exemptedParties.contains(partyName) || p >= neededThreshold) {
//           filtered[partyName] = count;
//         }
//       });
//
//       if (filtered.isEmpty) {
//         debugPrint("Okręg $dist: wszystkie partie poniżej progu.");
//         return;
//       }
//
//       final qualifiedParties = filtered.keys.toList();
//       final qualifiedVotes = filtered.values.toList();
//
//       final districtResult = ElectionCalc.chooseMethod(
//         qualifiedDictionary: qualifiedParties,
//         numberOfVotes: qualifiedVotes,
//         year: _selectedYear.toString(),
//         seatsNum: seatsNum,
//       );
//
//       _results[dist] = districtResult;
//     });
//
//     setState(() {
//       // odśwież UI
//     });
//   }
//
//   void _adjustSeatsForYear(Map<String, int> seats, int year) {
//     if (year <= 2007) {
//       seats["12"] = (seats["12"] ?? 0) - 1;
//       seats["13"] = (seats["13"] ?? 0) - 1;
//       seats["18"] = (seats["18"] ?? 0) - 1;
//       seats["19"] = (seats["19"] ?? 0) - 1;
//       seats["20"] = (seats["20"] ?? 0) + 1;
//       seats["23"] = (seats["23"] ?? 0) + 1;
//       seats["28"] = (seats["28"] ?? 0) + 1;
//       seats["40"] = (seats["40"] ?? 0) + 1;
//
//       if (year <= 2001) {
//         seats["1"] = (seats["1"] ?? 0) + 1;
//         seats["8"] = (seats["8"] ?? 0) + 1;
//         seats["11"] = (seats["11"] ?? 0) - 1;
//         seats["12"] = (seats["12"] ?? 0) - 1;
//         seats["14"] = (seats["14"] ?? 0) + 1;
//         seats["19"] = (seats["19"] ?? 0) - 1;
//         seats["30"] = (seats["30"] ?? 0) + 1;
//         seats["34"] = (seats["34"] ?? 0) - 1;
//       }
//     }
//   }
//
//   /// Render tabeli z wynikami — zagregowanymi (suma z wszystkich okręgów).
//   Widget _buildResultsTable() {
//     if (_results.isEmpty) {
//       return const Text("", style: TextStyle(color: Colors.grey));
//     }
//
//     final allParties = <String>{};
//     _results.values.forEach((methodsMap) {
//       methodsMap.values.forEach((mapParties) {
//         allParties.addAll(mapParties.keys);
//       });
//     });
//     final allPartiesList = allParties.toList()..sort();
//
//     final Map<String, Map<String, int>> aggregated = {};
//
//     _results.forEach((district, methodsMap) {
//       methodsMap.forEach((methodName, seatsMap) {
//         aggregated.putIfAbsent(methodName, () => {});
//         seatsMap.forEach((party, seats) {
//           aggregated[methodName]!.update(
//             party,
//             (old) => old + seats,
//             ifAbsent: () => seats,
//           );
//         });
//       });
//     });
//
//     final rows = <DataRow>[];
//     final methodsSorted = aggregated.keys.toList()..sort();
//
//     for (final methodName in methodsSorted) {
//       final seatsMap = aggregated[methodName] ?? {};
//       final cells = <DataCell>[];
//
//       // Pierwsza kolumna: nazwa metody
//       cells.add(DataCell(Text(methodName)));
//
//       // Kolejne kolumny: liczba mandatów danej partii
//       for (final p in allPartiesList) {
//         final seats = seatsMap[p] ?? 0;
//         cells.add(DataCell(Text(seats.toString())));
//       }
//       rows.add(DataRow(cells: cells));
//     }
//
//     final columns = [
//       const DataColumn(label: Text("Metoda")),
//       ...allPartiesList.map((p) => DataColumn(label: Text(p))),
//     ];
//
//     return SingleChildScrollView(
//       scrollDirection: Axis.horizontal,
//       child: DataTable(columns: columns, rows: rows),
//     );
//   }
//
//   /// Checkboxy do zwolnienia partii z progu
//   Widget _buildExemptedPartiesWidget() {
//     if (_possibleParties.isEmpty) {
//       return const Text("");
//     }
//
//     return Column(
//       children: _possibleParties.map((party) {
//         return Row(
//           children: [
//             Checkbox(
//               value: _exemptedParties.contains(party),
//               onChanged: (val) {
//                 setState(() {
//                   if (val == true) {
//                     _exemptedParties.add(party);
//                   } else {
//                     _exemptedParties.remove(party);
//                   }
//                 });
//               },
//             ),
//             Expanded(child: Text(party)),
//           ],
//         );
//       }).toList(),
//     );
//   }
// }
