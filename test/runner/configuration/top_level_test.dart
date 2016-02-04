// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

@TestOn("vm")

import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:scheduled_test/descriptor.dart' as d;
import 'package:scheduled_test/scheduled_stream.dart';
import 'package:scheduled_test/scheduled_test.dart';

import '../../io.dart';

void main() {
  useSandbox();

  test("ignores an empty file", () {
    d.file("dart_test.yaml", "").create();

    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        test("success", () {});
      }
    """).create();

    var test = runTest(["test.dart"]);
    test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
    test.shouldExit(0);
  });

  test("includes the full stack with verbose_trace: true", () {
    d.file("dart_test.yaml", JSON.encode({
      "verbose_trace": true
    })).create();

    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        test("failure", () => throw "oh no");
      }
    """).create();

    var test = runTest(["test.dart"], reporter: "compact");
    test.stdout.expect(consumeThrough(contains("dart:isolate-patch")));
    test.shouldExit(1);
  });

  test("doesn't dartify stack traces for JS-compiled tests with js_trace: true",
      () {
    d.file("dart_test.yaml", JSON.encode({
      "js_trace": true
    })).create();

    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        test("failure", () => throw "oh no");
      }
    """).create();

    var test = runTest(["-p", "chrome", "--verbose-trace", "test.dart"]);
    test.stdout.fork().expect(never(endsWith(" main.<fn>")));
    test.stdout.fork().expect(never(contains("package:test")));
    test.stdout.fork().expect(never(contains("dart:async/zone.dart")));
    test.stdout.expect(consumeThrough(contains("-1: Some tests failed.")));
    test.shouldExit(1);
  });

  test("uses the specified reporter", () {
    d.file("dart_test.yaml", JSON.encode({
      "reporter": "json"
    })).create();

    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        test("success", () {});
      }
    """).create();

    var test = runTest(["test.dart"]);
    test.stdout.expect(consumeThrough(contains('"testStart"')));
    test.shouldExit(0);
  });

  test("uses the specified pub serve port", () {
    d.file("pubspec.yaml", """
name: myapp
dependencies:
  barback: any
  test: {path: ${p.current}}
transformers:
- myapp:
    \$include: test/**_test.dart
- test/pub_serve:
    \$include: test/**_test.dart
""").create();

    d.dir("lib", [
      d.file("myapp.dart", """
        import 'package:barback/barback.dart';

        class MyTransformer extends Transformer {
          final allowedExtensions = '.dart';

          MyTransformer.asPlugin();

          Future apply(Transform transform) async {
            var contents = await transform.primaryInput.readAsString();
            transform.addOutput(new Asset.fromString(
                transform.primaryInput.id,
                contents.replaceAll("isFalse", "isTrue")));
          }
        }
      """)
    ]).create();

    runPub(['get']).shouldExit(0);

    d.dir("test", [
      d.file("my_test.dart", """
        import 'package:test/test.dart';

        void main() {
          test("success", () => expect(true, isFalse));
        }
      """)
    ]).create();

    var pub = runPubServe();

    d.async(pubServePort.then((port) {
      return d.file("dart_test.yaml", JSON.encode({
        "pub_serve": port
      }));
    })).create();

    var test = runTest([]);
    test.stdout.expect(consumeThrough(contains('+1: All tests passed!')));
    test.shouldExit(0);
    pub.kill();
  });

  test("uses the specified concurrency", () {
    d.file("dart_test.yaml", JSON.encode({
      "concurrency": 2
    })).create();

    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        test("success", () {});
      }
    """).create();

    // We can't reliably test cthe concurrency, but this at least ensures that
    // it doesn't fail to parse.
    var test = runTest(["test.dart"]);
    test.stdout.expect(consumeThrough(contains("+1: All tests passed!")));
    test.shouldExit(0);
  });

  test("uses the specified timeout", () {
    d.file("dart_test.yaml", JSON.encode({
      "timeout": "0s"
    })).create();

    d.file("test.dart", """
      import 'dart:async';

      import 'package:test/test.dart';

      void main() {
        test("success", () => new Future.delayed(Duration.ZERO));
      }
    """).create();

    var test = runTest(["test.dart"]);
    test.stdout.expect(containsInOrder([
      "Test timed out after 0 seconds.",
      "-1: Some tests failed."
    ]));
    test.shouldExit(1);
  });

  test("runs on the specified platforms", () {
    d.file("dart_test.yaml", JSON.encode({
      "platforms": ["vm", "content-shell"]
    })).create();

    d.file("test.dart", """
      import 'package:test/test.dart';

      void main() {
        test("success", () {});
      }
    """).create();

    var test = runTest(["test.dart"]);
    test.stdout.expect(containsInOrder([
      "[VM] success",
      "[Dartium Content Shell] success"
    ]));
    test.shouldExit(0);
  });

  test("command line args take precedence", () {
    d.file("dart_test.yaml", JSON.encode({
      "timeout": "0s"
    })).create();

    d.file("test.dart", """
      import 'dart:async';

      import 'package:test/test.dart';

      void main() {
        test("success", () => new Future.delayed(Duration.ZERO));
      }
    """).create();

    var test = runTest(["--timeout=none", "test.dart"]);
    test.stdout.expect(consumeThrough(contains("All tests passed!")));
    test.shouldExit(0);
  });
}
