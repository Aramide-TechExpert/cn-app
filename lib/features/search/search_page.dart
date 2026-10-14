import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/search_controller.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../feed/widgets/article_card.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _controller = TextEditingController();
  Timer? _debounce;

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      ref.read(searchQueryProvider.notifier).state = value;
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final query = ref.watch(searchQueryProvider);
    final results = ref.watch(searchResultsProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onChanged: _onChanged,
          style: TextStyle(color: c.text, fontSize: 17),
          decoration: InputDecoration(
            hintText: 'Search Cluster News',
            hintStyle: TextStyle(color: c.textFaint),
            border: InputBorder.none,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.close, color: c.textSecondary),
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: query.trim().length < 2
          ? _Hint()
          : results.when(
              loading: () =>
                  Center(child: CircularProgressIndicator(color: c.brand)),
              error: (_, __) => Center(
                child: Text('Search failed.',
                    style: AppText.body.copyWith(color: c.textSecondary)),
              ),
              data: (items) => items.isEmpty
                  ? Center(
                      child: Text('No results for “${query.trim()}”.',
                          style:
                              AppText.body.copyWith(color: c.textSecondary)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.lg, AppSpace.lg, AppSpace.lg, AppSpace.x3),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpace.lg),
                      itemBuilder: (_, i) => ArticleCard(article: items[i]),
                    ),
            ),
    );
  }
}

class _Hint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search, size: 44, color: c.textFaint),
          const SizedBox(height: AppSpace.md),
          Text('Search news, topics, and sources',
              style: AppText.body.copyWith(color: c.textSecondary)),
        ],
      ),
    );
  }
}
