import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'dart:io';
import 'package:path/path.dart' as path;

class DeclarationNode {
  final String kind;
  final List<String> names;
  final List<String> headers;
  final List<String> documentation;
  final List<DeclarationNode> children;
  final String? parentClassName;

  DeclarationNode({
    required this.kind,
    required this.names,
    required this.headers,
    this.documentation = const [],
    this.children = const [],
    this.parentClassName,
  });

  @override
  String toString() => _toString('', parentClassName: parentClassName);

  String _toString(String indent, {String? parentClassName}) {
    final buffer = StringBuffer();
    final isContainer = _isContainerType(kind);
    
    for (int i = 0; i < names.length; i++) {
      final name = names[i];
      final header = i < headers.length ? headers[i] : '';
      final docs = i < documentation.length ? documentation[i] : '';
      
      if (docs.isNotEmpty) {
        final docLines = docs.split('\n');
        for (final line in docLines) {
          if (line.trim().isNotEmpty) {
            buffer.write('$indent$line\n');
          }
        }
      }
      
      if (isContainer) {
        buffer.write('$indent$header\n');
        for (final child in children) {
          buffer.write(child._toString('$indent  ', parentClassName: name));
        }
        buffer.write('$indent}\n');
      } else {
        buffer.write('$indent$header\n');
      }
    }
    
    if (!isContainer) {
      for (final child in children) {
        buffer.write(child._toString(indent, parentClassName: parentClassName));
      }
    }
    
    return buffer.toString();
  }

  static bool _isContainerType(String kind) {
    return kind == 'class' || kind == 'enum' || kind == 'mixin' || kind == 'extension';
  }
}

void main(List<String> args) async {
  String? inputFile;
  String? inputDirectory;
  String? outputFile;
  bool includeDocumentation = true;
  int? maxProcesses;

  // Parse command line arguments
  for (int i = 0; i < args.length; i++) {
    if (args[i] == '--help' || args[i] == '-h') {
      _printUsage();
      exit(0);
    } else if ((args[i] == '-o' || args[i] == '--output') && i + 1 < args.length) {
      outputFile = args[i + 1];
      i++; // Skip the next argument since we consumed it
    } else if (args[i] == '-d' || args[i] == '--dir') {
      if (i + 1 < args.length) {
        inputDirectory = args[i + 1];
        i++; // Skip the next argument since we consumed it
      } else {
        print('Error: Directory path required after ${args[i]}');
        _printUsage();
        exit(1);
      }
    } else if (args[i] == '--no-docs') {
      includeDocumentation = false;
    } else if (args[i] == '--processes') {
      if (i + 1 < args.length) {
        final processCount = int.tryParse(args[i + 1]);
        if (processCount != null && processCount > 0) {
          maxProcesses = processCount;
          i++; // Skip the next argument since we consumed it
        } else {
          print('Error: Invalid number of processes: ${args[i + 1]}');
          _printUsage();
          exit(1);
        }
      } else {
        print('Error: Number of processes required after --processes');
        _printUsage();
        exit(1);
      }
    } else if (args[i].startsWith('-')) {
      print('Unknown option: ${args[i]}');
      _printUsage();
      exit(1);
    } else if (inputFile == null && inputDirectory == null) {
      inputFile = args[i];
    } else {
      print('Multiple input sources specified. Only one input file or directory is allowed.');
      _printUsage();
      exit(1);
    }
  }

  if (inputFile == null && inputDirectory == null) {
    print('No input file or directory specified.');
    _printUsage();
    exit(1);
  }

  if (inputFile != null && inputDirectory != null) {
    print('Cannot specify both file and directory input.');
    _printUsage();
    exit(1);
  }

  if (inputDirectory != null && outputFile != null) {
    print('Cannot specify output file when processing directory. Output files are created next to source files.');
    _printUsage();
    exit(1);
  }

  if (inputDirectory != null) {
    await _processDirectory(inputDirectory, includeDocumentation, maxProcesses);
  } else {
    await _processFile(inputFile!, outputFile, includeDocumentation);
  }
}

