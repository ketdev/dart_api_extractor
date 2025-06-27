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
git clone https://github.com/your-username/dart_api_extractor.git
cd dart_api_extractor
dart run bin/dart_analyzer.dart <args>
```

> Requires Dart SDK installed and available in your `PATH`.

## Usage

```bash
dart dart_analyzer.dart <input_file.dart> [-o <output_file>] [--no-docs]
dart dart_analyzer.dart -d <directory> [--no-docs] [--processes <num>]
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
dart dart_analyzer.dart lib/example.dart

# Analyze and write to custom output
dart dart_analyzer.dart lib/example.dart -o summary.txt

# Analyze without documentation
dart dart_analyzer.dart lib/example.dart --no-docs

# Analyze a whole directory (parallelized)
dart dart_analyzer.dart -d lib/

# Analyze a directory with 4 parallel processes
dart dart_analyzer.dart -d lib/ --processes 4
```

## Output Format

The output is a readable text file showing public declarations in a tree structure with optional documentation and signatures:

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
