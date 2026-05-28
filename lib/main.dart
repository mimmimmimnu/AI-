import 'dart:convert';
import 'dart:math' as math;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui;
 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;
 
class ChatMessage {
  final String text;
  final bool isUser;
  final bool isSystem;
  ChatMessage({required this.text, required this.isUser, this.isSystem = false});
}
 
class PlaceResult {
  final String name;
  final String address;
  final String roadAddress;
  final String category;
  final String phone;
  final double? lat;
  final double? lng;
  final String source;
  final String placeUrl;
  final String openHours;
 
  PlaceResult({
    required this.name, required this.address, required this.roadAddress,
    required this.category, required this.phone,
    this.lat, this.lng, required this.source,
    this.placeUrl = '', this.openHours = '',
  });
}
 
class CourseStep {
  String time;
  final String emoji;
  final String type;
  final String band;   // morning / lunch / afternoon / dinner / night
  final String duration;
  final String description;
  final String searchQuery;
  final String categoryCode;
  final String engine;
  PlaceResult? place;
  bool isSearching;
  int? travelMinutesFromPrev;

  CourseStep({
    required this.time, required this.emoji, required this.type,
    this.band = '',
    required this.duration, required this.description,
    required this.searchQuery, required this.categoryCode, required this.engine,
    this.place, this.isSearching = false, this.travelMinutesFromPrev,
  });
}
 
void main() {
  ui.platformViewRegistry.registerViewFactory('kakao-map-view', (int viewId) {
    final div = web.HTMLDivElement()
      ..id = 'kakao-map'
      ..style.width = '100%'
      ..style.height = '100%';
    Future.delayed(const Duration(seconds: 1), () {
      globalContext.callMethod('initKakaoMap'.toJS, div);
    });
    return div;
  });
  runApp(const MyApp());
}
 
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false, home: PlaceSearchPage());
}
 
class PlaceSearchPage extends StatefulWidget {
  const PlaceSearchPage({super.key});
  @override
  State<PlaceSearchPage> createState() => _PlaceSearchPageState();
}
 