String _findDartSdkPath() {
  // Try to find Dart SDK from environment
  final dartPath = Platform.environment['DART_SDK'];
  if (dartPath != null && Directory(dartPath).existsSync()) {
    return dartPath;
  }
  
  // Try to find from 'dart' command
  try {
    final result = Process.runSync('dart', ['--version']);
    if (result.exitCode == 0) {
      // Parse the version output to find SDK path
      final lines = result.stdout.toString().split('\n');
      for (final line in lines) {
        if (line.contains('Dart SDK version:')) {
          // Extract path from version info
          final match = RegExp(r'Dart SDK version: \d+\.\d+\.\d+ \((\w+)\)').firstMatch(line);
          if (match != null) {
            // final channel = match.group(1);
            
            // Common SDK paths
            final possiblePaths = [
              '/usr/local/lib/dart',
              '/opt/homebrew/lib/dart',
              '/usr/lib/dart',
              path.join(Platform.environment['HOME'] ?? '', '.pub-cache', 'hosted', 'pub.dev', 'dart'),
            ];
            
            for (final sdkPath in possiblePaths) {
              if (Directory(sdkPath).existsSync()) {
                return sdkPath;
              }
            }
          }
        }
      }
    }
  } catch (e) {
    // Ignore errors
  }
  
  // Last resort: try common Flutter SDK paths
  final flutterPaths = [
    path.join(Platform.environment['HOME'] ?? '', 'flutter'),
    '/usr/local/flutter',
    '/opt/homebrew/lib/flutter',
  ];
  
  for (final flutterPath in flutterPaths) {
    final sdkPath = path.join(flutterPath, 'bin', 'cache', 'dart-sdk');
    if (Directory(sdkPath).existsSync()) {
      return sdkPath;
    }
  }
  
  // Try to find from 'which dart' and work backwards
  try {
    final result = Process.runSync('which', ['dart']);
    if (result.exitCode == 0) {
      final dartExecutable = result.stdout.toString().trim();
      // For Flutter SDK: /Users/davidketer/Developer/SDKs/flutter/bin/dart
      // We need: /Users/davidketer/Developer/SDKs/flutter/bin/cache/dart-sdk
      final dartDir = path.dirname(dartExecutable); // bin
      final flutterDir = path.dirname(dartDir); // flutter
      final sdkPath = path.join(flutterDir, 'bin', 'cache', 'dart-sdk');
      if (Directory(sdkPath).existsSync()) {
        return sdkPath;
      }
    }
  } catch (e) {
    // Ignore errors
  }
  
  // Final fallback
  return '/usr/local/lib/dart';
}

void _printUsage() {
  print('Usage: dart dart_analyzer.dart <input_file.dart> [-o <output_file>] [--no-docs]');
  print('   or: dart dart_analyzer.dart -d <directory> [--no-docs] [--processes <num>]');
  print('');
  print('Arguments:');
  print('  input_file.dart    The Dart file to analyze');
  print('  -o, --output file  Optional output file (default: <input>.dart.api)');
  print('  -d, --dir dir      Analyze all Dart files in directory (recursive)');
  print('  --no-docs          Exclude documentation comments from output');
  print('  --processes <num>  Number of concurrent processes for directory processing (default: half of CPU cores)');
  print('  -h, --help         Show this help message');
  print('');
  print('Examples:');
  print('  dart dart_analyzer.dart my_file.dart');
  print('  dart dart_analyzer.dart my_file.dart -o analysis_output.txt');
  print('  dart dart_analyzer.dart my_file.dart --output analysis_output.txt');
  print('  dart dart_analyzer.dart my_file.dart --no-docs');
  print('  dart dart_analyzer.dart -d src/');
  print('  dart dart_analyzer.dart --dir /path/to/project --no-docs');
  print('  dart dart_analyzer.dart -d src/ --processes 4');
}

DeclarationNode? _gatherDeclaration(dynamic declaration, {String? parentClassName, bool includeDocumentation = true}) {
  final names = _getPublicNames(declaration);
  if (names.isEmpty) return null;
  
  final kind = _getKind(declaration);
  final headers = _getDeclarationHeaders(declaration);
  final List<String> documentation = includeDocumentation ? _getDocumentation(declaration) : [];
  final children = _getNodesToAnalyze(declaration)
      .map((child) => _gatherDeclaration(child, 
          parentClassName: DeclarationNode._isContainerType(kind) ? names.first : parentClassName,
          includeDocumentation: includeDocumentation))
      .where((node) => node != null)
      .cast<DeclarationNode>()
      .toList();
      
  return DeclarationNode(
    kind: kind,
    names: names,
    headers: headers,
    documentation: documentation,
    children: children,
    parentClassName: parentClassName,
  );
}

List<String> _getPublicNames(dynamic declaration) {
  if (declaration is TopLevelVariableDeclaration) {
    return _getVariableNames(declaration.variables.variables);
  } else if (declaration is FieldDeclaration) {
    return _getVariableNames(declaration.fields.variables);
  } else {
    final name = _extractName(declaration);
    return name != null && !name.startsWith('_') ? [name] : [];
  }
}

