/// Data-widget payloads from GET /api/v1/widgets (weather/fx/markets/stocks).
class WeatherDay {
  final String label;
  final int hi;
  final int lo;
  final int code;
  const WeatherDay(
      {required this.label, required this.hi, required this.lo, required this.code});

  factory WeatherDay.fromJson(Map<String, dynamic> j) => WeatherDay(
        label: (j['label'] ?? '').toString(),
        hi: (j['hi'] as num?)?.round() ?? 0,
        lo: (j['lo'] as num?)?.round() ?? 0,
        code: (j['code'] as num?)?.toInt() ?? 0,
      );
}

class Weather {
  final String place;
  final String summary;
  final int tempC;
  final int code;
  final List<WeatherDay> days;
  const Weather({
    required this.place,
    required this.summary,
    required this.tempC,
    required this.code,
    required this.days,
  });

  factory Weather.fromJson(Map<String, dynamic> j) => Weather(
        place: (j['place'] ?? '').toString(),
        summary: (j['summary'] ?? '').toString(),
        tempC: (j['tempC'] as num?)?.round() ?? 0,
        code: (j['code'] as num?)?.toInt() ?? 0,
        days: ((j['days'] as List?) ?? const [])
            .map((e) => WeatherDay.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class MarketQuote {
  final String label;
  final double price;
  final double changePct;
  const MarketQuote(
      {required this.label, required this.price, required this.changePct});

  factory MarketQuote.fromJson(Map<String, dynamic> j) => MarketQuote(
        label: (j['label'] ?? j['symbol'] ?? '').toString(),
        price: (j['price'] as num?)?.toDouble() ?? 0,
        changePct: (j['changePct'] as num?)?.toDouble() ?? 0,
      );
}

class FxRate {
  final String code;
  final double rate;
  const FxRate({required this.code, required this.rate});

  factory FxRate.fromJson(Map<String, dynamic> j) => FxRate(
        code: (j['code'] ?? '').toString(),
        rate: (j['rate'] as num?)?.toDouble() ?? 0,
      );
}

class WidgetsData {
  final Weather? weather;
  final List<MarketQuote> markets;
  final List<MarketQuote> stocks;
  final List<FxRate> fx;
  const WidgetsData({
    this.weather,
    required this.markets,
    required this.stocks,
    required this.fx,
  });

  factory WidgetsData.fromJson(Map<String, dynamic> j) {
    List<MarketQuote> quotes(dynamic v) =>
        ((v as List?) ?? const [])
            .map((e) => MarketQuote.fromJson(e as Map<String, dynamic>))
            .toList();
    final fxObj = j['fx'] as Map<String, dynamic>?;
    return WidgetsData(
      weather: j['weather'] == null
          ? null
          : Weather.fromJson(j['weather'] as Map<String, dynamic>),
      markets: quotes(j['markets']),
      stocks: quotes(j['stocks']),
      fx: ((fxObj?['rates'] as List?) ?? const [])
          .map((e) => FxRate.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isEmpty =>
      weather == null && markets.isEmpty && stocks.isEmpty && fx.isEmpty;
}
