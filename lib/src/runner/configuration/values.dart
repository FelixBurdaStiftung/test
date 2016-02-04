// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';
import 'dart:math' as math;

import '../../util/io.dart';

/// The default number of test suites to run at once.
///
/// This defaults to half the available processors, since presumably some of
/// them will be used for the OS and other processes.
final defaultConcurrency = math.max(1, Platform.numberOfProcessors ~/ 2);

/// The reporters supported by the test runner.
const allReporters = const ["compact", "expanded", "json"];

/// The default reporter.
final defaultReporter = inTestTests
    ? 'expanded'
    : (Platform.isWindows ? 'expanded' : 'compact');