List<String> _getVariableNames(List<VariableDeclaration> variables) {
  return variables
      .where((v) => !v.name.lexeme.startsWith('_'))
      .map((v) => v.name.lexeme)
      .toList();
}

String? _extractName(dynamic declaration) {
  if (declaration is ClassDeclaration) return declaration.name.lexeme;
  if (declaration is FunctionDeclaration) return declaration.name.lexeme;
  if (declaration is EnumDeclaration) return declaration.name.lexeme;
  if (declaration is FunctionTypeAlias) return declaration.name.lexeme;
  if (declaration is MixinDeclaration) return declaration.name.lexeme;
  if (declaration is ExtensionDeclaration) return declaration.name?.lexeme;
  if (declaration is ClassTypeAlias) return declaration.name.lexeme;
  if (declaration is GenericTypeAlias) return declaration.name.lexeme;
  if (declaration is ConstructorDeclaration) return declaration.name?.lexeme ?? 'default';
  if (declaration is MethodDeclaration) return declaration.name.lexeme;
  if (declaration is EnumConstantDeclaration) return declaration.name.lexeme;
  return null;
}

List<String> _getDeclarationHeaders(dynamic declaration) {
  if (declaration is TopLevelVariableDeclaration) {
    return declaration.variables.variables
        .where((v) => !v.name.lexeme.startsWith('_'))
        .map((v) => _getVariableHeader(declaration.variables, v))
        .toList();
  } else if (declaration is FieldDeclaration) {
    return declaration.fields.variables
        .where((v) => !v.name.lexeme.startsWith('_'))
        .map((v) => _getVariableHeader(declaration.fields, v))
        .toList();
  } else {
    final header = _extractHeader(declaration);
    return header != null ? [header] : [];
  }
}

String? _extractHeader(dynamic declaration) {
  if (declaration is ClassDeclaration || 
      declaration is EnumDeclaration || 
      declaration is MixinDeclaration || 
      declaration is ExtensionDeclaration) {
    return _trimAtBrace(declaration.toSource());
  } else if (declaration is FunctionDeclaration) {
    return _buildFunctionSignature(declaration);
  } else if (declaration is ConstructorDeclaration) {
    return _buildConstructorSignature(declaration);
  } else if (declaration is MethodDeclaration) {
    return _buildMethodSignature(declaration);
  } else if (declaration is EnumConstantDeclaration) {
    return _trimEnumConstantHeader(declaration.toSource());
  } else {
    return declaration.toSource(); // FunctionTypeAlias, ClassTypeAlias, GenericTypeAlias
  }
}

String _trimAtBrace(String source) {
  final braceIndex = source.indexOf('{');
  return braceIndex != -1 ? source.substring(0, braceIndex + 1) : source;
}

String _trimEnumConstantHeader(String source) {
  final indices = [
    source.indexOf('('),
    source.indexOf('{'),
    source.indexOf('=')
  ].where((i) => i != -1).toList();
  
  if (indices.isEmpty) return source.endsWith(',') ? source : '$source,';
  
  final cut = indices.reduce((a, b) => a < b ? a : b);
  final header = source.substring(0, cut).trimRight();
  return header.endsWith(',') ? header : '$header,';
}

String _buildFunctionSignature(FunctionDeclaration function) {
  final buffer = StringBuffer();
  
  // Return type
  if (function.returnType != null) {
    buffer.write('${function.returnType} ');
  }
  
  // Function name
  buffer.write('${function.name}');
  
  // Parameters
  buffer.write('(${_formatParameters(function.functionExpression.parameters)})');
  
  return '${buffer.toString().trimRight()};';
}

String _buildConstructorSignature(ConstructorDeclaration constructor) {
  final buffer = StringBuffer();
  
  // Get the class name from the parent
  final className = (constructor.parent as ClassDeclaration?)?.name.lexeme ?? '';
  
  // Constructor name (empty for default constructor)
  final constructorName = constructor.name?.lexeme ?? '';
  
  // Build the signature
  if (constructorName.isEmpty) {
    buffer.write('$className');
  } else {
    buffer.write('$className.$constructorName');
  }
  
  // Parameters
  buffer.write('(${_formatParameters(constructor.parameters)})');
  
  return '${buffer.toString().trimRight()};';
}

String _buildMethodSignature(MethodDeclaration method) {
  final buffer = StringBuffer();
  
  // Return type
  if (method.returnType != null) {
    buffer.write('${method.returnType} ');
  }
  
  // Method name
  buffer.write('${method.name}');
  
  // Parameters
  buffer.write('(${_formatParameters(method.parameters)})');
  
  return '${buffer.toString().trimRight()};';
}