class _PlaceSearchPageState extends State<PlaceSearchPage>
    with SingleTickerProviderStateMixin {
  static const String kakaoRestApiKey    = String.fromEnvironment('KAKAO_REST_API_KEY', defaultValue: '8ddff68bae409484fe211e99220c0bd1');
  static const String naverClientId      = String.fromEnvironment('NAVER_CLIENT_ID');
  static const String naverClientSecret  = String.fromEnvironment('NAVER_CLIENT_SECRET');
  static const String groqApiKey         = String.fromEnvironment('GROQ_API_KEY');
  static const String _groqModel         = 'llama-3.3-70b-versatile';

  static const Map<String, String> _districtHotspot = {
    '강남구': '신사동, 압구정동, 청담동, 삼성동',
    '용산구': '이태원동, 한남동, 해방촌',
    '마포구': '홍대입구, 연남동, 망원동',
    '성동구': '성수동, 서울숲',
    '종로구': '북촌, 인사동, 광화문',
    '중구':   '명동, 을지로, 충무로',
    '서초구': '반포동, 방배동',
    '송파구': '잠실동, 방이동',
    '강서구': '마곡동, 발산동',
    '영등포구': '여의도, 당산동',
    '광진구': '건대입구, 뚝섬',
    '성북구': '성신여대입구, 삼청동',
    '은평구': '연신내, 불광동',
    '동작구': '흑석동, 노량진',
  };

  static Map<String, String> _seasonTheme() {
    final m = DateTime.now().month;
    if (m >= 3 && m <= 5) {
      return {
        'key':'season','emoji':'🌸','label':'계절 특화형',
        'desc':'봄 — 벚꽃 명소와 야외 피크닉 중심',
        'places':'벚꽃 공원, 야외 카페, 피크닉 스팟, 강변 산책로',
        'hint':'봄 특화 규칙: search 필드에 반드시 실제 장소명(예: "남산공원", "석촌호수", "여의도 한강공원", "경의선숲길")을 사용할 것. '
            '"벚꽃 명소" 같은 추상적 표현 금지. 벚꽃·야외 관련 스텝은 공원 이름으로 검색.',
      };
    }
    if (m >= 6 && m <= 8) {
      return {
        'key':'season','emoji':'☀️','label':'계절 특화형',
        'desc':'여름 — 한강·루프탑·시원한 실내 중심',
        'places':'한강 수변공원, 루프탑 카페, 실내 미술관, 시원한 카페',
        'hint':'여름 특화 규칙: search 필드에 실제 장소명 사용(예: "한강공원", "뚝섬유원지"). '
            '"야외 풀장" 같은 추상적 표현 금지. 오후 뜨거운 시간엔 실내 배치, 저녁은 한강변.',
      };
    }
    if (m >= 9 && m <= 11) {
      return {
        'key':'season','emoji':'🍂','label':'계절 특화형',
        'desc':'가을 — 단풍 명소와 야외 활동 중심',
        'places':'단풍 공원, 궁궐 후원, 야외 카페, 트레킹 코스',
        'hint':'가을 특화 규칙: search 필드에 실제 장소명 사용(예: "남산공원", "창덕궁", "북한산 둘레길"). '
            '"단풍 명소" 같은 추상적 표현 금지. 야외 활동 비중을 높여 구성.',
      };
    }
    return {
      'key':'season','emoji':'❄️','label':'계절 특화형',
      'desc':'겨울 — 야경·실내 전시·따뜻한 카페 중심',
      'places':'야경 명소, 실내 전시, 따뜻한 카페',
      'hint':'겨울 특화 규칙: search 필드에 실제 장소명 사용(예: "청계천", "남산타워", "DDP"). '
            '"야경 명소" 같은 추상적 표현 금지. 이동 거리 최소화, 낮은 실내 위주.',
    };
  }

  static List<Map<String, String>> get _themes => [
    {'key':'healing','label':'정적인 힐링형','emoji':'🌿','desc':'여유롭고 조용한 분위기','places':'조용한 카페, 공원 산책, 한강, 북카페, 소품샵'},
    _seasonTheme(),
    {'key':'food',   'label':'미식 탐방형', 'emoji':'🍽️','desc':'맛집과 디저트 중심','places':'이색 레스토랑, 유명 베이커리, 디저트 카페, 와인바'},
    {'key':'culture','label':'문화 감성형', 'emoji':'🎨','desc':'감성적인 문화 체험','places':'미술관, 전시회, 독립서점, 힙한 골목, 팝업스토어'},
  ];
 
  static const Map<String, String> categoryLabels = {
    'FD6':'음식점','CE7':'카페','AT4':'관광명소','AD5':'숙박','CT1':'문화시설','MT1':'쇼핑',
  };
 
  final TextEditingController searchController       = TextEditingController();
  final TextEditingController chatInputController    = TextEditingController();
  final TextEditingController _courseInputController = TextEditingController();
  final ScrollController      chatScrollController   = ScrollController();
 
  List<PlaceResult> places      = [];
  List<ChatMessage> chatMessages = [];
  List<CourseStep>  _courseSteps = [];
 
  bool   isLoading        = false;
  bool   isChatLoading    = false;
  bool   _isCourseLoading = false;
  String errorMessage     = '';
  String _courseError     = '';
  String _selectedThemeKey  = '';
  String currentCategoryCode = '';
  int?   selectedPlaceIndex;
 
  List<Map<String, dynamic>> _localSpots  = [];
  List<Map<String, dynamic>> _restaurants = [];
 
  late final TabController _tabController;
 
  // ─── 시스템 프롬프트 ──────────────────────────────────────
  static const String _systemPrompt = '''
당신은 카카오맵 기반 데이트 코스 및 장소 추천 AI 어시스턴트입니다.
 
[장소 추천 규칙]
1. [검색결과] 목록에 있는 장소만 추천하세요. 절대 지어내지 마세요.
2. "다른 거 알려줘" → 아직 추천 안 한 [검색결과] 항목 추천.
3. [검색결과] 소진 시 다른 키워드로 재검색하세요.
4. 검색 결과 없으면 즉시 [SEARCH:...]로 검색하세요.
 
[검색 명령 형식 — 반드시 대괄호 사용]
[SEARCH:검색어:카테고리코드:엔진]
 
엔진 선택:
- naver: "조용한", "아늑한", "분위기 좋은", "힙한", "감성적인", "로맨틱한" 등 감성 키워드
- kakao: 음식 종류, 지역+업종, 브랜드명 등 일반 검색
 
카테고리: FD6=음식점, CE7=카페, AT4=관광명소, CT1=문화시설, MT1=쇼핑
 
[엔진 선택 규칙]
- engine="naver" : 분위기/감성/추상적 검색어 (데이트, 핫플, 감성카페, 뷰 맛집 등)
- engine="kakao" : 구체적인 음식 종류·업종명 (파스타, 스시, 브런치 등)

[검색 예시]
"파스타 집 추천해줘" → [SEARCH:강남 파스타:FD6:kakao]
"성북구 데이트 장소" → [SEARCH:성북구 데이트 핫플:AT4:naver]
"조용한 카페 성북구" → [SEARCH:성북구 조용한 카페:CE7:naver]

잡담에는 [SEARCH:] 없이 한국어로 친절하게 답변하세요.
''';
 
  // ─── 코스 생성 프롬프트 ───────────────────────────────────
  String _buildCoursePrompt({
    required String region,
    required String themeLine,
    required String mandatoryNote,
    required String spotsContext,
    required String restaurantCtx,
    required String userPreferences,
  }) {
    final hotspot = _districtHotspot[region] ?? '';
    final hotspotHint = hotspot.isNotEmpty
        ? '\n[핵심 동네 — 이 중에서 1~2곳을 골라 모든 search 쿼리에 반영하세요]: $hotspot'
        : '';
    return '''
You are a Korean date course planner for Seoul couples.
Reply ONLY with a valid JSON array. No markdown, no explanation.

$themeLine
Region: $region$hotspotHint$mandatoryNote$spotsContext$restaurantCtx$userPreferences

═══════════════════════════════════════════
STEP 1 — 핵심 동네 선정 (내부 사고, 출력 안 함)
═══════════════════════════════════════════
[핵심 동네] 목록에서 도보 이동 가능한 동네 1~2곳을 먼저 선정하세요.
이후 모든 장소는 그 동네 안에서만 찾습니다.

═══════════════════════════════════════════
STEP 2 — 코스 구성 규칙
═══════════════════════════════════════════
코스는 아래 5개 슬롯을 반드시 이 순서대로 채우세요:

슬롯 1 (morning)  : 오전 활동 1~2개 — 카페 or 공원 산책
슬롯 2 (lunch)    : 점심 식사 1개   — 반드시 FD6, 12시 전후
슬롯 3 (afternoon): 오후 활동 1~2개 — 관광/문화/쇼핑
슬롯 4 (dinner)   : 저녁 식사 1개   — 반드시 FD6, 18시 전후
슬롯 5 (night)    : 야간 활동 1개   — 야경/바/산책, 20시 이후

총 5~7개 스텝. 슬롯 순서 절대 변경 금지.

═══════════════════════════════════════════
STEP 3 — search 쿼리 작성 규칙 (가장 중요)
═══════════════════════════════════════════
search 필드는 카카오맵에서 실제로 검색될 쿼리입니다.
반드시 "<동네명> <구체적 장소 특성>" 형식으로 작성하세요.

✅ 올바른 예시:
  "한남동 브런치 카페"
  "이태원 분위기 좋은 이탈리안"
  "청담동 오마카세"
  "연남동 루프탑 바"
  "성수동 갤러리"

❌ 절대 금지:
  "$region 카페"       → 구 단위 단독 사용 금지
  "레스토랑"            → 지역명 없음 금지
  "맛있는 집"           → 장소명이 아닌 표현 금지
  "$region 관광명소"   → 너무 광범위한 표현 금지
  "분위기 좋은 곳"      → 지역명 없음 금지

search 쿼리가 실제 카카오맵 검색 결과를 결정합니다.
추상적이거나 지역명 없는 쿼리는 엉뚱한 장소를 반환합니다.

═══════════════════════════════════════════
STEP 4 — 동선 규칙
═══════════════════════════════════════════
- 모든 장소는 선정한 핵심 동네 반경 1.5km 이내
- 연속된 두 장소 간 도보 이동: 최대 15분 이내
- 지그재그 이동 금지: 한 방향으로 흐르는 코스

═══════════════════════════════════════════
STEP 5 — 장소 선정 금지 목록
═══════════════════════════════════════════
절대 포함 금지:
- 오피스텔, 아파트, 주상복합, 상가 건물
- 주차장, 카셰어링 존 (쏘카, 그린카 등)
- 관공서 (구청, 주민센터, 경찰서 등)
- 구내식당, 직원식당, 급식소
- 병원, 약국, 은행
- "OO 산책길" 같은 불특정 장소

═══════════════════════════════════════════
출력 형식 (이 형식만 허용)
═══════════════════════════════════════════
[
  {
    "band": "morning",
    "emoji": "☕",
    "type": "카페",
    "duration": "1시간 30분",
    "description": "한남동 감성 카페에서 여유로운 시작",
    "search": "한남동 감성 브런치 카페",
    "category": "CE7",
    "engine": "naver"
  }
]

필드 규칙:
- band    : morning / lunch / afternoon / dinner / night 중 하나
- emoji   : 슬롯에 맞는 이모지
- type    : 한국어 2~5자 (예: 카페, 점심, 관광, 저녁, 야경)
- duration: "X시간" 또는 "X시간 Y분"
- description: 20자 이내 한국어 한 줄 설명
- search  : 반드시 "<동네명> <구체적 특성>" 형식
- category: CE7 / FD6 / AT4 / CT1 / MT1 중 하나
- engine  : "naver"(감성/분위기) 또는 "kakao"(구체적 업종)

lunch/dinner는 반드시 category="FD6", engine="kakao".
야경/바는 반드시 engine="naver".
''';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadLocalSpots();
    _loadRestaurants();
  }
 
  @override
  void dispose() {
    _tabController.dispose();
    chatInputController.dispose();
    chatScrollController.dispose();
    searchController.dispose();
    _courseInputController.dispose();
    super.dispose();
  }
 
  Future<void> _loadLocalSpots() async {
    try {
      final s = await rootBundle.loadString('assets/spots.json');
      _localSpots = (jsonDecode(s) as List).cast<Map<String, dynamic>>();
    } catch (_) {}
  }
 
  Future<void> _loadRestaurants() async {
    try {
      final s = await rootBundle.loadString('assets/restaurants.json');
      _restaurants = (jsonDecode(s) as List).cast<Map<String, dynamic>>();
    } catch (_) {}
  }
 
  List<Map<String, dynamic>> _getTopRestaurants({String mealType = 'meal', bool forTourist = true, int limit = 5}) {
    final cats = mealType == 'cafe' ? ['카페/찻집']
        : mealType == 'dinner' ? ['한식','전문음식','외국식','음식점기타']
        : ['한식','간이음식','전문음식','외국식','음식점기타'];
    final key = forTourist ? 'rank_tourist' : 'rank_local';
    return (_restaurants.where((r) => cats.contains(r['category'])).toList()
      ..sort((a, b) => (a[key] as int).compareTo(b[key] as int))).take(limit).toList();
  }
 
  List<Map<String, dynamic>> _getSpotsForRegion(String region) =>
      (_localSpots.where((s) {
        final d = s['district'] as String;
        return d.contains(region) || region.contains(d.replaceAll('구', ''));
      }).toList()..sort((a, b) => (a['rank'] as int).compareTo(b['rank'] as int)));
 
  List<String> _getCategoriesForTheme(String key) {
    final m = DateTime.now().month;
    return switch (key) {
      'healing' => ['자연관광','기타관광','문화관광'],
      'season'  => (m >= 6 && m <= 8)
          ? ['자연관광','기타관광','문화관광']          // 여름: 수변+실내
          : (m >= 12 || m <= 2)
              ? ['문화관광','역사관광','기타관광']       // 겨울: 실내+야경
              : ['자연관광','기타관광','역사관광'],      // 봄/가을: 야외+명소
      'culture' => ['문화관광','역사관광','체험관광','쇼핑'],
      'food'    => ['문화관광','기타관광','쇼핑','자연관광'],
      _         => ['문화관광','기타관광','역사관광','자연관광'],
    };
  }
 
  // ─── Groq 호출 ────────────────────────────────────────────
  Future<String> _callGroq(List<Map<String, String>> messages, {bool jsonMode = false}) async {
    if (groqApiKey.isEmpty) throw Exception('API 키 없음');
    final body = <String, dynamic>{'model': _groqModel, 'messages': messages};
    if (jsonMode) body['response_format'] = {'type': 'json_object'};
    final res = await http.post(
      Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $groqApiKey'},
      body: jsonEncode(body),
    );
    if (res.statusCode == 401) throw Exception('API 키 오류');
    if (res.statusCode != 200) throw Exception('Groq ${res.statusCode}: ${res.body}');
    return jsonDecode(utf8.decode(res.bodyBytes))['choices'][0]['message']['content'] as String;
  }
 
  // ─── 네이버 검색 ─────────────────────────────────────────
  Future<List<PlaceResult>> _searchNaver(String query) async {
    final res = await http.get(
      Uri.parse('https://openapi.naver.com/v1/search/local.json'
          '?query=${Uri.encodeQueryComponent(query)}&display=5&sort=sim'),
      headers: {'X-Naver-Client-Id': naverClientId, 'X-Naver-Client-Secret': naverClientSecret},
    );
    if (res.statusCode != 200) throw Exception('네이버 API ${res.statusCode}');
    final items = jsonDecode(res.body)['items'] as List;
    String strip(String s) => s.replaceAll(RegExp(r'<[^>]*>'), '').trim();
    return await Future.wait(items.map((item) async {
      final road = item['roadAddress'] ?? '';
      final addr = item['address'] ?? '';
      final coord = await _getCoordFromAddress(road.isNotEmpty ? road : addr);
      return PlaceResult(
        name: strip(item['title'] ?? ''), address: addr, roadAddress: road,
        category: item['category'] ?? '', phone: item['telephone'] ?? '',
        lat: coord?['lat'], lng: coord?['lng'], source: 'naver',
      );
    }));
  }
 
  // ─── 카카오 주소→좌표 ───────────────────────────────────
  Future<Map<String, double>?> _getCoordFromAddress(String address) async {
    if (address.isEmpty) return null;
    final clean = address.replaceAll(RegExp(r'\s+(?:\d+[Ff층호]|B\d+|지하\d+층?).*$'), '').trim();
    for (final q in [clean, address]) {
      try {
        final res = await http.get(
          Uri.parse('https://dapi.kakao.com/v2/local/search/address.json?query=${Uri.encodeQueryComponent(q)}'),
          headers: {'Authorization': 'KakaoAK $kakaoRestApiKey'},
        );
        if (res.statusCode == 200) {
          final docs = jsonDecode(res.body)['documents'] as List;
          if (docs.isNotEmpty) return {
            'lat': double.parse(docs[0]['y'].toString()),
            'lng': double.parse(docs[0]['x'].toString()),
          };
        }
      } catch (_) {}
    }
    return null;
  }
 
  // ─── 카카오 키워드 검색 ──────────────────────────────────
  Future<List<PlaceResult>> _searchKakao(String query, String categoryCode, {
    double? centerLat, double? centerLng, int radius = 3000, int size = 5,
  }) async {
    final cat = categoryCode.isNotEmpty ? '&category_group_code=$categoryCode' : '';
    final loc = (centerLat != null && centerLng != null)
        ? '&x=$centerLng&y=$centerLat&radius=$radius&sort=distance'
        : '&sort=accuracy';
    final res = await http.get(
      Uri.parse('https://dapi.kakao.com/v2/local/search/keyword.json'
          '?query=${Uri.encodeQueryComponent(query)}$cat$loc&size=$size'),
      headers: {'Authorization': 'KakaoAK $kakaoRestApiKey'},
    );
    if (res.statusCode == 400) return []; // 잘못된 쿼리 → 빈 결과 (예외 X)
    if (res.statusCode != 200) throw Exception('카카오 API ${res.statusCode}');
    return (jsonDecode(res.body)['documents'] as List).map((p) => PlaceResult(
      name: p['place_name'] ?? '', address: p['address_name'] ?? '',
      roadAddress: p['road_address_name'] ?? '', category: p['category_name'] ?? '',
      phone: p['phone'] ?? '',
      lat: double.tryParse(p['y']?.toString() ?? ''),
      lng: double.tryParse(p['x']?.toString() ?? ''),
      source: 'kakao', placeUrl: p['place_url'] ?? '',
    )).toList();
  }
 
  // ─── 영업시간 조회 ───────────────────────────────────────
  // 영업 상태 조회: (영업시간 문자열, 지금 영업 중 여부)
  // isOpen=true → 영업 중 or 정보 없음(포함), false → 오늘 휴무/영업 전/후
  Future<(String, bool)> _fetchOpenStatus(String placeId, String bandTime) async {
    if (placeId.isEmpty) return ('', true);
    try {
      final res = await http.get(
        Uri.parse('https://place.map.kakao.com/main/v/$placeId'),
        headers: {'Referer': 'https://map.kakao.com'},
      );
      if (res.statusCode != 200) return ('', true);
      final data = jsonDecode(res.body);
      final openHour = data['basicInfo']?['openHour'];
      if (openHour == null) return ('', true);

      // 정기 휴무일 확인 (weekAndDay: "0/1" = 매주 월, "1/1" = 첫째주 월)
      final offdayList = openHour['offdayList'];
      if (offdayList is List) {
        final now = DateTime.now();
        for (final offday in offdayList) {
          final wd = offday['weekAndDay']?.toString() ?? '';
          final parts = wd.split('/');
          if (parts.length == 2) {
            final week = int.tryParse(parts[0]) ?? -1;
            final day  = int.tryParse(parts[1]) ?? -1;
            final todayWeek = ((now.day - 1) ~/ 7) + 1;
            if (day == now.weekday && (week == 0 || week == todayWeek)) {
              return ('휴무', false);
            }
          }
        }
      }

      // 영업시간대 확인
      final periodList = openHour['periodList'];
      if (periodList is List && periodList.isNotEmpty) {
        final timeList = periodList[0]['timeList'];
        if (timeList is List && timeList.isNotEmpty) {
          final t = timeList[0];
          final open  = t['startTime']?.toString() ?? '';
          final close = t['endTime']?.toString()   ?? '';
          if (open.isNotEmpty && close.isNotEmpty) {
            return ('$open~$close', _isOpenAtBandTime(open, close, bandTime));
          }
        }
      }
    } catch (_) {}
    return ('', true);
  }

  static bool _isOpenAtBandTime(String start, String end, String bandTime) {
    try {
      int toMin(String t) =>
          int.parse(t.substring(0, 2)) * 60 + int.parse(t.substring(2, 4));
      final bp = bandTime.split(':');
      final bandMin  = int.parse(bp[0]) * 60 + int.parse(bp[1]);
      final openMin  = toMin(start);
      final closeMin = toMin(end);
      if (closeMin <= openMin) return bandMin >= openMin || bandMin <= closeMin;
      return bandMin >= openMin && bandMin <= closeMin;
    } catch (_) {
      return true;
    }
  }
 
  // ─── 부적절 장소 필터 ────────────────────────────────────
  static const _blocked = [
    '구내식당','직원식당','학생식당','사원식당','급식소','여성전용','남성전용',
    '구청','시청','주민센터','동사무소','구의회','시의회','세무서','경찰서',
    '소방서','우체국','보건소','복지관','관공서','행정복지센터','출입국',
    '행복플러스','사회적기업','자활센터',
  ];
  List<PlaceResult> _filter(List<PlaceResult> r) => r.where((p) {
    final s = '${p.name} ${p.category} ${p.address}';
    return !_blocked.any((k) => s.contains(k));
  }).toList();
 
  // ─── 통합 검색 ───────────────────────────────────────────
  Future<void> searchPlaces(String query, {
    String categoryCode = '', String engine = 'naver', bool fromChat = false,
  }) async {
    if (query.isEmpty) return;
    setState(() { isLoading = true; errorMessage = ''; places = []; selectedPlaceIndex = null; currentCategoryCode = categoryCode; });
    globalContext.callMethod('clearMarkers'.toJS);
    try {
      // kakao 검색 → 결과 없으면 naver 폴백
      List<PlaceResult> results = engine == 'naver'
          ? await _searchNaver(query)
          : await _searchKakao(query, categoryCode);
      if (results.isEmpty && engine != 'naver') results = await _searchNaver(query);
      final usedEngine = (results.isNotEmpty && engine != 'naver' && results[0].source == 'naver') ? 'naver' : engine;

      setState(() => places = results);
      if (results.isNotEmpty) { _showPlaceOnMap(results[0]); setState(() => selectedPlaceIndex = 0); }
      if (fromChat) {
        final lbl = categoryLabels[categoryCode] ?? '';
        final engLabel = usedEngine == 'naver' ? '네이버' : '카카오';
        setState(() => chatMessages.add(ChatMessage(
          text: results.isNotEmpty
              ? '[검색결과] "$query"${lbl.isNotEmpty ? " [$lbl]" : ""} ($engLabel) ${results.length}개:\n'
                  + results.asMap().entries.map((e) {
                      final p = e.value;
                      final a = p.roadAddress.isNotEmpty ? p.roadAddress : p.address;
                      return '${e.key+1}. ${p.name} | $a | ${p.category}';
                    }).join('\n')
              : '[검색결과] "$query" 결과 없음.',
          isUser: false, isSystem: true,
        )));
      }
    } catch (e) { setState(() => errorMessage = '검색 오류: $e'); }
    finally { setState(() => isLoading = false); }
  }
 
  // ─── 쇼핑 판별 ───────────────────────────────────────────
  String _shoppingCode(String name) {
    const kw = ['아이파크몰','현대백화점','롯데백화점','신세계','갤러리아','코엑스몰','타임스퀘어','스타필드','더현대','몰','백화점','쇼핑몰','아울렛'];
    return kw.any((k) => name.contains(k)) ? 'MT1' : '';
  }
 
  // ─── mandatory 추출 ──────────────────────────────────────
  String? _extractMandatory(String query) {
    for (final p in [
      RegExp(r'(.{1,20}?)(?:는|을|이|가)?\s*(?:꼭|반드시|무조건)\s*(?:넣어|포함|추가)'),
      RegExp(r'([가-힣a-zA-Z0-9 ·&]{2,20}?)\s*(?:이|가|을|를|은|는|에)?\s*(?:꼭\s*)?(?:가고\s*싶|가보고\s*싶|들르고\s*싶|방문하고\s*싶|가봐야)'),
      RegExp(r'([가-힣a-zA-Z0-9 ·&]{2,20}?)\s*(?:을|를|이|가|은|는)?\s*(?:중심으로|위주로|포함해서|포함하여|포함시켜|넣어서|꼭\s*넣어)'),
    ]) {
      final m = p.firstMatch(query);
      if (m != null) return m.group(1)?.trim();
    }
    return null;
  }
 
  // ─── 사용자 선호 추출 ─────────────────────────────────────
  String _extractUserPreferences(List<ChatMessage> history) {
    final dislikes = <String>[], likes = <String>[];
    for (final msg in history.where((m) => m.isUser)) {
      final dm = RegExp(r'([가-힣a-zA-Z]+)(?:은|는|이|가)?\s*(?:싫어|별로|빼줘|제외|없이)').firstMatch(msg.text);
      if (dm != null) dislikes.add(dm.group(1)!);
      final lm = RegExp(r'([가-힣a-zA-Z]+)(?:은|는|이|가)?\s*(?:좋아|원해|넣어|포함|위주)').firstMatch(msg.text);
      if (lm != null) likes.add(lm.group(1)!);
    }
    if (dislikes.isEmpty && likes.isEmpty) return '';
    return [
      if (dislikes.isNotEmpty) '\n[사용자 거부 — 절대 포함 금지]: ${dislikes.join(", ")}',
      if (likes.isNotEmpty)    '\n[사용자 선호 — 우선 반영]: ${likes.join(", ")}',
    ].join('\n');
  }
 
  // ─── 코스 생성 ───────────────────────────────────────────
  Future<void> _generateCourse({String? queryOverride}) async {
    final query = queryOverride ?? _courseInputController.text.trim();
    if (query.isEmpty || _isCourseLoading) return;
    final theme = _selectedThemeKey.isNotEmpty
        ? _themes.firstWhere((t) => t['key'] == _selectedThemeKey) : null;
    setState(() { _isCourseLoading = true; _courseSteps = []; _courseError = ''; });
    globalContext.callMethod('clearMarkers'.toJS);
 
    try {
      // ── 지역 파싱 ──
      const validDistricts = {
        '강남구','강동구','강북구','강서구','관악구','광진구','구로구','금천구',
        '노원구','도봉구','동대문구','동작구','마포구','서대문구','서초구',
        '성동구','성북구','송파구','양천구','영등포구','용산구','은평구','종로구','중구','중랑구',
      };
      final dm = RegExp(r'강남|강동|강북|강서|관악|광진|구로|금천|노원|도봉|동대문|동작|'
          r'마포|서대문|서초|성동|성북|송파|양천|영등포|용산|은평|종로|중구|중랑').firstMatch(query);
      final rm = RegExp(r'^(\S+?)(?:에서|에|의|은|는|,|\s)').firstMatch(query);
      final raw = dm?.group(0) ?? rm?.group(1) ?? query.split(' ').first;
      final region = raw.endsWith('구') ? raw : '${raw}구';
 
      if (!validDistricts.contains(region)) {
        setState(() { _courseError = '어느 구에서 코스를 원하세요?\n예: "용산에서 코스 짜줘"'; _isCourseLoading = false; });
        return;
      }
 
      // ── 구별 중심 좌표 ──
      const centers = {
        '용산구':[37.5340,126.9947],'강남구':[37.5172,127.0473],'마포구':[37.5560,126.9234],
        '종로구':[37.5704,126.9831],'중구':[37.5640,126.9979],'서초구':[37.4836,127.0323],
        '송파구':[37.5145,127.1058],'강서구':[37.5509,126.8495],'영등포구':[37.5260,126.8963],
        '성동구':[37.5633,127.0368],'광진구':[37.5384,127.0823],'동대문구':[37.5744,127.0395],
        '중랑구':[37.6063,127.0928],'성북구':[37.5894,127.0167],'강북구':[37.6397,127.0255],
        '도봉구':[37.6688,127.0470],'노원구':[37.6549,127.0563],'은평구':[37.6027,126.9291],
        '서대문구':[37.5791,126.9368],'양천구':[37.5170,126.8664],'강동구':[37.5301,127.1237],
        '동작구':[37.5124,126.9395],'관악구':[37.4784,126.9516],'금천구':[37.4600,126.9001],
        '구로구':[37.4954,126.8872],
      };
      double? cLat, cLng;
      if (centers.containsKey(region)) {
        cLat = centers[region]![0]; cLng = centers[region]![1];
      } else {
        final c = await _getCoordFromAddress(region);
        cLat = c?['lat']; cLng = c?['lng'];
      }
 
      // ── mandatory ──
      final mandatory = _extractMandatory(query);
      final rawD = region.replaceAll('구', '');
      final mandStripped = mandatory != null
          ? mandatory.replaceAll(region, '').replaceAll(rawD, '').trim() : '';
      final mandLabel = mandStripped.isNotEmpty ? mandStripped : (mandatory ?? '');
      final isMandShop = _shoppingCode(mandLabel) == 'MT1';
      final mandNote = mandatory != null
          ? '\n\n[사용자 명시 장소 — 절대 규칙]\n'
              '"$mandLabel"을 반드시 1~2번째 step에 배치하세요.\n'
              'type: "${isMandShop ? "쇼핑" : mandLabel}", search: "$mandLabel"\n'
              '내부 입점 매장 추천 금지. 시설 자체를 포함하세요.' : '';
 
      // ── 인기 관광지 사전 검색 ──
      final themeCategories = theme != null
          ? _getCategoriesForTheme(_selectedThemeKey)
          : ['문화관광','자연관광','역사관광','체험관광','기타관광','쇼핑','레저스포츠'];
      final topSpots = _getSpotsForRegion(region)
          .where((s) => themeCategories.contains(s['category'] as String)).take(2).toList();
 
      final Map<String, PlaceResult> preResolved = {};
      for (final spot in topSpots) {
        final name = spot['name'] as String;
        try {
          final r = _filter(await _searchKakao(name, 'AT4', centerLat: cLat, centerLng: cLng, radius: 2000));
          final f = r.where((p) => '${p.address} ${p.roadAddress}'.contains(region)).toList();
          if (f.isNotEmpty) preResolved[name] = f[0];
        } catch (_) {}
      }
 
      // ── mandatory 사전 검색 ──
      PlaceResult? mandResult;
      if (mandatory != null) {
        try {
          final cat = _shoppingCode(mandLabel);
          var r = await _searchKakao(mandLabel, cat, centerLat: cLat, centerLng: cLng, radius: 5000, size: 10);
          if (r.isEmpty) r = await _searchKakao('$region $mandLabel', cat, centerLat: cLat, centerLng: cLng, radius: 5000, size: 10);
          if (r.isEmpty) r = await _searchKakao(mandLabel, '', centerLat: cLat, centerLng: cLng, radius: 5000, size: 10);
          if (r.isNotEmpty) {
            r.sort((a, b) => _nameScore(a.name, mandLabel).compareTo(_nameScore(b.name, mandLabel)));
            mandResult = r[0];
            for (final key in [mandatory, '$region $mandatory', mandStripped, '$region $mandStripped', mandLabel]) {
              if (key.isNotEmpty) preResolved[key] = r[0];
            }
          }
        } catch (_) {}
      }
 
      // ── 프롬프트 컨텍스트 ──
      final spotsCtx = topSpots.isNotEmpty
          ? '\n\n[방문객 데이터 기반 필수 관광지 - 반드시 포함]\n'
              + topSpots.map((s) => '- "${s['name']}" (${s['category']})').join('\n') : '';
      final lunch  = _getTopRestaurants(mealType: 'meal',   limit: 5);
      final dinner = _getTopRestaurants(mealType: 'dinner', limit: 5);
      final cafe   = _getTopRestaurants(mealType: 'cafe',   limit: 3);
      final restCtx = _restaurants.isNotEmpty
          ? '\n\n[인기 맛집]\n점심: ${lunch.map((r) => '"${r['name']}"').join(', ')}\n'
              '저녁: ${dinner.map((r) => '"${r['name']}"').join(', ')}\n'
              '카페: ${cafe.map((r) => '"${r['name']}"').join(', ')}' : '';
      final seasonHint = (theme != null && theme['key'] == 'season' && theme['hint'] != null)
          ? '\n\n[계절 특화 추가 규칙]\n${theme['hint']}'
          : '';
      final themeLine = theme != null
          ? 'Theme: ${theme['label']} (${theme['desc']})\nActivities (참고용): ${theme['places']}$seasonHint'
          : 'Theme: 인기 관광지 코스 (테마 없음)';
      final userPref = _extractUserPreferences(chatMessages);
 
      // ── Groq 호출 ──
      String rawReply = '';
      for (int attempt = 1; attempt <= 3; attempt++) {
        try {
          rawReply = await _callGroq([
            {'role': 'system', 'content': _buildCoursePrompt(
              region: region, themeLine: themeLine, mandatoryNote: mandNote,
              spotsContext: spotsCtx, restaurantCtx: restCtx, userPreferences: userPref,
            )},
            {'role': 'user', 'content': query},
          ]);
          break;
        } catch (e) {
          if (attempt == 3 || !e.toString().contains('429')) rethrow;
          final retryMatch =
              RegExp(r'(?:retry|again) in (\d+(?:\.\d+)?)s').firstMatch(e.toString());
          final waitSecs =
              retryMatch != null ? double.parse(retryMatch.group(1)!).ceil() : 65;
          for (int i = waitSecs; i > 0; i--) {
            setState(() => _courseError = '⏳ API 한도 초과 — $i초 후 자동 재시도 ($attempt/3)...');
            await Future.delayed(const Duration(seconds: 1));
          }
          setState(() => _courseError = '');
        }
      }
 
      // ── JSON 파싱 ──
      final cleaned = rawReply
          .replaceAll(RegExp(r'```json\s*'), '').replaceAll(RegExp(r'```\s*'), '').trim();
      List<dynamic> stepsJson;
      final arrMatch = RegExp(r'\[[\s\S]+\]').firstMatch(cleaned);
      if (arrMatch != null) {
        stepsJson = jsonDecode(arrMatch.group(0)!) as List;
      } else {
        final dec = jsonDecode(cleaned);
        stepsJson = dec is List ? dec
            : (dec['steps'] ?? dec['course'] ?? dec.values.firstWhere((v) => v is List)) as List;
      }
      if (stepsJson.isEmpty) throw Exception('코스 파싱 실패');
 
      String bandToTime(String band) => switch (band) {
        'lunch'     => '12:00',
        'afternoon' => '14:00',
        'dinner'    => '18:00',
        'night'     => '20:00',
        _           => '10:00', // morning
      };

      // band 기준으로 정렬 (morning→lunch→afternoon→dinner→night)
      const bandOrder = {'morning':0,'lunch':1,'afternoon':2,'dinner':3,'night':4};
      stepsJson.sort((a, b) {
        final ba = bandOrder[(a['band'] ?? 'morning').toString()] ?? 0;
        final bb = bandOrder[(b['band'] ?? 'morning').toString()] ?? 0;
        return ba.compareTo(bb);
      });

      final steps = stepsJson.map((item) {
        final band = (item['band'] ?? 'morning').toString();
        // 하위호환: AI가 time을 줬으면 그대로, band를 줬으면 변환
        final time = item['time'] != null
            ? item['time'].toString()
            : bandToTime(band);
        return CourseStep(
          time: time,
          emoji: (item['emoji'] ?? '📍').toString(),
          type: (item['type'] ?? '').toString(),
          band: band,
          duration: (item['duration'] ?? '1시간').toString(),
          description: (item['description'] ?? '').toString(),
          searchQuery: (item['search'] ?? '').toString(),
          categoryCode: (item['category'] ?? '').toString(),
          engine: (item['engine'] ?? 'kakao').toString(),
        );
      }).toList();
 
      // 사전 검색 결과 주입
      for (int i = 0; i < steps.length; i++) {
        PlaceResult? r = preResolved[steps[i].searchQuery];
        if (r == null) {
          for (final e in preResolved.entries) {
            if (e.key.length > 2 && steps[i].searchQuery.contains(e.key)) { r = e.value; break; }
          }
        }
        if (r != null) steps[i].place = r;
      }
 
      setState(() { _courseSteps = steps; _isCourseLoading = false; });
 
      final usedNames = <String>{...preResolved.values.map((p) => p.name)};
 
      // ── 모든 단계 병렬 검색 (구 중심 기준) ──
      setState(() {
        for (int i = 0; i < _courseSteps.length; i++) {
          if (_courseSteps[i].place == null && _courseSteps[i].searchQuery.isNotEmpty) {
            _courseSteps[i].isSearching = true;
          }
        }
      });

      final allCandidates = await Future.wait(
        _courseSteps.map((s) => (s.place != null || s.searchQuery.isEmpty)
            ? Future.value(<PlaceResult>[])
            : _searchStepCandidates(s, region, cLat, cLng)),
      );

      // 중복 없이 순서대로 배정
      for (int i = 0; i < _courseSteps.length; i++) {
        if (_courseSteps[i].place != null) {
          _addCourseMarker(_courseSteps[i].place!, i + 1);
          continue;
        }
        final candidates = allCandidates[i].where((p) => !usedNames.contains(p.name)).toList();
        if (candidates.isEmpty) {
          setState(() => _courseSteps[i].isSearching = false);
          continue;
        }
        // 이전 장소 기준 도보 거리 우선 정렬 (가까운 곳 우선)
        List<PlaceResult> sortedCandidates = candidates;
        if (i > 0) {
          final prevList = _courseSteps.sublist(0, i)
              .where((s) => s.place?.lat != null).toList();
          final prev = prevList.isNotEmpty ? prevList.last.place : null;
          if (prev != null) {
            final walks = await Future.wait(
              candidates.take(5).map((c) => _getTravelMinutes(prev, c)));
            final zipped = List.generate(
              math.min(candidates.length, 5),
              (j) => (candidates[j], walks[j] ?? 9999));
            zipped.sort((a, b) => a.$2.compareTo(b.$2));
            sortedCandidates = [
              ...zipped.map((e) => e.$1),
              ...candidates.skip(5),
            ];
          }
        }
        // 영업 중인 후보 우선 선택 (최대 3개 확인, 휴무면 다음 후보)
        PlaceResult best = sortedCandidates[0];
        String bestHours = '';
        for (final candidate in sortedCandidates.take(3)) {
          final idMatch = candidate.placeUrl.isNotEmpty
              ? RegExp(r'/(\d+)$').firstMatch(candidate.placeUrl)
              : null;
          if (idMatch == null) { best = candidate; break; }
          final (hours, isOpen) = await _fetchOpenStatus(idMatch.group(1)!, _courseSteps[i].time);
          if (isOpen) { best = candidate; bestHours = hours; break; }
          best = candidate; // 닫혀있어도 fallback으로 저장
        }
        if (bestHours.isNotEmpty) {
          best = PlaceResult(
            name: best.name, address: best.address,
            roadAddress: best.roadAddress, category: best.category,
            phone: best.phone, lat: best.lat, lng: best.lng,
            source: best.source, placeUrl: best.placeUrl, openHours: bestHours,
          );
        }
        setState(() {
          _courseSteps[i].place = best;
          _courseSteps[i].isSearching = false;
        });
        usedNames.add(best.name);
        _addCourseMarker(best, i + 1);
      }

      // ── mandatory 보장 ──
      if (mandatory != null && mandResult?.lat != null) {
        final existIdx = _courseSteps.indexWhere((s) => s.place != null && _nameScore(s.place!.name, mandLabel) <= 2);
        if (existIdx >= 0) {
          setState(() => _courseSteps[existIdx].place = mandResult);
        } else {
          final matchIdx = _courseSteps.indexWhere((s) =>
              mandLabel.isNotEmpty && (s.searchQuery.contains(mandLabel) ||
              (mandStripped.isNotEmpty && s.searchQuery.contains(mandStripped))));
          if (matchIdx >= 0) {
            setState(() => _courseSteps[matchIdx].place = mandResult);
          } else {
            final lunchIdx = _courseSteps.indexWhere((s) => s.type.contains('점심'));
            final at = ((lunchIdx > 0) ? lunchIdx : 1).clamp(0, _courseSteps.length);
            setState(() => _courseSteps.insert(at, CourseStep(
              time: '11:00', emoji: isMandShop ? '🛍️' : '📍',
              type: isMandShop ? '쇼핑' : mandLabel, duration: '1시간 30분',
              description: '$mandLabel 방문', searchQuery: mandLabel,
              categoryCode: '', engine: 'kakao', place: mandResult,
            )));
          }
        }
        usedNames.add(mandResult!.name);
      }
 
      // ── 장소 못 찾은 스텝 제거 ──
      setState(() {
        _courseSteps.removeWhere((s) => s.place == null);
      });

      // ── 동선 최적화 → 마커 재그리기 → 경로 → 시간 재계산 ──
      _optimizeRoute();
      _redrawAllMarkers();
      await _drawRoute();
      await _recalculateTimes();

      // ── 시간 공백 채우기 (직전 장소 근처로) ──
      await _fillTimeGaps(region, _selectedThemeKey, cLat, cLng);
      _optimizeRoute();  // fillTimeGaps 후 다시 최적화
      _redrawAllMarkers();
      await _drawRoute();
      await _recalculateTimes();
 
    } catch (e) {
      setState(() => _courseError = '코스 생성 오류: $e');
    } finally {
      if (_isCourseLoading) setState(() => _isCourseLoading = false);
    }
  }
 
  Future<List<PlaceResult>> _searchStepCandidates(
      CourseStep step, String region, double? cLat, double? cLng) async {
    if (step.searchQuery.isEmpty) return [];
    String withR(String q) => q.contains(region) ? q : '$region $q';
    bool inDistrict(PlaceResult p) => '${p.address} ${p.roadAddress}'.contains(region);

    List<PlaceResult> best = [];
    // 1차: 구 중심 1km
    if (cLat != null && cLng != null) {
      try {
        final r = _filter(await _searchKakao(withR(step.searchQuery), step.categoryCode,
            centerLat: cLat, centerLng: cLng, radius: 1000))
            .where(inDistrict).toList();
        if (r.isNotEmpty) best = r;
      } catch (_) {}
    }
    // 2차: 구 중심 2km
    if (best.isEmpty && cLat != null && cLng != null) {
      try {
        final r = _filter(await _searchKakao(withR(step.searchQuery), step.categoryCode,
            centerLat: cLat, centerLng: cLng, radius: 2000))
            .where(inDistrict).toList();
        if (r.isNotEmpty) best = r;
      } catch (_) {}
    }
    // 3차: 네이버 검색
    if (best.isEmpty) {
      try {
        final r = _filter(await _searchNaver(withR(step.searchQuery)))
            .where(inDistrict).toList();
        if (r.isNotEmpty) best = r;
      } catch (_) {}
    }
    // 4차: 카테고리명 단순화
    if (best.isEmpty && step.categoryCode.isNotEmpty) {
      final cn = categoryLabels[step.categoryCode] ?? '';
      if (cn.isNotEmpty) {
        try {
          final r = _filter(await _searchKakao('$region $cn', step.categoryCode,
              centerLat: cLat, centerLng: cLng, radius: 3000))
              .where(inDistrict).toList();
          if (r.isNotEmpty) best = r;
        } catch (_) {}
      }
    }
    // 5차: type으로 재검색
    if (best.isEmpty && step.type.isNotEmpty) {
      try {
        final r = _filter(await _searchKakao('$region ${step.type}', step.categoryCode,
            centerLat: cLat, centerLng: cLng, radius: 5000))
            .where(inDistrict).toList();
        if (r.isNotEmpty) best = r;
      } catch (_) {}
    }
    // 6차: 구 전체 카테고리
    if (best.isEmpty && step.categoryCode.isNotEmpty && cLat != null && cLng != null) {
      try {
        final r = _filter(await _searchKakao(region, step.categoryCode,
            centerLat: cLat, centerLng: cLng, radius: 5000))
            .toList();
        if (r.isNotEmpty) best = r;
      } catch (_) {}
    }
    return best;
  }

  void _redrawAllMarkers() {
    globalContext.callMethod('clearMarkers'.toJS);
    const double dupThreshold = 0.0006; // ~67m → 버블 라벨 겹침 감지 범위
    const double offsetStep   = 0.0005; // ~55m → 겹칠 때 라벨 간격

    // (1-based 번호, place) 목록
    final items = <(int, PlaceResult)>[];
    for (int i = 0; i < _courseSteps.length; i++) {
      final p = _courseSteps[i].place;
      if (p?.lat != null) items.add((i + 1, p!));
    }

    final placed = List.filled(items.length, false);
    for (int i = 0; i < items.length; i++) {
      if (placed[i]) continue;
      final group = [i];
      final (_, pi) = items[i];
      for (int j = i + 1; j < items.length; j++) {
        if (placed[j]) continue;
        final (_, pj) = items[j];
        if ((pi.lat! - pj.lat!).abs() < dupThreshold &&
            (pi.lng! - pj.lng!).abs() < dupThreshold) {
          group.add(j);
          placed[j] = true;
        }
      }
      placed[i] = true;

      final n = group.length;
      for (int gi = 0; gi < n; gi++) {
        final (num, place) = items[group[gi]];
        // gi=0 → 맨 위(north/높은 lat), gi=n-1 → 맨 아래(south)
        final latOff = n == 1 ? 0.0 : ((n - 1) / 2.0 - gi) * offsetStep;
        globalContext.callMethod(
          'addCourseMarker'.toJS,
          (place.lat! + latOff).toJS, place.lng!.toJS,
          num.toJS, place.name.toJS,
        );
      }
    }
  }
 
  void _addCourseMarker(PlaceResult place, int number) {
    if (place.lat == null || place.lng == null) return;
    globalContext.callMethod(
      'addCourseMarker'.toJS,
      place.lat!.toJS, place.lng!.toJS,
      number.toJS, place.name.toJS,
    );
  }
 
  // ─── 실제 도보 경로 좌표 조회 (OSRM) ────────────────────
  Future<List<Map<String, double>>?> _fetchWalkingRoutePath(
      PlaceResult from, PlaceResult to) async {
    try {
      final res = await http.get(Uri.parse(
        'https://router.project-osrm.org/route/v1/foot/'
        '${from.lng},${from.lat};${to.lng},${to.lat}'
        '?overview=full&geometries=geojson',
      ));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final coords = data['routes']?[0]?['geometry']?['coordinates'] as List?;
        if (coords != null && coords.isNotEmpty) {
          return coords.map<Map<String, double>>((c) => {
            'lat': (c[1] as num).toDouble(),
            'lng': (c[0] as num).toDouble(),
          }).toList();
        }
      }
    } catch (_) {}
    return null;
  }

  // ─── 실제 도로를 따라 경로 그리기 ───────────────────────
  Future<void> _drawRoute() async {
    final steps = _courseSteps.where((s) => s.place?.lat != null).toList();
    if (steps.length < 2) return;

    final segments = <List<Map<String, double>>>[];
    for (int i = 0; i < steps.length - 1; i++) {
      final from = steps[i].place!;
      final to   = steps[i + 1].place!;
      final path = await _fetchWalkingRoutePath(from, to);
      // OSRM 실패 시 직선으로 fallback
      segments.add(path ?? [
        {'lat': from.lat!, 'lng': from.lng!},
        {'lat': to.lat!,   'lng': to.lng!},
      ]);
    }

    globalContext.callMethod('drawRoute'.toJS, jsonEncode(segments).toJS);
  }
 
  void _showPlaceOnMap(PlaceResult place) {
    if (place.lat == null || place.lng == null) return;
    globalContext.callMethod('moveMapTo'.toJS, place.lat!.toJS, place.lng!.toJS, place.name.toJS);
  }
 
  // ─── 동선 최적화 ──────────────────────────────────────────
  double _haversineKm(double la1, double lo1, double la2, double lo2) {
    final dLa = (la2-la1)*math.pi/180, dLo = (lo2-lo1)*math.pi/180;
    final a = math.sin(dLa/2)*math.sin(dLa/2) +
        math.cos(la1*math.pi/180)*math.cos(la2*math.pi/180)*math.sin(dLo/2)*math.sin(dLo/2);
    return 6371 * 2 * math.atan2(math.sqrt(a), math.sqrt(1-a));
  }
 
  double _dist(PlaceResult a, PlaceResult b) => _haversineKm(a.lat!, a.lng!, b.lat!, b.lng!);
 
  // ─── 동선 방향 최적화 (band 순서 유지 + 각 band 내 지리 정렬) ────────────────
  void _optimizeRoute() {
    final withPlaces = _courseSteps.where((s) => s.place?.lat != null).toList();
    final noPlace    = _courseSteps.where((s) => s.place?.lat == null).toList();
    if (withPlaces.length < 2) return;

    // 가장 멀리 떨어진 두 점 → 주행 방향축 결정
    PlaceResult? axisFrom, axisTo;
    double maxD = 0;
    for (int i = 0; i < withPlaces.length; i++) {
      for (int j = i + 1; j < withPlaces.length; j++) {
        final d = _dist(withPlaces[i].place!, withPlaces[j].place!);
        if (d > maxD) {
          maxD = d;
          axisFrom = withPlaces[i].place;
          axisTo   = withPlaces[j].place;
        }
      }
    }
    if (axisFrom == null || axisTo == null) return;

    // 방향 벡터 투영
    final PlaceResult af = axisFrom;
    final dLat = axisTo.lat! - af.lat!;
    final dLng = axisTo.lng! - af.lng!;
    double proj(PlaceResult p) =>
        (p.lat! - af.lat!) * dLat + (p.lng! - af.lng!) * dLng;

    // band별로 분리 (band 필드 우선, 없으면 type으로 추론)
    String getBand(CourseStep s) {
      if (s.band.isNotEmpty) return s.band;
      if (s.type.contains('점심')) return 'lunch';
      if (s.type.contains('저녁')) return 'dinner';
      if (s.type.contains('야경') || s.type.contains('야간') || s.type.contains('바')) return 'night';
      return 'morning';
    }

    // band 순서 정의
    const bandOrder = {'morning':0,'lunch':1,'afternoon':2,'dinner':3,'night':4};

    // 각 band 그룹 내에서 지리적 방향 정렬
    List<CourseStep> sortByProj(List<CourseStep> g) =>
        g..sort((a, b) => proj(a.place!).compareTo(proj(b.place!)));

    // band별 그룹핑
    final groups = <String, List<CourseStep>>{};
    for (final s in withPlaces) {
      final b = getBand(s);
      (groups[b] ??= []).add(s);
    }

    // band 순서대로 조립 (각 그룹 내 지리 정렬)
    final result = <CourseStep>[];
    final orderedBands = [...bandOrder.keys]
      ..sort((a, b) => bandOrder[a]!.compareTo(bandOrder[b]!));
    for (final b in orderedBands) {
      final g = groups[b];
      if (g != null) result.addAll(sortByProj(g));
    }

    setState(() => _courseSteps = [...result, ...noPlace]);
  }
 
  // ─── 도보 이동 시간 추정 ─────────────────────────────────
  Future<int?> _getTravelMinutes(PlaceResult from, PlaceResult to) async {
    if (from.lat == null ||
        from.lng == null ||
        to.lat == null ||
        to.lng == null) {
      return null;
    }

    final distKm = _haversineKm(
      from.lat!,
      from.lng!,
      to.lat!,
      to.lng!,
    );

    // 도보 기준 추정
    // 실제 길은 직선보다 돌아가므로 1.25배 보정
    // 평균 보행 속도 약 4.5km/h 기준
    final walkingMinutes = (distKm * 1.25 / 4.5 * 60).ceil();

    return math.max(3, walkingMinutes);
  }

  Future<void> _recalculateTimes() async {
    if (_courseSteps.isEmpty) return;
    int parseDur(String s) {
      int m = 0;
      final h = RegExp(r'(\d+)시간').firstMatch(s);
      final n = RegExp(r'(\d+)분').firstMatch(s);
      if (h != null) m += int.parse(h.group(1)!) * 60;
      if (n != null) m += int.parse(n.group(1)!);
      return m > 0 ? m : 60;
    }
    int toM(String t) { final p = t.split(':'); return int.parse(p[0])*60+int.parse(p[1]); }
    String fmt(int m) => '${(m~/60).toString().padLeft(2,'0')}:${(m%60).toString().padLeft(2,'0')}';
    int cursor = toM(_courseSteps[0].time);
    for (int i = 1; i < _courseSteps.length; i++) {
      final prev = _courseSteps[i-1], curr = _courseSteps[i];
      int? tr = (prev.place != null && curr.place != null) ? await _getTravelMinutes(prev.place!, curr.place!) : null;
      tr ??= 15;
      cursor += parseDur(prev.duration) + tr;
      if (_courseSteps[i].type.contains('점심')) cursor = 12*60;          // 점심: 항상 12:00 고정
      if (_courseSteps[i].type.contains('저녁')) cursor = 18*60;          // 저녁: 항상 18:00 고정
      if (_courseSteps[i].type.contains('야간') || _courseSteps[i].type.contains('야경')) cursor = math.max(cursor, 20*60);
      setState(() { _courseSteps[i].travelMinutesFromPrev = tr; _courseSteps[i].time = fmt(cursor); });
    }
  }
 
  // ─── 시간 공백 채우기 (직전 장소 근처 우선) ──────────────
  Future<void> _fillTimeGaps(String region, String themeKey, double? cLat, double? cLng) async {
    final used = _courseSteps.where((s) => s.place != null).map((s) => s.place!.name).toSet();
    int parseDur(String s) { int m=0; final h=RegExp(r'(\d+)시간').firstMatch(s); final n=RegExp(r'(\d+)분').firstMatch(s); if(h!=null)m+=int.parse(h.group(1)!)*60; if(n!=null)m+=int.parse(n.group(1)!); return m>0?m:60; }
    int toM(String t){ final p=t.split(':'); return int.parse(p[0])*60+int.parse(p[1]); }
    String fmt(int m)=>'${(m~/60).toString().padLeft(2,'0')}:${(m%60).toString().padLeft(2,'0')}';
 
    final month = DateTime.now().month;
    final (ge, gt, gs, gc) = switch(themeKey) {
      'healing' => ('🌿','오후 힐링','$region 공원 산책','AT4'),
      'season'  => (month >= 6 && month <= 8)
          ? ('☀️','오후 수변','$region 한강공원','AT4')
          : (month >= 12 || month <= 2)
              ? ('❄️','오후 실내','$region 실내 전시 미술관','CT1')
              : ('🌸','오후 야외','$region 공원 산책로','AT4'),
      'culture' => ('🎨','오후 문화','$region 갤러리 미술관','CT1'),
      'food'    => ('☕','카페 디저트','$region 분위기 좋은 카페','CE7'),
      _         => ('📍','오후 활동','$region 관광명소','AT4'),
    };
 
    int i = 0;
    while (i < _courseSteps.length - 1) {
      final curr = _courseSteps[i], next = _courseSteps[i+1];
      final gap = toM(next.time) - (toM(curr.time) + parseDur(curr.duration));
      if (gap <= 90 || toM(curr.time) >= 18*60) { i++; continue; }
 
      // 직전 장소 좌표 기준으로 가까운 곳 검색 (왔다갔다 방지 핵심)
      final prevLat = curr.place?.lat ?? cLat;
      final prevLng = curr.place?.lng ?? cLng;
 
      List<PlaceResult> r = [];
      for (final (lat, lng, rad) in [
        (prevLat, prevLng, 1000), // 직전 장소 1km 이내 최우선
        (prevLat, prevLng, 2000), // 2km
        (cLat,    cLng,    3000), // 구 중심 3km 폴백
      ]) {
        if (lat == null || lng == null) continue;
        try {
          r = _filter(await _searchKakao(gs, gc, centerLat: lat, centerLng: lng, radius: rad))
              .where((p) => '${p.address} ${p.roadAddress}'.contains(region) && !used.contains(p.name)).toList();
          if (r.isNotEmpty) break;
        } catch (_) {}
      }
 
      // 네이버 폴백
      if (r.isEmpty) {
        try {
          r = _filter(await _searchNaver(gs))
              .where((p) => '${p.address} ${p.roadAddress}'.contains(region) && !used.contains(p.name)).toList();
        } catch (_) {}
      }
 
      if (r.isEmpty) { i++; continue; }
      used.add(r[0].name);
      setState(() => _courseSteps.insert(i+1, CourseStep(
        time: fmt(toM(curr.time)+parseDur(curr.duration)+15),
        emoji: ge, type: gt, duration: '1시간 30분', description: '오후 여가 시간',
        searchQuery: gs, categoryCode: gc, engine: 'naver', place: r[0],
      )));
      i += 2;
    }
  }
 
  int _nameScore(String name, String target) {
    final n = name.replaceAll(' ',''), t = target.replaceAll(' ','');
    if (name == target) return 0; if (n == t) return 1;
    if (n.startsWith(t) || t.startsWith(n)) return 2;
    if (n.contains(t)) return 3; if (t.contains(n)) return 4;
    return 5;
  }
 
  // ─── 장소 상세 바텀시트 ──────────────────────────────────
  void _showPlaceDetail(BuildContext context, PlaceResult place) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) {
        final addr = place.roadAddress.isNotEmpty ? place.roadAddress : place.address;
        final cat  = place.category.isNotEmpty ? place.category.split(' > ').last : '';
        return Container(
          margin: const EdgeInsets.fromLTRB(8,0,8,8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0,-2))]),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.fromLTRB(20,0,20,24), child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(place.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                if (cat.isNotEmpty) Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.deepPurple.shade50, borderRadius: BorderRadius.circular(20)),
                  child: Text(cat, style: TextStyle(fontSize: 12, color: Colors.deepPurple.shade700)),
                ),
                if (place.openHours.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.access_time, size: 15, color: Colors.green.shade600),
                    const SizedBox(width: 6),
                    Text('영업시간: ${place.openHours}',
                        style: TextStyle(fontSize: 12, color: Colors.green.shade700, fontWeight: FontWeight.w600)),
                  ]),
                ],
                const SizedBox(height: 16), const Divider(height: 1), const SizedBox(height: 14),
                if (addr.isNotEmpty) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.location_on, size: 17, color: Colors.grey.shade600),
                  const SizedBox(width: 8), Expanded(child: Text(addr, style: const TextStyle(fontSize: 13))),
                ]),
                if (addr.isNotEmpty) const SizedBox(height: 10),
                if (place.phone.isNotEmpty) Row(children: [
                  Icon(Icons.phone, size: 17, color: Colors.grey.shade600),
                  const SizedBox(width: 8), Text(place.phone, style: const TextStyle(fontSize: 13)),
                ]),
                if (place.phone.isNotEmpty) const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.grey.shade400), const SizedBox(width: 6),
                  Text('출처: ${place.source}', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                ]),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton.icon(
                  onPressed: () { Navigator.pop(ctx); _showPlaceOnMap(place); },
                  icon: const Icon(Icons.map, size: 16), label: const Text('지도에서 위치 보기'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13)),
                )),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () {
                      final url = place.placeUrl.isNotEmpty ? place.placeUrl
                          : 'https://map.kakao.com/link/search/${Uri.encodeComponent(place.name)}';
                      web.window.open(url, '_blank');
                    },
                    icon: const Icon(Icons.open_in_new, size: 15),
                    label: const Text('카카오맵', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFFFCD00),
                        side: const BorderSide(color: Color(0xFFFFCD00)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 11)),
                  )),
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton.icon(
                    onPressed: () => web.window.open(
                        'https://map.naver.com/v5/search/${Uri.encodeComponent(place.name)}', '_blank'),
                    icon: const Icon(Icons.search, size: 15),
                    label: const Text('네이버지도', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF03C75A),
                        side: const BorderSide(color: Color(0xFF03C75A)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 11)),
                  )),
                ]),
              ],
            )),
          ]),
        );
      },
    );
  }
 
  // ─── 챗봇 ────────────────────────────────────────────────
  Future<void> _addPlaceToCourse(String userText) async {
    String name = userText
        .replaceAll(RegExp(r'코스에?'), '')
        .replaceAll(RegExp(r'추가해\s*줘|추가시켜\s*줘|넣어\s*줘|포함시켜\s*줘|포함해\s*줘|추가해|넣어'), '')
        .replaceAll(RegExp(r'[을를도]\s*$'), '').replaceAll(RegExp(r'^\s*[을를도]\s*'), '').trim();
    if (name.isEmpty) {
      setState(() { chatMessages.add(ChatMessage(text: '어떤 장소를 추가할까요?', isUser: false)); isChatLoading = false; });
      _scrollToBottom(); return;
    }
    setState(() => chatMessages.add(ChatMessage(text: '"$name"을(를) 코스에 추가하고 있어요...', isUser: false)));
    _scrollToBottom();
    try {
      // 현재 코스의 마지막 장소 근처에서 검색 (동선 유지)
      final valid = _courseSteps.where((s) => s.place?.lat != null).toList();
      final lastPlace = valid.isNotEmpty ? valid.last.place : null;
      final cLat = lastPlace?.lat ?? (valid.isNotEmpty ? valid.map((s)=>s.place!.lat!).reduce((a,b)=>a+b)/valid.length : null);
      final cLng = lastPlace?.lng ?? (valid.isNotEmpty ? valid.map((s)=>s.place!.lng!).reduce((a,b)=>a+b)/valid.length : null);
 
      var r = _filter(await _searchKakao(name, '', centerLat: cLat, centerLng: cLng, radius: 3000, size: 10));
      if (r.isEmpty) r = _filter(await _searchKakao(name, '', centerLat: cLat, centerLng: cLng, radius: 10000, size: 10));
      if (r.isEmpty) { setState(() => chatMessages.add(ChatMessage(text: '"$name"을(를) 찾을 수 없어요.', isUser: false))); return; }
      r.sort((a,b) => _nameScore(a.name,name).compareTo(_nameScore(b.name,name)));
      final place = r[0];
      int insertIdx = (_courseSteps.length-1).clamp(1, _courseSteps.length);
      for (int i = 1; i < _courseSteps.length; i++) {
        if (RegExp(r'저녁|야경|야간').hasMatch(_courseSteps[i].type)) { insertIdx = i; break; }
      }
      const emojiMap = {'카페':'☕','음식점':'🍽️','관광명소':'🏛️','쇼핑':'🛍️','문화시설':'🎭','숙박':'🏨','공원':'🌿'};
      final cat = place.category.isNotEmpty ? place.category.split(' > ').last : '장소';
      final emoji = emojiMap.entries.firstWhere((e) => cat.contains(e.key), orElse: () => const MapEntry('','📍')).value;
      setState(() => _courseSteps.insert(insertIdx, CourseStep(
        time: '', emoji: emoji, type: cat, duration: '1시간', description: place.name,
        searchQuery: name, categoryCode: '', engine: 'kakao', place: place,
      )));
      _redrawAllMarkers(); await _drawRoute(); await _recalculateTimes();
      setState(() => chatMessages.add(ChatMessage(text: '"${place.name}"을(를) ${insertIdx+1}번째에 추가했어요!', isUser: false)));
      _tabController.animateTo(2);
    } catch (e) {
      setState(() => chatMessages.add(ChatMessage(text: '장소 추가 오류: $e', isUser: false)));
    } finally { setState(() => isChatLoading = false); _scrollToBottom(); }
  }
 
  Future<void> _modifyCourseByRequest(String userText) async {
    setState(() => chatMessages.add(ChatMessage(
          text: '코스를 수정하고 있어요...', isUser: false)));
    _scrollToBottom();

    try {
      // 현재 코스 요약 (AI에게 전달)
      final courseSummary = _courseSteps.asMap().entries.map((e) {
        final p = e.value.place;
        return '${e.key}: [${e.value.type}] ${e.value.description}'
            '${p != null ? " → ${p.name}" : ""}';
      }).join('\n');

      // 지역 추출 (코스 장소 주소에서)
      String region = '';
      for (final s in _courseSteps) {
        if (s.place != null) {
          final addr = '${s.place!.address} ${s.place!.roadAddress}';
          final m = RegExp(r'([가-힣]{2,4}구)').firstMatch(addr);
          if (m != null) { region = m.group(1)!; break; }
        }
      }

      final systemMsg =
          'You are a course editor. Given a current course and a user modification request, '
          'respond ONLY with valid JSON. No explanation, no markdown.';

      final userMsg = '''현재 코스:
$courseSummary

사용자 요청: "$userText"
지역: $region

위 코스에서 사용자 요청을 반영해 수정할 스텝을 찾으세요.
아래 JSON 형식으로만 응답:
{
  "action": "replace",
  "step_index": <0-based 정수>,
  "replacement": {
    "type": "<한글 타입명>",
    "emoji": "<이모지>",
    "duration": "<X시간 Y분>",
    "description": "<한줄 설명>",
    "search": "<카카오 검색어 — 반드시 지역명($region) 포함>",
    "category": "<FD6|CE7|AT4|CT1|MT1 중 적합한 것>"
  }
}
action이 "remove"이면 replacement 생략 가능.''';

      final reply = await _callGroq([
        {'role': 'system', 'content': systemMsg},
        {'role': 'user', 'content': userMsg},
      ]);

      final jsonStr = RegExp(r'\{[\s\S]+\}').firstMatch(reply)?.group(0);
      if (jsonStr == null) throw Exception('응답 파싱 실패');

      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final action = data['action'] as String? ?? 'replace';
      final stepIdx = (data['step_index'] as num).toInt();

      if (stepIdx < 0 || stepIdx >= _courseSteps.length) {
        throw Exception('수정할 스텝을 찾지 못했어요.');
      }

      if (action == 'remove') {
        final removedName =
            _courseSteps[stepIdx].place?.name ?? _courseSteps[stepIdx].type;
        setState(() => _courseSteps.removeAt(stepIdx));
        await _redrawCourseMarkers();
        await _recalculateTimes();
        setState(() => chatMessages.add(ChatMessage(
              text: '"$removedName"을(를) 코스에서 제거했어요.', isUser: false)));
      } else {
        final rep = data['replacement'] as Map<String, dynamic>;
        final searchQuery = rep['search'] as String;
        final categoryCode = rep['category'] as String? ?? '';

        // 현재 코스 중심 좌표
        final vp = _courseSteps.where((s) => s.place?.lat != null).toList();
        double? cLat, cLng;
        if (vp.isNotEmpty) {
          cLat = vp.map((s) => s.place!.lat!).reduce((a, b) => a + b) / vp.length;
          cLng = vp.map((s) => s.place!.lng!).reduce((a, b) => a + b) / vp.length;
        }

        var results = await _searchKakao(searchQuery, categoryCode,
            centerLat: cLat, centerLng: cLng, radius: 3000, size: 10);
        results = _filter(results);

        if (results.isEmpty && region.isNotEmpty) {
          results = await _searchKakao('$region ${rep['type']}', categoryCode,
              centerLat: cLat, centerLng: cLng, radius: 5000, size: 10);
          results = _filter(results);
        }

        // 이미 코스에 있는 장소 제외
        final usedNames =
            _courseSteps.map((s) => s.place?.name ?? '').toSet();
        results = results.where((p) => !usedNames.contains(p.name)).toList();

        final oldStep = _courseSteps[stepIdx];
        final newStep = CourseStep(
          time: oldStep.time,
          emoji: rep['emoji'] as String? ?? '📍',
          type: rep['type'] as String? ?? '장소',
          duration: rep['duration'] as String? ?? '1시간',
          description: rep['description'] as String? ?? searchQuery,
          searchQuery: searchQuery,
          categoryCode: categoryCode,
          engine: 'kakao',
          place: results.isNotEmpty ? results[0] : null,
        );

        setState(() => _courseSteps[stepIdx] = newStep);
        await _redrawCourseMarkers();
        await _recalculateTimes();

        final msg = results.isNotEmpty
            ? '"${results[0].name}"으로 교체했어요! 코스 탭을 확인하세요.'
            : '"${rep['type']}" 관련 장소를 찾지 못했어요. 다른 표현으로 요청해보세요.';
        setState(() => chatMessages.add(ChatMessage(text: msg, isUser: false)));
        if (results.isNotEmpty) _tabController.animateTo(2);
      }
    } catch (e) {
      setState(() => chatMessages.add(ChatMessage(
            text: '코스 수정 중 오류: $e', isUser: false)));
    } finally {
      setState(() => isChatLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _redrawCourseMarkers() async {
    globalContext.callMethod('clearMarkers'.toJS);
    for (int i = 0; i < _courseSteps.length; i++) {
      if (_courseSteps[i].place != null) {
        _addCourseMarker(_courseSteps[i].place!, i + 1);
      }
    }
    await _drawRoute();
  }

  Future<void> sendMessage() async {
    final text = chatInputController.text.trim();
    if (text.isEmpty || text.length == 1 || isChatLoading || _isCourseLoading) return;
    chatInputController.clear();
    setState(() => chatMessages.add(ChatMessage(text: text, isUser: true)));
    _scrollToBottom();

    // 장소 추가 요청
    if (RegExp(r'추가해\s*줘|추가시켜\s*줘|넣어\s*줘|포함시켜\s*줘|포함해\s*줘').hasMatch(text) && _courseSteps.isNotEmpty) {
      setState(() => isChatLoading = true);
      await _addPlaceToCourse(text);
      return;
    }

    final isCourse = RegExp(r'코스|데이트|여행|당일치기|나들이|짜줘|만들어').hasMatch(text);
    final isWant   = RegExp(r'가고\s*싶|가보고\s*싶|들르고\s*싶|방문하고\s*싶|가봐야').hasMatch(text);
    final hasReg   = RegExp(r'강남|강동|강북|강서|관악|광진|구로|금천|노원|도봉|동대문|동작|마포|서대문|서초|성동|성북|송파|양천|영등포|용산|은평|종로|중구|중랑|[가-힣]{1,4}(?:구|동|시|에서)').hasMatch(text);
    final isMand   = RegExp(r'중심으로|위주로|포함해서|포함하여|포함시켜').hasMatch(text);

    // 수정 vs 추천 공통 키워드 (아래 두 분기에서 모두 사용)
    final hasModifyKeyword = RegExp(
      r'말고|대신|바꿔|빼|제외|변경|교체|싫어|다른\s*(?:걸|것|곳|데|장소)|'
      r'없애|수정|고쳐|별로|원하지|하기\s*싫|바꾸고\s*싶|바꿨으면|'
      r'제거|삭제|뺐으면|교환|대체|다른\s*거|필요\s*없|하고\s*싶지'
    ).hasMatch(text);
    final isRecommendRequest = RegExp(
      r'추천해\s*봐|추천해\s*줘|추천\s*좀|추천\s*받|몇\s*개만|몇개만|'
      r'알려\s*줘|알려줘|뭐가\s*있어|어디가\s*좋[아아]|어디\s*있어|'
      r'뭐\s*있어|뭐\s*추천|어디\s*추천'
    ).hasMatch(text);

    // 장소 추천 요청 (수정 의도 없음) → 검색탭으로 전환
    if (isRecommendRequest && !hasModifyKeyword) {
      final query = text.replaceAll(RegExp(
        r'추천해\s*봐|추천해\s*줘|추천\s*좀|추천\s*받|몇\s*개만|몇개만|'
        r'알려\s*줘|알려줘|뭐가\s*있어|어디가\s*좋[아아]|어디\s*있어|'
        r'뭐\s*있어|뭐\s*추천|어디\s*추천'
      ), '').trim();
      if (query.isNotEmpty) {
        setState(() => chatMessages.add(ChatMessage(
          text: '"$query" 검색 결과를 검색 탭에서 확인해보세요! 🔍', isUser: false)));
        _scrollToBottom();
        searchController.text = query;
        _tabController.animateTo(0);
        await searchPlaces(query, engine: 'naver');
        return;
      }
    }

    // 명확한 새 코스 생성 (지역+코스 조합 or 명시적 재생성)
    final isNewCourse = (hasReg && isCourse) ||
        RegExp(r'코스\s*짜줘|코스\s*만들어|새로\s*짜|처음부터\s*짜|다시\s*짜').hasMatch(text);

    // 코스 수정 요청 — 코스가 존재하고 명확한 새 코스 요청이 아닐 때
    if (_courseSteps.isNotEmpty && !isNewCourse) {
      // 현재 코스 스텝 타입 언급 → 수정
      final stepTypes = _courseSteps.map((s) => s.type).where((t) => t.length > 1).toSet();
      final mentionsStep = stepTypes.any((t) => text.contains(t));
      // 지역 없이 "가고 싶다" → 특정 장소 추가/삽입 요청 (새 코스 생성 아님)
      final isWantSpecificPlace = isWant && !hasReg;

      if (hasModifyKeyword || (mentionsStep && !isRecommendRequest) || isWantSpecificPlace) {
        setState(() => isChatLoading = true);
        await _modifyCourseByRequest(text);
        return;
      }
    }

    if (hasReg || isCourse || isWant || isMand) {
      setState(() => chatMessages.add(ChatMessage(
        text: _selectedThemeKey.isNotEmpty ? '코스를 생성하고 있어요! 코스 탭을 확인해주세요 🗺️'
            : '인기 관광지 기반으로 코스를 생성할게요! 코스 탭을 확인해주세요 🗺️',
        isUser: false,
      )));
      _scrollToBottom();
      _tabController.animateTo(2);
      await _generateCourse(queryOverride: text);
      return;
    }
 
    setState(() => isChatLoading = true);
    try {
      final rm = RegExp(r'([가-힣]{2,4}(?:구|동))').firstMatch(text);
      final dr = rm?.group(1);
      String spotsCtx = '';
      if (dr != null) {
        final spots = _getSpotsForRegion(dr).where((s) => s['category'] != '숙박').take(10).toList();
        if (spots.isNotEmpty) spotsCtx = '\n\n[$dr 인기 관광지]\n${spots.map((s) => '- ${s['name']} (${s['category']})').join('\n')}';
      }
      final isFood = RegExp(r'맛집|식당|음식|밥|점심|저녁|카페|커피|뭐 먹').hasMatch(text);
      String restCtx = '';
      if (isFood && _restaurants.isNotEmpty) {
        final ft = !text.contains('현지인') && !text.contains('로컬');
        final meals = _getTopRestaurants(mealType: 'meal', forTourist: ft, limit: 8);
        final cafes = _getTopRestaurants(mealType: 'cafe', forTourist: ft, limit: 4);
        restCtx = '\n\n[인기 맛집]\n식사: ${meals.map((r) => '${r['name']}').join(', ')}\n카페: ${cafes.map((r) => r['name']).join(', ')}';
      }
      final reply = await _callGroq([
        {'role': 'system', 'content': _systemPrompt + spotsCtx + restCtx},
        ...chatMessages.map((m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text}),
      ]);
      final sm = RegExp(r'\[SEARCH:([^:\]]+):([^:\]]*):([^\]]+)\]').firstMatch(reply);
      if (sm != null) {
        final q = sm.group(1)!.trim(), cat = sm.group(2)!.trim(), eng = sm.group(3)!.trim();
        searchController.text = q; _tabController.animateTo(0);
        await searchPlaces(q, categoryCode: cat, engine: eng, fromChat: true);
      }
      final disp = reply.replaceAll(RegExp(r'\[SEARCH:[^\]]*\]'), '').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
      setState(() => chatMessages.add(ChatMessage(text: disp, isUser: false)));
    } catch (e) {
      setState(() => chatMessages.add(ChatMessage(text: '오류: $e', isUser: false)));
    } finally { setState(() => isChatLoading = false); _scrollToBottom(); }
  }
 
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (chatScrollController.hasClients) {
        chatScrollController.animateTo(chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }
 
  // ─── UI ─────────────────────────────────────────────────
  Widget _buildSearchTab() {
    return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(8)),
        child: const Row(children: [
          Icon(Icons.info_outline, size: 14, color: Colors.blue), SizedBox(width: 8),
          Expanded(child: Text('장소를 직접 검색해요.\n챗봇에서 추천받으면 자동으로 여기에 표시돼요.',
              style: TextStyle(fontSize: 11, color: Colors.blue, height: 1.5))),
        ]),
      ),
      Row(children: [
        Expanded(child: TextField(controller: searchController,
          decoration: const InputDecoration(hintText: '예: 강남 파스타, 성수동 카페',
              prefixIcon: Icon(Icons.search), border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
          onSubmitted: (v) => searchPlaces(v.trim(), categoryCode: currentCategoryCode, engine: 'naver'))),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () => searchPlaces(searchController.text.trim(), categoryCode: currentCategoryCode, engine: 'naver'),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
          child: const Text('검색')),
      ]),
      const SizedBox(height: 8),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        Padding(padding: const EdgeInsets.only(right: 6),
            child: FilterChip(label: const Text('전체'), selected: currentCategoryCode.isEmpty,
                onSelected: (_) => setState(() => currentCategoryCode = ''))),
        ...categoryLabels.entries.map((e) => Padding(padding: const EdgeInsets.only(right: 6),
            child: FilterChip(label: Text(e.value), selected: currentCategoryCode == e.key,
                onSelected: (_) => setState(() => currentCategoryCode = e.key)))),
      ])),
      const SizedBox(height: 12),
      if (isLoading) const Expanded(child: Center(child: CircularProgressIndicator()))
      else if (errorMessage.isNotEmpty)
        Expanded(child: Center(child: Text(errorMessage, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)))
      else if (places.isEmpty)
        const Expanded(child: Center(child: Text('검색어를 입력하거나\n챗봇에서 장소를 추천받아보세요!',
            textAlign: TextAlign.center, style: TextStyle(color: Colors.grey))))
      else ...[
        Row(children: [
          Text('검색 결과 ${places.length}개${currentCategoryCode.isNotEmpty ? " · ${categoryLabels[currentCategoryCode]} 필터" : ""}',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: places[0].source == 'naver' ? Colors.green.shade50 : Colors.yellow.shade50,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: places[0].source == 'naver' ? Colors.green.shade300 : Colors.orange.shade300)),
            child: Text(places[0].source == 'naver' ? '네이버 감성검색' : '카카오',
                style: TextStyle(fontSize: 10, color: places[0].source == 'naver' ? Colors.green.shade700 : Colors.orange.shade700))),
        ]),
        const SizedBox(height: 8),
        Expanded(child: ListView.builder(itemCount: places.length, itemBuilder: (ctx, i) {
          final p = places[i]; final sel = selectedPlaceIndex == i;
          return Card(elevation: sel ? 4 : 1, color: sel ? Colors.blue.shade50 : null,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8),
                side: sel ? BorderSide(color: Colors.blue.shade300, width: 1.5) : BorderSide.none),
            child: ListTile(
              leading: CircleAvatar(backgroundColor: sel ? Colors.blue : Colors.grey.shade200,
                  child: Text('${i+1}', style: TextStyle(color: sel ? Colors.white : Colors.black54, fontWeight: FontWeight.bold))),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 2),
                Text(p.roadAddress.isNotEmpty ? p.roadAddress : p.address, style: const TextStyle(fontSize: 12)),
                if (p.category.isNotEmpty) Text(p.category, style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                if (p.phone.isNotEmpty) Text(p.phone, style: TextStyle(fontSize: 11, color: Colors.blue.shade700)),
                if (p.openHours.isNotEmpty) Row(children: [
                  Icon(Icons.access_time, size: 12, color: Colors.green.shade600), const SizedBox(width: 3),
                  Text(p.openHours, style: TextStyle(fontSize: 11, color: Colors.green.shade700)),
                ]),
                if (p.lat == null) Text('지도 표시 불가', style: TextStyle(fontSize: 10, color: Colors.red.shade300)),
              ]),
              isThreeLine: true,
              onTap: p.lat != null ? () { setState(() => selectedPlaceIndex = i); _showPlaceOnMap(p); } : null,
            ));
        })),
      ],
    ]));
  }
 
  Widget _buildChatTab() {
    return Column(children: [
      Container(
        padding: const EdgeInsets.fromLTRB(12,10,12,8),
        decoration: BoxDecoration(color: Colors.grey.shade50, border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: Colors.deepPurple.shade50, borderRadius: BorderRadius.circular(8)),
            child: const Text(
              '💬 지역을 말하면 자동으로 코스를 짜드려요!\n'
              '🔍 장소 추천 요청 → 검색 탭에 결과 표시\n'
              '➕ "OO 추가해줘" → 현재 코스에 장소 추가',
              style: TextStyle(fontSize: 11, color: Color(0xFF5B21B6), height: 1.5)),
          ),
          const Text('코스 테마 (선택)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const Text('선택 안 하면 인기 관광지 기반으로 추천해요', style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 6),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            if (_selectedThemeKey.isNotEmpty)
              GestureDetector(onTap: () => setState(() => _selectedThemeKey = ''),
                child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.shade400)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.close, size: 12, color: Colors.grey), SizedBox(width: 2),
                    Text('해제', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ]))),
            ..._themes.map((theme) {
              final sel = _selectedThemeKey == theme['key'];
              return GestureDetector(
                onTap: () => setState(() => _selectedThemeKey = sel ? '' : theme['key']!),
                child: AnimatedContainer(duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? Colors.deepPurple : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? Colors.deepPurple : Colors.grey.shade300)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(theme['emoji']!, style: const TextStyle(fontSize: 14)), const SizedBox(width: 4),
                    Text(theme['label']!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold,
                        color: sel ? Colors.white : Colors.black87)),
                  ])));
            }),
          ])),
        ]),
      ),
      Expanded(
        child: chatMessages.where((m) => !m.isSystem).isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey), SizedBox(height: 12),
                Text('"용산에서 데이트 코스 짜줘"\n"성북구 힐링 코스 추천해줘"\n"홍대 분위기 좋은 카페 어디야?"',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.8)),
              ])))
            : ListView.builder(controller: chatScrollController, padding: const EdgeInsets.all(12),
                itemCount: chatMessages.length,
                itemBuilder: (ctx, i) {
                  final msg = chatMessages[i];
                  if (msg.isSystem) return const SizedBox.shrink();
                  return _buildMessageBubble(msg);
                }),
      ),
      if (isChatLoading) const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: LinearProgressIndicator()),
      Container(padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey.shade300))),
        child: Row(children: [
          Expanded(child: TextField(controller: chatInputController,
            decoration: const InputDecoration(hintText: '예: 용산에서 코스 짜줘, 아이파크몰 중심으로',
                border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
            onSubmitted: (_) { if (!isChatLoading && !_isCourseLoading) sendMessage(); },
            maxLines: null)),
          const SizedBox(width: 8),
          IconButton(onPressed: (isChatLoading || _isCourseLoading) ? null : sendMessage,
            icon: const Icon(Icons.send),
            style: IconButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white)),
        ]),
      ),
    ]);
  }
 
  Widget _buildCourseTab() {
    return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(color: Colors.deepPurple.shade50, borderRadius: BorderRadius.circular(8)),
        child: const Text(
          '🗺️ AI가 동선을 최적화해서 왔다갔다 없이 코스를 짜드려요.\n'
          '💡 챗봇 탭에서 "용산 코스 짜줘"라고 말해보세요!',
          style: TextStyle(fontSize: 11, color: Color(0xFF5B21B6), height: 1.5)),
      ),
      if (_isCourseLoading)
        const Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: Colors.deepPurple), SizedBox(height: 12),
          Text('AI가 코스를 생성하고 있어요...', style: TextStyle(color: Colors.grey)),
        ])))
      else if (_courseError.isNotEmpty)
        Expanded(child: Center(child: Text(_courseError, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center)))
      else if (_courseSteps.isEmpty)
        Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.map_outlined, size: 48, color: Colors.grey), const SizedBox(height: 12),
          const Text('챗봇 탭에서 코스를 요청하면 여기에 표시됩니다!',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.8)),
        ])))
      else
        Expanded(child: ListView.builder(itemCount: _courseSteps.length, itemBuilder: (ctx, idx) {
          final step = _courseSteps[idx]; final isLast = idx == _courseSteps.length-1;
          return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 48, child: Column(children: [
              Container(width: 36, height: 36,
                decoration: const BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle),
                child: Center(child: Text(step.emoji, style: const TextStyle(fontSize: 18)))),
              if (!isLast) Expanded(child: Stack(alignment: Alignment.center, children: [
                Container(width: 2, color: Colors.deepPurple.shade100),
                if (_courseSteps[idx+1].travelMinutesFromPrev != null)
                  Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white,
                        border: Border.all(color: Colors.deepPurple.shade100), borderRadius: BorderRadius.circular(8)),
                    child: Text('🚶 ${_courseSteps[idx+1].travelMinutesFromPrev}분',
                        style: TextStyle(fontSize: 10, color: Colors.deepPurple.shade400))),
              ])),
            ])),
            Expanded(child: Padding(padding: EdgeInsets.only(bottom: isLast ? 0 : 16, left: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 20, height: 20,
                    decoration: const BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle),
                    child: Center(child: Text('${idx+1}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)))),
                  const SizedBox(width: 6),
                  Text(step.time, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Text(step.type, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  Text('(${step.duration})', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ]),
                Text(step.description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                if (step.isSearching)
                  const Row(children: [
                    SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 6), Text('장소 검색 중...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ])
                else if (step.place != null)
                  GestureDetector(onTap: () => _showPlaceOnMap(step.place!),
                    child: Container(padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.deepPurple.shade50,
                          borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.deepPurple.shade100)),
                      child: Row(children: [
                        const Icon(Icons.place, size: 16, color: Colors.deepPurple), const SizedBox(width: 4),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(step.place!.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          Text(step.place!.roadAddress.isNotEmpty ? step.place!.roadAddress : step.place!.address,
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
                          if (step.place!.openHours.isNotEmpty)
                            Row(children: [
                              Icon(Icons.access_time, size: 11, color: Colors.green.shade600), const SizedBox(width: 3),
                              Text(step.place!.openHours, style: TextStyle(fontSize: 10, color: Colors.green.shade700)),
                            ]),
                        ])),
                        GestureDetector(onTap: () => _showPlaceDetail(ctx, step.place!),
                          behavior: HitTestBehavior.opaque,
                          child: const Padding(padding: EdgeInsets.all(4),
                              child: Icon(Icons.chevron_right, size: 16, color: Colors.deepPurple))),
                      ])))
                else Text('장소를 찾지 못했습니다', style: TextStyle(fontSize: 12, color: Colors.red.shade300)),
              ]),
            )),
          ]));
        })),
    ]));
  }
 
  Widget _buildMessageBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: const BoxConstraints(maxWidth: 300),
        decoration: BoxDecoration(
          color: msg.isUser ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12), topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(msg.isUser ? 12 : 0), bottomRight: Radius.circular(msg.isUser ? 0 : 12)),
        ),
        child: Text(msg.text, style: TextStyle(color: msg.isUser ? Colors.white : Colors.black87)),
      ),
    );
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('📍 데이트 코스 추천'), centerTitle: false),
      body: Row(children: [
        SizedBox(width: 400, child: Column(children: [
          TabBar(controller: _tabController, tabs: const [
            Tab(icon: Icon(Icons.search), text: '검색'),
            Tab(icon: Icon(Icons.chat_bubble_outline), text: '챗봇'),
            Tab(icon: Icon(Icons.route), text: '코스'),
          ]),
          Expanded(child: TabBarView(controller: _tabController, children: [
            _buildSearchTab(), _buildChatTab(), _buildCourseTab(),
          ])),
        ])),
        const VerticalDivider(width: 1),
        Expanded(child: HtmlElementView(viewType: 'kakao-map-view')),
      ]),
    );
  }
}