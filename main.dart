import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui';
import 'dart:ui_web' as ui;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  ui.platformViewRegistry.registerViewFactory('kakao-map-view', (int viewId) {
    final div =
        web.HTMLDivElement()
          ..id = 'kakao-map'
          ..style.width = '100%'
          ..style.height = '100%';

    Future.delayed(const Duration(seconds: 1), () {
      globalContext.callMethod('initKakaoMap'.toJS);
    });

    return div;
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PlaceSearchPage(),
    );
  }
}

class PlaceSearchPage extends StatefulWidget {
  const PlaceSearchPage({super.key});

  @override
  State<PlaceSearchPage> createState() => _PlaceSearchPageState();
}
Future<void> signInAnonymously() async {
  try {
    await FirebaseAuth.instance.signInAnonymously();
    print('익명 로그인 성공');
  } catch (e) {
    print('로그인 오류: $e');
  }
}

class _PlaceSearchPageState extends State<PlaceSearchPage> {
  final Map<String, String> regionCodeMap = {
    '종로구': '11110',
    '중구': '11140',
    '용산구': '11170',
    '성동구': '11200',
    '광진구': '11215',
    '동대문구': '11230',
    '중랑구': '11260',
    '성북구': '11290',
    '강북구': '11305',
    '도봉구': '11320',
    '노원구': '11350',
    '은평구': '11380',
    '서대문구': '11410',
    '마포구': '11440',
    '양천구': '11470',
    '강서구': '11500',
    '구로구': '11530',
    '금천구': '11545',
    '영등포구': '11560',
    '동작구': '11590',
    '관악구': '11620',
    '서초구': '11650',
    '강남구': '11680',
    '송파구': '11710',
    '강동구': '11740',
  };

  static const String sbizServiceKey =
      'bcc7bd3642c235f3be36850b43c02c5a5e59c26871dc48502273a47c569644c3';

