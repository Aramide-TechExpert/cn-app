import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/auth_controller.dart';
import '../../models/article.dart';
import '../../theme/app_theme.dart';
import '../../theme/tokens.dart';
import '../../utils/format.dart';

class _Comment {
  _Comment({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.author,
    required this.isOwn,
  });
  final String id;
  final String body;
  final String createdAt;
  final String author;
  final bool isOwn;
}

/// Comments on a story (`comments` table). Public read; post/delete-own under
/// RLS. Author names need the 0012 profiles public-read policy to render for
/// other users (else they show "Member"). Opened from the long-press sheet.
class CommentsPage extends ConsumerStatefulWidget {
  const CommentsPage({super.key, required this.article});
  final Article article;

  @override
  ConsumerState<CommentsPage> createState() => _CommentsPageState();
}

class _CommentsPageState extends ConsumerState<CommentsPage> {
  final _input = TextEditingController();
  List<_Comment> _comments = [];
  bool _loading = true;
  bool _sending = false;

  String get _articleId => widget.article.dbId!;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final db = ref.read(supabaseProvider);
    final me = ref.read(currentUserProvider)?.id;
    try {
      final rows = await db
          .from('comments')
          .select('id, body, created_at, user_id')
          .eq('article_id', _articleId)
          .order('created_at', ascending: false)
          .limit(200);
      final list = (rows as List).cast<Map<String, dynamic>>();
      final ids = {for (final r in list) r['user_id'] as String}.toList();
      final names = <String, String>{};
      if (ids.isNotEmpty) {
        try {
          final profs = await db
              .from('profiles')
              .select('id, full_name')
              .inFilter('id', ids);
          for (final p in (profs as List)) {
            final n = (p['full_name'] as String?)?.trim();
            if (n != null && n.isNotEmpty) names[p['id'] as String] = n;
          }
        } catch (_) {/* profiles not readable → fall back to 'Member' */}
      }
      if (!mounted) return;
      setState(() {
        _comments = [
          for (final r in list)
            _Comment(
              id: r['id'] as String,
              body: (r['body'] ?? '') as String,
              createdAt: (r['created_at'] ?? '') as String,
              author: names[r['user_id']] ?? 'Member',
              isOwn: me != null && r['user_id'] == me,
            )
        ];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final user = ref.read(currentUserProvider);
    final text = _input.text.trim();
    if (user == null || text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(supabaseProvider).from('comments').insert({
        'user_id': user.id,
        'article_id': _articleId,
        'body': text,
      });
      _input.clear();
      HapticFeedback.lightImpact();
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("Couldn't post")));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(String id) async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;
    setState(() => _comments.removeWhere((c) => c.id == id));
    try {
      await ref
          .read(supabaseProvider)
          .from('comments')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);
    } catch (_) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Comments', style: AppText.title.copyWith(color: c.text)),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator.adaptive())
                : _comments.isEmpty
                    ? Center(
                        child: Text('No comments yet — be the first.',
                            style:
                                AppText.body.copyWith(color: c.textSecondary)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.lg, vertical: AppSpace.md),
                        itemCount: _comments.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpace.lg),
                        itemBuilder: (_, i) {
                          final cm = _comments[i];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(cm.author,
                                    style: AppText.caption.copyWith(
                                        color: c.text,
                                        fontWeight: FontWeight.w700)),
                                const SizedBox(width: 6),
                                Text(timeAgo(cm.createdAt),
                                    style: AppText.caption
                                        .copyWith(color: c.textFaint)),
                                const Spacer(),
                                if (cm.isOwn)
                                  InkResponse(
                                    onTap: () => _delete(cm.id),
                                    child: Icon(Icons.delete_outline,
                                        size: 16, color: c.textFaint),
                                  ),
                              ]),
                              const SizedBox(height: 4),
                              Text(cm.body,
                                  style: AppText.body.copyWith(color: c.text)),
                            ],
                          );
                        },
                      ),
          ),
          Divider(height: 1, color: c.border),
          SafeArea(
            top: false,
            child: user == null
                ? Padding(
                    padding: const EdgeInsets.all(AppSpace.lg),
                    child: OutlinedButton(
                      onPressed: () => context.push('/sign-in'),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: c.border),
                        minimumSize: const Size.fromHeight(46),
                        shape: const RoundedRectangleBorder(),
                      ),
                      child: Text('Sign in to comment',
                          style: AppText.callout.copyWith(color: c.brand)),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.lg, AppSpace.sm, AppSpace.sm, AppSpace.sm),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          style: AppText.body.copyWith(color: c.text),
                          decoration: InputDecoration(
                            hintText: 'Add a comment…',
                            filled: true,
                            fillColor: c.bgInset,
                            border: const OutlineInputBorder(
                                borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.md, vertical: AppSpace.sm),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _sending ? null : _send,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(Icons.send, color: c.brand),
                      ),
                    ]),
                  ),
          ),
        ],
      ),
    );
  }
}
