# BreakStream

Small docker based project for black-box testing of Streambased components.

## Overview

`breakstream` provides utilities and examples to perform black-box tests against 
Streambased components.

## Features

A Breakstream test consists of 3 components:

1. A spec - Specs are defined in a json file `spec.json` stored inside a test-named 
    directory (e.g. `specs/my-first-test/spec.json`). These define the data and test 
    cases that to be run. e.g.
    ```json
    {
        "components": [
            "kafka",
            "iceberg",
            "datagen-setup",
            "datagen-background",
            "streambased"
        ],
        "setup_datasets": [
            "core"
        ],
        "background_dataset" : "core",
        "tests" : [
            "core_functions"
        ]
    }
    ```
2. One or more datasets - Datasets are shadowtraffic specs and post load actions defined in 
   a named directory (e.g. `datasets/my-first-dataset`). Breakstream has 2 classes of dataset:
   * Setup - These are one shot Shadowtraffic jobs (named `setup.json`) used to prepopulate 
     data ahead of the test run. They are followed by after population steps (defined in 
     `post_setup.sh`).
   * Background - These are long-running Shadowtraffic jobs (named `background.json`) used to 
     provide background traffic during the test run. Only 1 background dataset is currently 
     supported per test run.
3. One or more test cases - Test cases are defined in a named directory (e.g. 
   `tests/my-first-test-case`) and contain simply a shell script to execute (`run.sh`). 
   Breakstream requires only that the return code of the script is 0 for success, non-zero 
   for failure and has no opinions about how the tests are run. 

## Requirements

- Java 11+ (or your project's configured JVM)
- jq
- Docker

## Quickstart

1. Clone the repository
2. Run with a test name, e.g.
   ```bash
   ./bin/start.sh <spec name>
   ```
3. Breakstream should clean itself up but if it doesn't you can run:
   ```bash
   ./bin/stop.sh
   ```