  Future<Map<String, double>?> getRegionCoordinate(String region) async {
    final uri = Uri.parse(
      'https://dapi.kakao.com/v2/local/search/address.json'
      '?query=${Uri.encodeQueryComponent(region)}',
    );

    final response = await http.get(
      uri,
      headers: {'Authorization': 'KakaoAK $kakaoRestApiKey'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final documents = data['documents'];

      if (documents.isNotEmpty) {
        final first = documents[0];

        return {
          'x': double.parse(first['x']), // 경도
          'y': double.parse(first['y']), // 위도
        };
      }
    }

    return null;
  }

  final TextEditingController regionController = TextEditingController(
    text: '',
  );
  final TextEditingController keywordController = TextEditingController(
    text: '',
  );

  List<dynamic> places = [];
  bool isLoading = false;
  String errorMessage = '';

  // 여기에 카카오 REST API 키 넣기
  static const String kakaoRestApiKey = '8ddff68bae409484fe211e99220c0bd1';

  Future<void> searchPlaces() async {
    final region = regionController.text.trim();
    final keyword = keywordController.text.trim();

    if (region.isEmpty) return;

    final regionCode = regionCodeMap[region];

    if (regionCode == null) {
      setState(() {
        errorMessage = '지원하지 않는 지역입니다.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = '';
      places = [];
    });

    globalContext.callMethod('clearMarkers'.toJS);

    List<dynamic> allResults = [];

    try {
      for (int page = 1; page <= 100; page++) {
        final uri = Uri.parse(
          'https://apis.data.go.kr/B553077/api/open/sdsc2/storeListInDong'
          '?serviceKey=$sbizServiceKey'
          '&pageNo=$page'
          '&numOfRows=100'
          '&type=json'
          '&divId=signguCd'
          '&key=$regionCode',
        );

        final response = await http.get(uri);
        final data = jsonDecode(response.body);
        final items = data['body']['items'];

        if (items == null || items.isEmpty) break;

        // 🔥 키워드 필터
        final filtered =
            items.where((store) {
              final name = store['bizesNm']?.toString() ?? '';
              final small = store['indsSclsNm']?.toString() ?? '';
              final middle = store['indsMclsNm']?.toString() ?? '';

              return keyword.isEmpty ||
                  name.contains(keyword) ||
                  small.contains(keyword) ||
                  middle.contains(keyword);
            }).toList();

        allResults.addAll(filtered);
      }

      setState(() {
        places = allResults;
      });

      if (allResults.isNotEmpty) {
        showPlaceOnMap(allResults[0]);
      }
    } catch (e) {
      setState(() {
        errorMessage = '에러 발생: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void showPlaceOnMap(dynamic store) {
    final lat = double.tryParse(store['lat']?.toString() ?? '');
    final lng = double.tryParse(store['lon']?.toString() ?? '');

    if (lat == null || lng == null) return;

    final name = store['bizesNm'] ?? '상호명 없음';

    globalContext.callMethod(
      'moveMapTo'.toJS,
      lat.toJS,
      lng.toJS,
      name.toString().toJS,
    );
  }

  Future<void> loadCommentMarkers() async {
  final snapshot = await FirebaseFirestore.instance
      .collection('place_comments')
      .get();

  final Map<String, List<Map<String, dynamic>>> grouped = {};

  for (final doc in snapshot.docs) {
    final data = doc.data();

    final lat = data['latitude'];
    final lng = data['longitude'];

    if (lat == null || lng == null) continue;

    final key = '${lat}_${lng}';

    grouped.putIfAbsent(key, () => []);
    grouped[key]!.add(data);
  }

  grouped.forEach((key, reviews) {
    final first = reviews.first;

    final placeName = (first['placeName'] ?? '상호명 없음').toString();
    final lat = first['latitude'].toString();
    final lng = first['longitude'].toString();

    final avgRating = reviews
            .map((r) => (r['rating'] ?? 5) as num)
            .reduce((a, b) => a + b) /
        reviews.length;

    final commentsText = reviews.map((r) {
      final username = r['username'] ?? '익명';
      final rating = r['rating'] ?? 5;
      final comment = r['comment'] ?? '';
      return '⭐ $rating | $username: $comment';
    }).join('<br/><br/>');

    globalContext.callMethod(
      'addCommentMarker'.toJS,
      lat.toJS,
      lng.toJS,
      '<b>$placeName</b><br/>⭐ ${avgRating.toStringAsFixed(1)} · 후기 ${reviews.length}개'.toJS,
      commentsText.toJS,
    );
  });
}

  Future<void> showCommentDialog(BuildContext context, dynamic place) async {
    final commentController = TextEditingController();
    double rating = 5;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
  title: Text(place['bizesNm'] ?? '상호명 없음'),

  content: StatefulBuilder(
    builder: (context, setDialogState) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: List.generate(5, (index) {
              final starValue = index + 1;

              return IconButton(
                onPressed: () {
                  setDialogState(() {
                    rating = starValue.toDouble();
                  });
                },
                icon: Icon(
                  starValue <= rating
                      ? Icons.star
                      : Icons.star_border,
                  color: Colors.amber,
                ),
              );
            }),
          ),

          TextField(
            controller: commentController,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText: '이 장소에 대한 후기를 남겨주세요',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      );
    },
  ),

  
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('취소'),
            ),
            ElevatedButton(
  onPressed: () async {
    final comment = commentController.text.trim();

    if (comment.isEmpty) {
      return;
    }

    await FirebaseFirestore.instance
        .collection('place_comments')
        .add({
      'uid': FirebaseAuth.instance.currentUser?.uid,
      'username':
          FirebaseAuth.instance.currentUser?.displayName ??
          FirebaseAuth.instance.currentUser?.email ??
          '익명',
      'placeName': place['bizesNm'] ?? '상호명 없음',
      'address': place['rdnmAdr'] ?? place['lnoAdr'] ?? '',
      'comment': comment,
      'rating': rating,
      'latitude': double.tryParse(
        place['lat']?.toString() ?? '',
      ),
      'longitude': double.tryParse(
        place['lon']?.toString() ?? '',
      ),
      'createdAt': FieldValue.serverTimestamp(),
    });

    globalContext.callMethod('clearMarkers'.toJS);
    await loadCommentMarkers();

    Navigator.pop(context);
  },
  child: const Text('저장'),
),
          ],
        );
      },
    );
  }

  //후기 수정부분
  Future<void> editCommentDialog(
    BuildContext context,
    String docId,
    String oldComment,
  ) async {
    final controller = TextEditingController(text: oldComment);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('후기 수정'),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () async {
                await FirebaseFirestore.instance
                    .collection('place_comments')
                    .doc(docId)
                    .update({
                      'comment': controller.text.trim(),
                      'updatedAt': FieldValue.serverTimestamp(),
                    });

                Navigator.pop(context);
              },
              child: const Text('수정'),
            ),
          ],
        );
      },
    );
  }

  //후기 목록 함수
  Future<void> showMyCommentsDialog(BuildContext context) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;

  if (uid == null) {
    return;
  }

  final snapshot = await FirebaseFirestore.instance
      .collection('place_comments')
      .where('uid', isEqualTo: uid)
      .get();


    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('내 후기 목록'),
          content: SizedBox(
            width: 400,
            height: 400,
            child: ListView(
              children:
                  snapshot.docs.map((doc) {
                    final data = doc.data();

                    final placeName = data['placeName'] ?? '상호명 없음';
                    final comment = data['comment'] ?? '';

                    return ListTile(
                      title: Text(placeName),
                      subtitle: Text(comment),
                      trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    TextButton(
      child: const Text('수정'),
      onPressed: () {
        Navigator.pop(context);
        editCommentDialog(context, doc.id, comment);
      },
    ),
    TextButton(
      child: const Text(
        '삭제',
        style: TextStyle(color: Colors.red),
      ),
      onPressed: () async {
        await FirebaseFirestore.instance
            .collection('place_comments')
            .doc(doc.id)
            .delete();

        Navigator.pop(context);
        showMyCommentsDialog(context);
      },
    ),
  ],
),
                    );
                  }).toList(),
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();

    signInAnonymously();

    Future.delayed(const Duration(seconds: 2), () {
      searchPlaces();
      loadCommentMarkers();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('카카오 장소 검색 + 지도')),
      body: Row(
        children: [
          SizedBox(
            width: 400,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: regionController,
                    decoration: const InputDecoration(
                      hintText: '지역 예: 성북구',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: keywordController,
                    decoration: const InputDecoration(
                      hintText: '장소 예: 식당, 카페',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => searchPlaces(),
                  ),

                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        searchPlaces();
                      },
                      child: const Text('검색'),
                    ),
                  ),

                  const SizedBox(height: 8),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        showMyCommentsDialog(context);
                      },
                      child: const Text('내 후기 보기'),
                    ),
                  ),

                  const SizedBox(height: 16),
                  if (isLoading) const CircularProgressIndicator(),
                  if (errorMessage.isNotEmpty)
                    Expanded(
                      child: SingleChildScrollView(
                        child: Text(
                          errorMessage,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  if (!isLoading && errorMessage.isEmpty)
                    Expanded(
                      child: ListView.builder(
                        itemCount: places.length,
                        itemBuilder: (context, index) {
                          final place = places[index];

                          return Card(
                            child: ListTile(
                              title: Text(place['bizesNm'] ?? '상호명 없음'),
                              subtitle: Text(
                                '주소: ${place['rdnmAdr'] ?? place['lnoAdr'] ?? '-'}\n'
                                '업종: ${place['indsMclsNm'] ?? '-'} / ${place['indsSclsNm'] ?? '-'}\n'
                                '좌표: ${place['lon'] ?? '-'}, ${place['lat'] ?? '-'}',
                              ),
                              onTap: () {
                                showPlaceOnMap(place);
                                showCommentDialog(context, place);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: HtmlElementView(viewType: 'kakao-map-view'),
            ),
          ),
        ],
      ),
    );
  }
}
