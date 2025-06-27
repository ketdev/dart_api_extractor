# Dart API Extractor

**Dart API Extractor** is a CLI tool that analyzes Dart source files or entire directories to extract public declarations (classes, functions, variables, etc.) into a structured, human-readable API summary. It optionally includes documentation comments.

## Features

- Parses Dart files using the Dart Analyzer
- Extracts:
  - Public declarations (ignores private `_` members)
  - Class, enum, mixin, extension, methods, functions, variables
  - Function/method signatures
  - Documentation comments (optional)
- Outputs to `.dart.api` files
- Supports analyzing individual files or entire directories
- **Fast!** Directory analysis runs in parallel using multiple processes (configurable)

## Installation

Clone this repo and run with Dart:

```bash
git clone https://github.com/ketdev/dart_api_extractor.git
cd dart_api_extractor
dart run src/dart_api_extractor.dart <args>
```

or build the executable:

```bash
dart compile exe src/dart_api_extractor.dart -o build/dart_api_extractor
```

> Requires Dart SDK installed and available in your `PATH`.

## Usage

```bash
dart_api_extractor <input_file.dart> [-o <output_file>] [--no-docs]
dart_api_extractor -d <directory> [--no-docs] [--processes <num>]
```

### Options

* `<input_file.dart>` – Path to a Dart file to analyze.
* `-o`, `--output <file>` – Optional output path (defaults to `<input>.dart.api`)
* `-d`, `--dir <directory>` – Analyze all `.dart` files recursively in a directory.
* `--no-docs` – Exclude documentation comments from output.
* `--processes <num>` – Number of concurrent processes for directory analysis (defaults to half of CPU cores, max 8).
* `-h`, `--help` – Show help message.

### Examples

```bash
# Analyze a single file
dart_api_extractor lib/example.dart

# Analyze and write to custom output
dart_api_extractor lib/example.dart -o summary.txt

# Analyze without documentation
dart_api_extractor lib/example.dart --no-docs

# Analyze a whole directory (parallelized)
dart_api_extractor -d lib/

# Analyze a directory with 4 parallel processes
dart_api_extractor -d lib/ --processes 4
```

## Output Format

The output is a readable text file similar to the original dart code, showing public declarations only with optional documentation and signatures:

```dart
/// This is a sample class
class MyClass {
  int myField;

  MyClass();

  void myMethod(String arg);
}
```

## License

MIT License
