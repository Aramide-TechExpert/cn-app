import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/discover_controller.dart';
import '../../models/widgets_data.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';

/// Weather + markets strip (ports the web right-rail data widgets). Hidden
/// until loaded; each source is independently nullable.
class MarketsWeatherSection extends ConsumerWidget {
  const MarketsWeatherSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final data = ref.watch(widgetsDataProvider).valueOrNull;
    if (data == null || data.isEmpty) return const SizedBox.shrink();

    final quotes = [...data.markets, ...data.stocks];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (quotes.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.md),
            child: _Header('Markets'),
          ),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
              itemCount: quotes.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
              itemBuilder: (_, i) => _QuoteCard(quote: quotes[i]),
            ),
          ),
        ],
        if (data.weather != null) ...[
          const Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.md),
            child: _Header('Weather'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
            child: _WeatherCard(weather: data.weather!),
          ),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(label,
      style: AppText.headline.copyWith(color: context.colors.text));
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote});
  final MarketQuote quote;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final up = quote.changePct >= 0;
    final col = up ? c.success : c.critical;
    return Container(
      width: 132,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: c.bgInset,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(quote.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption
                  .copyWith(color: c.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(quote.price.toStringAsFixed(quote.price >= 100 ? 0 : 2),
              style: AppText.bodyStrong.copyWith(color: c.text)),
          const SizedBox(height: 2),
          Row(children: [
            Icon(up ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                size: 16, color: col),
            Text('${quote.changePct.abs().toStringAsFixed(2)}%',
                style: AppText.caption.copyWith(color: col)),
          ]),
        ],
      ),
    );
  }
}

class _WeatherCard extends StatelessWidget {
  const _WeatherCard({required this.weather});
  final Weather weather;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(AppSpace.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D6BFF), Color(0xFF1840B0)],
        ),
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(weather.place,
                        style: AppText.bodyStrong.copyWith(color: Colors.white)),
                    Text(weather.summary,
                        style: AppText.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.85))),
                  ],
                ),
              ),
              Text('${weather.tempC}°',
                  style: AppText.display.copyWith(color: Colors.white)),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: weather.days
                .take(5)
                .map((d) => Column(
                      children: [
                        Text(d.label,
                            style: AppText.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.85))),
                        const SizedBox(height: 4),
                        Text('${d.hi}°',
                            style: AppText.caption
                                .copyWith(color: Colors.white)),
                        Text('${d.lo}°',
                            style: AppText.caption.copyWith(
                                color: Colors.white.withValues(alpha: 0.6))),
                      ],
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}
