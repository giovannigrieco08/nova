import 'package:flutter_test/flutter_test.dart';
import 'package:nova/features/notifications/data/models/fcm_token_model.dart';
import 'package:nova/features/notifications/domain/entities/fcm_token.dart';

void main() {
  final now = DateTime(2025, 6, 1, 10, 0);
  final lastUsed = DateTime(2025, 6, 15, 14, 30);

  FcmTokenModel createModel({
    String id = 'token-001',
    String userId = 'user-001',
    String token = 'fcm-device-token-abc123',
    String platform = 'android',
    String? deviceName = 'Pixel 8',
    DateTime? createdAt,
    DateTime? lastUsedAt,
  }) {
    return FcmTokenModel(
      id: id,
      userId: userId,
      token: token,
      platform: platform,
      deviceName: deviceName,
      createdAt: createdAt ?? now,
      lastUsedAt: lastUsedAt ?? lastUsed,
    );
  }

  group('FcmTokenModel', () {
    // ===================== HAPPY PATH =====================

    test('creates with all fields', () {
      final model = createModel();

      expect(model.id, 'token-001');
      expect(model.userId, 'user-001');
      expect(model.token, 'fcm-device-token-abc123');
      expect(model.platform, 'android');
      expect(model.deviceName, 'Pixel 8');
    });

    test('fromJson and toJson roundtrip', () {
      final json = {
        'id': 'tok-1',
        'user_id': 'u1',
        'token': 'abc',
        'platform': 'ios',
        'device_name': 'iPhone di Mario',
        'created_at': '2025-06-01T10:00:00.000',
        'last_used_at': '2025-06-15T14:30:00.000',
      };

      final model = FcmTokenModel.fromJson(json);
      expect(model.id, 'tok-1');
      expect(model.platform, 'ios');
      expect(model.deviceName, 'iPhone di Mario');

      final output = model.toJson();
      expect(output['id'], 'tok-1');
      expect(output['user_id'], 'u1');
      expect(output['platform'], 'ios');
      expect(output['device_name'], 'iPhone di Mario');
    });

    test('toInsertJson excludes id and timestamps', () {
      final model = createModel();
      final json = model.toInsertJson();

      expect(json.containsKey('id'), false);
      expect(json.containsKey('created_at'), false);
      expect(json.containsKey('last_used_at'), false);
      expect(json['user_id'], 'user-001');
      expect(json['token'], 'fcm-device-token-abc123');
      expect(json['platform'], 'android');
      expect(json['device_name'], 'Pixel 8');
    });

    test('toEntity and fromEntity roundtrip', () {
      final model = createModel();
      final entity = model.toEntity();

      expect(entity, isA<FcmToken>());
      expect(entity.id, model.id);
      expect(entity.userId, model.userId);
      expect(entity.token, model.token);
      expect(entity.platform, model.platform);
      expect(entity.deviceName, model.deviceName);

      final backToModel = FcmTokenModel.fromEntity(entity);
      expect(backToModel.id, model.id);
      expect(backToModel.userId, model.userId);
      expect(backToModel.token, model.token);
    });

    // ===================== EDGE CASES =====================

    test('fromJson handles null deviceName', () {
      final json = {
        'id': 'tok-1',
        'user_id': 'u1',
        'token': 'abc',
        'platform': 'android',
        'device_name': null,
        'created_at': '2025-06-01T10:00:00.000',
        'last_used_at': '2025-06-15T14:30:00.000',
      };

      final model = FcmTokenModel.fromJson(json);
      expect(model.deviceName, isNull);
    });

    test('toInsertJson excludes null deviceName', () {
      final model = createModel(deviceName: null);
      final json = model.toInsertJson();

      expect(json.containsKey('device_name'), false);
    });
  });
}