String _formatParameters(FormalParameterList? parameters) {
  if (parameters == null || parameters.parameters.isEmpty) {
    return '';
  }

  final positional = <String>[];
  final optionalPositional = <String>[];
  final named = <String>[];

  for (final param in parameters.parameters) {
    if (param.isNamed) {
      named.add(_formatParameter(param));
    } else if (param.isOptionalPositional) {
      optionalPositional.add(_formatParameter(param));
    } else {
      positional.add(_formatParameter(param));
    }
  }

  final buffer = StringBuffer();
  buffer.write(positional.join(', '));
  if (optionalPositional.isNotEmpty) {
    if (buffer.isNotEmpty) buffer.write(', ');
    buffer.write('[');
    buffer.write(optionalPositional.join(', '));
    buffer.write(']');
  }
  if (named.isNotEmpty) {
    if (buffer.isNotEmpty) buffer.write(', ');
    buffer.write('{');
    buffer.write(named.join(', '));
    buffer.write('}');
  }
  return buffer.toString();
}

String _formatParameter(FormalParameter param) {
  if (param is DefaultFormalParameter) {
    final defaultValue = param.defaultValue?.toSource();
    final inner = _formatParameter(param.parameter);
    return defaultValue != null ? '$inner = $defaultValue' : inner;
  } else {
    return param.toSource();
  }
}

String _getVariableHeader(VariableDeclarationList list, VariableDeclaration variable) {
  final modifiers = <String>[];
  if (list.isConst) modifiers.add('const');
  if (list.isFinal) modifiers.add('final');
  if (list.isLate) modifiers.add('late');
  
  final type = list.type?.toString() ?? 'var';
  final modifiersStr = modifiers.isNotEmpty ? '${modifiers.join(' ')} ' : '';
  
  return '$modifiersStr$type ${variable.name};';
}

List<String> _getDocumentation(dynamic declaration) {
  if (declaration is AnnotatedNode && declaration.documentationComment != null) {
    return declaration.documentationComment!.tokens
        .map((token) => token.toString().trimRight())
        .where((line) => line.isNotEmpty)
        .cast<String>()
        .toList();
  }
  return [];
}

String _getKind(dynamic declaration) {
  if (declaration is ClassDeclaration) return 'class';
  if (declaration is FunctionDeclaration) return 'function';
  if (declaration is TopLevelVariableDeclaration) return 'variable';
  if (declaration is EnumDeclaration) return 'enum';
  if (declaration is FunctionTypeAlias) return 'function type alias';
  if (declaration is MixinDeclaration) return 'mixin';
  if (declaration is ExtensionDeclaration) return 'extension';
  if (declaration is ClassTypeAlias) return 'class type alias';
  if (declaration is GenericTypeAlias) return 'generic type alias';
  if (declaration is ConstructorDeclaration) return 'constructor';
  if (declaration is MethodDeclaration) return 'method';
  if (declaration is FieldDeclaration) return 'field';
  if (declaration is VariableDeclaration) return 'variable';
  if (declaration is EnumConstantDeclaration) return 'enum constant';
  return 'unknown';
}

List<dynamic> _getNodesToAnalyze(dynamic declaration) {
  if (declaration is TopLevelVariableDeclaration) return declaration.variables.variables;
  if (declaration is FieldDeclaration) return declaration.fields.variables;
  if (declaration is ClassDeclaration) return declaration.members;
  if (declaration is MixinDeclaration) return declaration.members;
  if (declaration is ExtensionDeclaration) return declaration.members;
  if (declaration is EnumDeclaration) return declaration.constants;
  return [];
}

