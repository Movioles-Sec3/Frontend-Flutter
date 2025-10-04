/// Base interface for all strategy implementations
abstract class Strategy<T, R> {
  /// Execute the strategy with the given input
  Future<R> execute(T input);
  
  /// Get the strategy identifier
  String get identifier;
  
  /// Check if this strategy can handle the given input
  bool canHandle(T input);
}

/// Base interface for strategies that don't require async execution
abstract class SyncStrategy<T, R> {
  /// Execute the strategy with the given input
  R execute(T input);
  
  /// Get the strategy identifier
  String get identifier;
  
  /// Check if this strategy can handle the given input
  bool canHandle(T input);
}

/// Strategy context that manages strategy selection and execution
class StrategyContext<T, R> {
  StrategyContext({
    required this.defaultStrategy,
    this.strategies = const [],
  });

  final Strategy<T, R> defaultStrategy;
  final List<Strategy<T, R>> strategies;

  /// Execute strategy based on input analysis
  Future<R> execute(T input) async {
    final strategy = _selectStrategy(input);
    return await strategy.execute(input);
  }

  /// Select the appropriate strategy for the given input
  Strategy<T, R> _selectStrategy(T input) {
    for (final strategy in strategies) {
      if (strategy.canHandle(input)) {
        return strategy;
      }
    }
    return defaultStrategy;
  }

  /// Add a new strategy to the context
  void addStrategy(Strategy<T, R> strategy) {
    strategies.add(strategy);
  }

  /// Remove a strategy by identifier
  void removeStrategy(String identifier) {
    strategies.removeWhere((s) => s.identifier == identifier);
  }
}

/// Strategy factory for creating strategy instances
class StrategyFactory {
  static final Map<Type, List<Strategy<dynamic, dynamic>>> _strategies = {};

  /// Register a strategy for a specific type
  static void register<T, R>(Strategy<T, R> strategy) {
    _strategies.putIfAbsent(T, () => []);
    _strategies[T]!.add(strategy);
  }

  /// Get all strategies for a specific type
  static List<Strategy<T, R>> getStrategies<T, R>() {
    return _strategies[T]?.cast<Strategy<T, R>>() ?? [];
  }

  /// Create a strategy context for a specific type
  static StrategyContext<T, R> createContext<T, R>({
    required Strategy<T, R> defaultStrategy,
  }) {
    return StrategyContext<T, R>(
      defaultStrategy: defaultStrategy,
      strategies: getStrategies<T, R>(),
    );
  }
}
