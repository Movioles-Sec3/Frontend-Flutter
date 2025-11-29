import 'package:hive_flutter/hive_flutter.dart';
import 'package:get_it/get_it.dart';

import '../core/api_client.dart';
import '../core/strategies/caching_strategy.dart';
import '../core/strategies/strategy_factory.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../data/repositories/order_repository_impl.dart';
import '../data/repositories/price_conversion_repository_impl.dart';
import '../data/repositories/product_repository_impl.dart';
import '../data/repositories/recommendation_repository_impl.dart';
import '../data/repositories/user_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/order_repository.dart';
import '../domain/repositories/price_conversion_repository.dart';
import '../domain/repositories/product_repository.dart';
import '../domain/repositories/recommendation_repository.dart';
import '../domain/repositories/user_repository.dart';
import '../domain/usecases/create_order_usecase.dart';
import '../domain/usecases/get_me_usecase.dart';
import '../domain/usecases/get_my_orders_usecase.dart';
import '../domain/usecases/get_order_details_usecase.dart';
import '../domain/usecases/get_product_price_conversion_usecase.dart';
import '../domain/usecases/get_products_by_category_usecase.dart';
import '../domain/usecases/get_recommended_products_usecase.dart';
import '../domain/usecases/login_usecase.dart';
import '../domain/usecases/recharge_usecase.dart';
import '../domain/usecases/register_usecase.dart';
import '../domain/usecases/search_products_usecase.dart';
import '../domain/usecases/submit_seat_delivery_survey_usecase.dart';
import '../services/form_cache_service.dart';
import '../services/profile_local_storage.dart';
import '../services/product_local_storage.dart';
import '../services/session_manager.dart';

final GetIt injector = GetIt.instance;

Future<void> setupDependencies() async {
  // Initialize secure storage for session handling
  await Hive.initFlutter();
  await Hive.openBox<String>(SessionManager.boxName);

  // Initialize strategy factory
  await StrategyFactory.initialize();

  // Core
  injector.registerLazySingleton<ApiClient>(() => ApiClient());

  // Repositories
  injector.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(injector.get<ApiClient>()),
  );
  injector.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(
      injector.get<ApiClient>(),
      injector.get<CacheContext<String>>(),
    ),
  );
  injector.registerLazySingleton<OrderRepository>(
    () => OrderRepositoryImpl(injector.get<ApiClient>()),
  );
  injector.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(injector.get<ApiClient>()),
  );
  injector.registerLazySingleton<RecommendationRepository>(
    () => RecommendationRepositoryImpl(injector.get<ApiClient>()),
  );
  injector.registerLazySingleton<PriceConversionRepository>(
    () => PriceConversionRepositoryImpl(injector.get<ApiClient>()),
  );

  // Use cases
  injector.registerFactory<LoginUseCase>(
    () => LoginUseCase(injector.get<AuthRepository>()),
  );
  injector.registerFactory<RegisterUseCase>(
    () => RegisterUseCase(injector.get<AuthRepository>()),
  );
  injector.registerFactory<GetProductsByCategoryUseCase>(
    () => GetProductsByCategoryUseCase(injector.get<ProductRepository>()),
  );
  injector.registerFactory<SearchProductsUseCase>(
    () => SearchProductsUseCase(injector.get<ProductRepository>()),
  );
  injector.registerFactory<GetMyOrdersUseCase>(
    () => GetMyOrdersUseCase(injector.get<OrderRepository>()),
  );
  injector.registerFactory<GetOrderDetailsUseCase>(
    () => GetOrderDetailsUseCase(injector.get<OrderRepository>()),
  );
  injector.registerFactory<CreateOrderUseCase>(
    () => CreateOrderUseCase(injector.get<OrderRepository>()),
  );
  injector.registerFactory<GetMeUseCase>(
    () => GetMeUseCase(injector.get<UserRepository>()),
  );
  injector.registerFactory<RechargeUseCase>(
    () => RechargeUseCase(injector.get<UserRepository>()),
  );
  injector.registerFactory<GetRecommendedProductsUseCase>(
    () =>
        GetRecommendedProductsUseCase(injector.get<RecommendationRepository>()),
  );
  injector.registerFactory<GetProductPriceConversionUseCase>(
    () => GetProductPriceConversionUseCase(
      injector.get<PriceConversionRepository>(),
    ),
  );
  injector.registerFactory<SubmitSeatDeliverySurveyUseCase>(
    () => SubmitSeatDeliverySurveyUseCase(injector.get<UserRepository>()),
  );

  // Strategy contexts
  injector.registerLazySingleton(() => StrategyFactory.createPaymentContext());
  injector.registerLazySingleton(
    () => StrategyFactory.createValidationContext(),
  );
  injector.registerLazySingleton(() => StrategyFactory.createCacheContext());
  injector.registerLazySingleton(() => StrategyFactory.createUIContext());
  injector.registerLazySingleton(
    () => StrategyFactory.createErrorHandlingContext(),
  );
  injector.registerLazySingleton(
    () => StrategyFactory.createRecommendationContext(
      injector.get<GetRecommendedProductsUseCase>(),
    ),
  );
  injector.registerLazySingleton(
    () => StrategyFactory.createCurrencyDisplayContext(),
  );

  // Services
  // Use SharedPreferences-backed cache for auth form drafts so they persist across sessions
  injector.registerLazySingleton<PreferencesCachingStrategy>(
    () => PreferencesCachingStrategy(),
  );
  injector.registerLazySingleton<FormCacheService>(
    () => FormCacheService(injector.get<PreferencesCachingStrategy>()),
  );
  final ProfileLocalStorage profileLocalStorage = ProfileLocalStorage();
  await profileLocalStorage.init();
  injector.registerSingleton<ProfileLocalStorage>(profileLocalStorage);

  final ProductLocalStorage productLocalStorage = ProductLocalStorage(
    defaultTtl: const Duration(hours: 12),
  );
  await productLocalStorage.init();
  injector.registerSingleton<ProductLocalStorage>(productLocalStorage);
}