Future<void> _processFile(String inputFile, String? outputFile, bool includeDocumentation) async {
  // Check if input file exists
  final inputFileObj = File(inputFile);
  if (!await inputFileObj.exists()) {
    print('Input file does not exist: $inputFile');
    exit(1);
  }

  // Determine output file
  if (outputFile == null) {
    final inputPath = inputFileObj.path;
    final baseName = inputPath.substring(0, inputPath.lastIndexOf('.'));
    outputFile = '${baseName}.dart.api';
  }
  
  // Convert output file to absolute path for portability
  final absoluteOutputFile = path.absolute(outputFile);

  // Analyze the file
  // Convert input file to absolute path for portability
  final absoluteInputFile = path.absolute(inputFile);
  
  try {
    // Find Dart SDK path for portability
    final dartSdkPath = _findDartSdkPath();
    
    final collection = AnalysisContextCollection(
      includedPaths: [absoluteInputFile],
      resourceProvider: PhysicalResourceProvider.INSTANCE,
      sdkPath: dartSdkPath,
    );

    final context = collection.contextFor(absoluteInputFile);
    final session = context.currentSession;

    final result = await session.getResolvedUnit(absoluteInputFile);
    if (result is! ResolvedUnitResult) {
      print('Failed to resolve file.');
      exit(1);
    }

    final tree = result.unit.declarations
        .map((decl) => _gatherDeclaration(decl, includeDocumentation: includeDocumentation))
        .where((node) => node != null)
        .cast<DeclarationNode>()
        .toList();

    // Write output to file
    final output = tree.map((node) => node.toString()).join('\n\n');
    await File(absoluteOutputFile).writeAsString(output);
    
    print('Analysis completed. Output written to: $absoluteOutputFile');
  } catch (e) {
    print('Error during analysis: $e');
    exit(1);
  }
}

Future<void> _processDirectory(String inputDirectory, bool includeDocumentation, int? maxProcesses) async {
  final directory = Directory(inputDirectory);
  if (!await directory.exists()) {
    print('Input directory does not exist: $inputDirectory');
    exit(1);
  }

  // Find all Dart files in the directory and subdirectories
  final dartFiles = await _findDartFiles(directory);
  
  if (dartFiles.isEmpty) {
    print('No Dart files found in directory: $inputDirectory');
    return;
  }

  print('Found ${dartFiles.length} Dart files to analyze...');
  
  // Determine number of processes to use (based on CPU cores)
  final processorCount = Platform.numberOfProcessors;
  final processCount = maxProcesses ?? (processorCount / 2).ceil().clamp(1, 8); // Use half the cores, max 8
  
  print('Using $processCount processes for parallel processing...');
  
  int processedCount = 0;
  int errorCount = 0;
  final errors = <String>[];

  // Process files in batches
  final batchSize = (dartFiles.length / processCount).ceil();
  final batches = <List<File>>[];
  
  for (int i = 0; i < dartFiles.length; i += batchSize) {
    final end = (i + batchSize < dartFiles.length) ? i + batchSize : dartFiles.length;
    batches.add(dartFiles.sublist(i, end));
  }

  // Process batches concurrently
  final futures = <Future<Map<String, dynamic>>>[];
  
  for (int batchIndex = 0; batchIndex < batches.length; batchIndex++) {
    final batch = batches[batchIndex];
    final future = _processBatch(batch, directory, includeDocumentation, batchIndex + 1, batches.length);
    futures.add(future);
  }

  // Wait for all batches to complete
  final results = await Future.wait(futures);
  
  // Aggregate results
  for (final result in results) {
    processedCount += result['processed'] as int;
    errorCount += result['errors'] as int;
    errors.addAll((result['errorMessages'] as List<dynamic>).cast<String>());
  }

  print('\nDirectory analysis completed:');
  print('  Processed: $processedCount files');
  if (errorCount > 0) {
    print('  Errors: $errorCount files');
    print('\nError details:');
    for (final error in errors) {
      print('  $error');
    }
  }
}

Future<Map<String, dynamic>> _processBatch(
  List<File> batch, 
  Directory baseDirectory, 
  bool includeDocumentation,
  int batchNumber,
  int totalBatches
) async {
  int processedCount = 0;
  int errorCount = 0;
  final errorMessages = <String>[];

  for (int i = 0; i < batch.length; i++) {
    final dartFile = batch[i];
    try {
      final relativePath = path.relative(dartFile.path, from: baseDirectory.path);
      final progress = ((i + 1) * 100 / batch.length).round();
      print('Batch $batchNumber/$totalBatches - Processing: $relativePath [${i + 1}/${batch.length}] ($progress%)');
      
      await _processFile(dartFile.path, null, includeDocumentation);
      processedCount++;
    } catch (e) {
      final errorMsg = 'Error processing ${dartFile.path}: $e';
      print(errorMsg);
      errorMessages.add(errorMsg);
      errorCount++;
    }
  }

  return {
    'processed': processedCount,
    'errors': errorCount,
    'errorMessages': errorMessages,
  };
}

Future<List<File>> _findDartFiles(Directory directory) async {
  final dartFiles = <File>[];
  
  try {
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        dartFiles.add(entity);
      }
    }
  } catch (e) {
    print('Error scanning directory: $e');
  }
  
  return dartFiles;
}
