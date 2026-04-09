/// Chat test fixtures
///
/// Reusable test data for chat-related tests.

import 'package:nova/features/chat/domain/entities/chat_message.dart';
import 'package:nova/features/chat/domain/entities/chat_reaction.dart';
import 'package:nova/features/chat/domain/entities/chat_media_info.dart';
import 'package:nova/features/chat/domain/entities/mention_info.dart';
import 'profile_fixtures.dart';
import 'test_fixtures.dart';

/// Test chat fixtures
class TestChatMessages {
  static ChatMessage textMessage({
    String? id,
    String? userId,
    String? content,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? 'msg-001',
      userId: userId ?? TestUserIds.student1,
      content: content ?? 'Ciao a tutti!',
      mentions: const [],
      reactionCount: 0,
      replyCount: 0,
      reportCount: 0,
      createdAt: createdAt ?? DateTime.now(),
      author: TestProfiles.completeProfile(),
      reactionCounts: const {},
      currentUserReactions: const {},
    );
  }

  static ChatMessage replyMessage({
    String? replyToId,
  }) {
    return ChatMessage(
      id: 'msg-reply-001',
      userId: TestUserIds.student2,
      replyToId: replyToId ?? 'msg-001',
      content: 'Risposta al messaggio',
      mentions: const [],
      reactionCount: 0,
      replyCount: 0,
      reportCount: 0,
      createdAt: DateTime.now(),
      author: TestProfiles.completeProfile(
        userId: TestUserIds.student2,
        fullName: 'Lucia Bianchi',
      ),
      reactionCounts: const {},
      currentUserReactions: const {},
    );
  }

  static ChatMessage deletedMessage() {
    return ChatMessage(
      id: 'msg-deleted-001',
      userId: TestUserIds.student1,
      content: 'Messaggio originale',
      mentions: const [],
      reactionCount: 0,
      replyCount: 0,
      reportCount: 0,
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      deletedAt: DateTime.now(),
      deletedByUser: true,
      author: TestProfiles.completeProfile(),
      reactionCounts: const {},
      currentUserReactions: const {},
    );
  }

  static ChatMessage hiddenMessage() {
    return ChatMessage(
      id: 'msg-hidden-001',
      userId: TestUserIds.student1,
      content: 'Contenuto inappropriato',
      mentions: const [],
      reactionCount: 0,
      replyCount: 0,
      reportCount: 3,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      hiddenAt: DateTime.now(),
      hiddenReason: 'Violazione regolamento',
      author: TestProfiles.completeProfile(),
      reactionCounts: const {},
      currentUserReactions: const {},
    );
  }

  static ChatMessage gifMessage() {
    return ChatMessage(
      id: 'msg-gif-001',
      userId: TestUserIds.student1,
      content: '',
      mentions: const [],
      reactionCount: 0,
      replyCount: 0,
      reportCount: 0,
      createdAt: DateTime.now(),
      gifUrl: 'https://media.giphy.com/test.gif',
      gifId: 'abc123',
      author: TestProfiles.completeProfile(),
      reactionCounts: const {},
      currentUserReactions: const {},
    );
  }

  static List<ChatMessage> sampleConversation({int count = 10}) {
    return List.generate(count, (i) => textMessage(
      id: 'msg-$i',
      content: 'Messaggio $i',
      createdAt: DateTime.now().subtract(Duration(minutes: count - i)),
    ));
  }

  TestChatMessages._();
}

/// Test mention fixtures
class TestMentions {
  static MentionInfo basic() {
    return MentionInfo(
      userId: TestUserIds.student2,
      username: 'lucia.bianchi',
      startIndex: 0,
      endIndex: 14,
    );
  }

  TestMentions._();
}
