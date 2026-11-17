import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trust_app/src/auth.dart';
import 'package:trust_app/src/remote_api.dart';
import 'package:trust_app/src/remote_store.dart';
import 'package:trust_app/src/store.dart';

void main() {
  test('cloud refresh updates existing request objects and failed writes keep state', () async {
    final request = Request(
      id: 'request-1',
      title: 'Shared request',
      description: 'Shared request description',
      category: 0,
      city: 'Riyadh',
      budget: 10000,
      customerId: 'customer-1',
    );
    var reject = true;
    final operations = <String>[];
    final api = RemoteApi(
      client: MockClient((input) async {
        if (input.method == 'POST') {
          final body = jsonDecode(input.body) as Map<String, dynamic>;
          operations.add(body['operation']);
          if (reject) {
            return http.Response(jsonEncode({'error': 'forbidden'}), 403);
          }
          request.stage = Stage.cancelled;
        }
        return http.Response(
          jsonEncode({
            'requests': [request.toJson()],
            'profile': {},
            'providerSummaries': {},
          }),
          200,
        );
      }),
    );
    final store = RemoteStore(api);
    addTearDown(store.dispose);
    await store.activateAccount(
      accountId: 'customer-1',
      fullName: 'Customer',
      accountCity: 'Riyadh',
      isProvider: false,
    );
    final visible = store.requests.single;
    await expectLater(store.cancel(visible), throwsA(isA<AuthFailure>()));
    expect(visible.stage, Stage.open);
    expect(store.mutating, isFalse);
    reject = false;
    await store.cancel(visible);
    expect(identical(visible, store.requests.single), isTrue);
    expect(visible.stage, Stage.cancelled);
    expect(operations.length, 2);
    await store.clearAccount();
    expect(store.requests, isEmpty);
  });
}
