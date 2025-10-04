import 'package:get_it/get_it.dart';

import '../core/api_client.dart';
import '../core/strategies/strategy_factory.dart';
import '../data/repositories/auth_repository_impl.dart';
import '../data/repositories/order_repository_impl.dart';
import '../data/repositories/product_repository_impl.dart';
import '../data/repositories/user_repository_impl.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/order_repository.dart';
import '../domain/repositories/product_repository.dart';
import '../domain/repositories/user_repository.dart';
import '../domain/usecases/create_order_usecase.dart';
import '../domain/usecases/get_me_usecase.dart';
import '../domain/usecases/get_my_orders_usecase.dart';
import '../domain/usecases/get_products_by_category_usecase.dart';
import '../domain/usecases/login_usecase.dart';
import '../domain/usecases/recharge_usecase.dart';
import '../domain/usecases/register_usecase.dart';

final GetIt injector = GetIt.instance;

Future<void> setupDependencies() async {
  // Initialize strategy factory
  await StrategyFactory.initialize();

  // Core
  injector.registerLazySingleton<ApiClient>(() => ApiClient());

  // Repositories
  injector.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(injector.get<ApiClient>()),
  );
  injector.registerLazySingleton<ProductRepository>(
    () => ProductRepositoryImpl(injector.get<ApiClient>()),
  );
  injector.registerLazySingleton<OrderRepository>(
    () => OrderRepositoryImpl(injector.get<ApiClient>()),
  );
  injector.registerLazySingleton<UserRepository>(
    () => UserRepositoryImpl(injector.get<ApiClient>()),
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
  injector.registerFactory<GetMyOrdersUseCase>(
    () => GetMyOrdersUseCase(injector.get<OrderRepository>()),
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

  // Strategy contexts
  injector.registerLazySingleton(() => StrategyFactory.createPaymentContext());
  injector.registerLazySingleton(() => StrategyFactory.createValidationContext());
  injector.registerLazySingleton(() => StrategyFactory.createCacheContext());
  injector.registerLazySingleton(() => StrategyFactory.createUIContext());
  injector.registerLazySingleton(() => StrategyFactory.createErrorHandlingContext());
}
