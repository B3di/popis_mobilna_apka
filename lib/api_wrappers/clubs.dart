import 'package:http/http.dart' as http;
import 'dart:convert';

Future<Map<String, dynamic>> getClubs(int term) async {
  final response = await http.get(Uri.parse('https://api.sejm.gov.pl/sejm/term$term/clubs'));
  List<dynamic> clubsList = json.decode(response.body);
  Map<String, dynamic> clubsResponse = {'data': clubsList};
  return clubsResponse;
}
Future<Map<String, dynamic>> getClub(int term, String id) async {
  final response = await http.get(Uri.parse('https://api.sejm.gov.pl/sejm/term$term/clubs/$id'));
  return json.decode(response.body);
}

Future<List<int>> getClubLogo(int term, String id) async {
  final response = await http.get(Uri.parse('https://api.sejm.gov.pl/sejm/term$term/clubs/$id/logo'));
  return response.bodyBytes;
}

Future<List<List<Map<String, dynamic>>>> findMinimalCoalitions([int term = 10,int threshold = 231,int? maxCombinations]) async {
  final clubsResponse = await getClubs(term);
  List<Map<String, dynamic>> clubs = List<Map<String, dynamic>>.from(clubsResponse['data']);

  clubs.sort((a, b) => b['membersCount'].compareTo(a['membersCount']));

  maxCombinations ??= clubs.length;
  List<List<Map<String, dynamic>>> minimalCoalitions = [];
  Set<Set<String>> minimalCoalitionNames = {};

  for (int coalitionSize = 1; coalitionSize <= maxCombinations; coalitionSize++) {
    for (List<Map<String, dynamic>> coalition in combinations(clubs, coalitionSize)) {
      int totalMPs = coalition.fold(0, (sum, club) => sum + club['membersCount'] as int);
      Set<String> coalitionNames = coalition.map((club) => club['name'] as String).toSet();


      if (totalMPs >= threshold) {
        bool isMinimal = true;
        for (var existingNames in minimalCoalitionNames) {
          if (existingNames.containsAll(coalitionNames)) {
            isMinimal = false;
            break;
          }
        }

        if (isMinimal) {
          for (var club in coalition) {
            var subsetCoalition = List.from(coalition)..remove(club);
            int subsetMPs = subsetCoalition.fold(0, (sum, c) => sum + c['membersCount'] as int);
            if (subsetMPs < threshold) {
              isMinimal = true;
              break;
            }
            isMinimal = false;
          }
        }

        if (isMinimal && !minimalCoalitionNames.contains(coalitionNames)) {
          minimalCoalitions.add(coalition);
          minimalCoalitionNames.add(coalitionNames);
        }
      }
    }
  }

  return minimalCoalitions;
}

Iterable<List<T>> combinations<T>(List<T> items, int length) sync* {
  if (length == 0) {
    yield [];
  } else {
    for (int i = 0; i <= items.length - length; i++) {
      for (var tail in combinations(items.sublist(i + 1), length - 1)) {
        yield [items[i], ...tail];
      }
    }
  }
}

void printCoalitionsTable(List<List<Map<String, dynamic>>> coalitions) {
  print('Coalition\tClubs\t\tTotal MPs');
  int i = 1;
  for (var coalition in coalitions) {
    String clubs = coalition.map((club) => club['name']).join(', ');
    int totalMPs = coalition.fold(0, (sum, club) => sum + club['membersCount'] as int);
    print('$i\t$clubs\t$totalMPs');
    i++;
  }

  print('\nDetailed Club Breakdown:');
  i = 1;
  for (var coalition in coalitions) {
    print('\nCoalition $i:');
    for (var club in coalition) {
      print('Club: ${club['name']}, MPs: ${club['membersCount']}');
    }
    i++;
  }
}
