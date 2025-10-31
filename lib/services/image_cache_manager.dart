import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class AppImageCacheManagers {
  AppImageCacheManagers._();

  static final BaseCacheManager banners = CacheManager(
    Config(
      'bannersCache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 150,
      repo: JsonCacheInfoRepository(databaseName: 'bannersCache'),
      fileService: HttpFileService(),
    ),
  );

  static final BaseCacheManager productImages = CacheManager(
    Config(
      'productImagesCache',
      stalePeriod: const Duration(days: 2),
      maxNrOfCacheObjects: 400,
      repo: JsonCacheInfoRepository(databaseName: 'productImagesCache'),
      fileService: HttpFileService(),
    ),
  );
}
