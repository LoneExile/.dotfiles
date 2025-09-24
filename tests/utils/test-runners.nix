# Test runner utilities
{
  lib,
  pkgs,
  testFramework,
  ...
}: let
  # Create a test runner for a specific test suite
  mkTestRunner = {
    name,
    tests,
    description ? "Test suite: ${name}",
  }:
    pkgs.writeShellScriptBin "run-${name}-tests" ''
      echo "Running ${description}..."
      echo "========================================"

      # Initialize counters
      total_tests=0
      passed_tests=0
      failed_tests=0

      # Track failed test names
      failed_test_names=()

      ${builtins.concatStringsSep "\n" (map (test: ''
          echo ""
          echo "Running test: ${test.name}"
          echo "----------------------------------------"
          total_tests=$((total_tests + 1))

          # Run the test and capture exit code
          if ${test.command}; then
            echo "✓ PASSED: ${test.name}"
            passed_tests=$((passed_tests + 1))
          else
            echo "✗ FAILED: ${test.name}"
            failed_tests=$((failed_tests + 1))
            failed_test_names+=("${test.name}")
          fi
        '')
        tests)}

      echo ""
      echo "========================================"
      echo "${description} Summary:"
      echo "  Total tests: $total_tests"
      echo "  Passed: $passed_tests"
      echo "  Failed: $failed_tests"

      if [ $failed_tests -gt 0 ]; then
        echo ""
        echo "Failed tests:"
        for test_name in "''${failed_test_names[@]}"; do
          echo "  - $test_name"
        done
        echo ""
        echo "❌ Test suite FAILED"
        exit 1
      else
        echo ""
        echo "✅ All tests PASSED"
        exit 0
      fi
    '';

  # Create a parallel test runner
  mkParallelTestRunner = {
    name,
    tests,
    maxJobs ? 4,
    description ? "Parallel test suite: ${name}",
  }:
    pkgs.writeShellScriptBin "run-${name}-tests-parallel" ''
      echo "Running ${description} (parallel, max ${toString maxJobs} jobs)..."
      echo "========================================"

      # Create temporary directory for test results
      temp_dir=$(mktemp -d)
      trap "rm -rf $temp_dir" EXIT

      # Function to run a single test
      run_single_test() {
        local test_name="$1"
        local test_command="$2"
        local result_file="$temp_dir/$test_name.result"

        echo "Starting test: $test_name" >&2

        if eval "$test_command" > "$temp_dir/$test_name.log" 2>&1; then
          echo "PASSED" > "$result_file"
          echo "✓ PASSED: $test_name" >&2
        else
          echo "FAILED" > "$result_file"
          echo "✗ FAILED: $test_name" >&2
        fi
      }

      # Export the function so it can be used by parallel
      export -f run_single_test
      export temp_dir

      # Run tests in parallel
      ${builtins.concatStringsSep "\n" (map (test: ''
          echo "${test.name}|${test.command}"
        '')
        tests)} | \
      ${pkgs.parallel}/bin/parallel -j ${toString maxJobs} --colsep '|' run_single_test {1} {2}

      # Collect results
      total_tests=0
      passed_tests=0
      failed_tests=0
      failed_test_names=()

      for result_file in "$temp_dir"/*.result; do
        if [ -f "$result_file" ]; then
          test_name=$(basename "$result_file" .result)
          result=$(cat "$result_file")
          total_tests=$((total_tests + 1))

          if [ "$result" = "PASSED" ]; then
            passed_tests=$((passed_tests + 1))
          else
            failed_tests=$((failed_tests + 1))
            failed_test_names+=("$test_name")
          fi
        fi
      done

      echo ""
      echo "========================================"
      echo "${description} Summary:"
      echo "  Total tests: $total_tests"
      echo "  Passed: $passed_tests"
      echo "  Failed: $failed_tests"

      if [ $failed_tests -gt 0 ]; then
        echo ""
        echo "Failed tests:"
        for test_name in "''${failed_test_names[@]}"; do
          echo "  - $test_name"
          echo "    Log: $temp_dir/$test_name.log"
        done
        echo ""
        echo "❌ Test suite FAILED"
        exit 1
      else
        echo ""
        echo "✅ All tests PASSED"
        exit 0
      fi
    '';

  # Create a test runner with filtering capabilities
  mkFilteredTestRunner = {
    name,
    tests,
    filter ? null,
    description ? "Filtered test suite: ${name}",
  }: let
    filteredTests =
      if filter != null
      then lib.filter filter tests
      else tests;
  in
    mkTestRunner {
      inherit name description;
      tests = filteredTests;
    };

  # Create a test runner with timeout support
  mkTimedTestRunner = {
    name,
    tests,
    timeout ? 300,
    description ? "Timed test suite: ${name}",
  }:
    pkgs.writeShellScriptBin "run-${name}-tests-timed" ''
      echo "Running ${description} (timeout: ${toString timeout}s per test)..."
      echo "========================================"

      # Initialize counters
      total_tests=0
      passed_tests=0
      failed_tests=0
      timed_out_tests=0

      # Track failed and timed out test names
      failed_test_names=()
      timed_out_test_names=()

      ${builtins.concatStringsSep "\n" (map (test: ''
          echo ""
          echo "Running test: ${test.name}"
          echo "----------------------------------------"
          total_tests=$((total_tests + 1))

          # Run the test with timeout
          if timeout ${toString timeout} ${test.command}; then
            echo "✓ PASSED: ${test.name}"
            passed_tests=$((passed_tests + 1))
          else
            exit_code=$?
            if [ $exit_code -eq 124 ]; then
              echo "⏰ TIMEOUT: ${test.name}"
              timed_out_tests=$((timed_out_tests + 1))
              timed_out_test_names+=("${test.name}")
            else
              echo "✗ FAILED: ${test.name}"
              failed_tests=$((failed_tests + 1))
              failed_test_names+=("${test.name}")
            fi
          fi
        '')
        tests)}

      echo ""
      echo "========================================"
      echo "${description} Summary:"
      echo "  Total tests: $total_tests"
      echo "  Passed: $passed_tests"
      echo "  Failed: $failed_tests"
      echo "  Timed out: $timed_out_tests"

      if [ $failed_tests -gt 0 ] || [ $timed_out_tests -gt 0 ]; then
        if [ $failed_tests -gt 0 ]; then
          echo ""
          echo "Failed tests:"
          for test_name in "''${failed_test_names[@]}"; do
            echo "  - $test_name"
          done
        fi

        if [ $timed_out_tests -gt 0 ]; then
          echo ""
          echo "Timed out tests:"
          for test_name in "''${timed_out_test_names[@]}"; do
            echo "  - $test_name (timeout: ${toString timeout}s)"
          done
        fi

        echo ""
        echo "❌ Test suite FAILED"
        exit 1
      else
        echo ""
        echo "✅ All tests PASSED"
        exit 0
      fi
    '';

  # Create a comprehensive test runner that combines all test suites
  runAllTests = pkgs.writeShellScriptBin "run-all-tests" ''
    echo "Running comprehensive test suite for modular Nix configuration..."
    echo "=================================================================="

    # Track overall results
    total_suites=0
    passed_suites=0
    failed_suites=0
    failed_suite_names=()

    # Function to run a test suite
    run_test_suite() {
      local suite_name="$1"
      local suite_command="$2"

      echo ""
      echo "Running $suite_name test suite..."
      echo "--------------------------------------------------"
      total_suites=$((total_suites + 1))

      if $suite_command; then
        echo "✅ $suite_name: PASSED"
        passed_suites=$((passed_suites + 1))
      else
        echo "❌ $suite_name: FAILED"
        failed_suites=$((failed_suites + 1))
        failed_suite_names+=("$suite_name")
      fi
    }

    # Run all test suites
    run_test_suite "Module Unit Tests" "${import ../modules/default.nix {inherit inputs outputs system lib pkgs;}}/bin/run-module-tests"
    run_test_suite "Library Tests" "${import ../lib/default.nix {inherit inputs outputs system lib pkgs;}}/bin/run-lib-tests"
    run_test_suite "Integration Tests" "${import ../integration/default.nix {inherit inputs outputs system lib pkgs;}}/bin/run-integration-tests"
    run_test_suite "System Tests" "${import ../system/default.nix {inherit inputs outputs system lib pkgs;}}/bin/run-system-tests"

    echo ""
    echo "=================================================================="
    echo "Overall Test Summary:"
    echo "  Total test suites: $total_suites"
    echo "  Passed: $passed_suites"
    echo "  Failed: $failed_suites"

    if [ $failed_suites -gt 0 ]; then
      echo ""
      echo "Failed test suites:"
      for suite_name in "''${failed_suite_names[@]}"; do
        echo "  - $suite_name"
      done
      echo ""
      echo "❌ OVERALL TEST SUITE FAILED"
      exit 1
    else
      echo ""
      echo "🎉 ALL TEST SUITES PASSED!"
      exit 0
    fi
  '';
in {
  inherit mkTestRunner mkParallelTestRunner mkFilteredTestRunner mkTimedTestRunner runAllTests;
}
