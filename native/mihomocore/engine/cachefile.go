package engine

import (
	"time"

	"github.com/metacubex/bbolt"
	"github.com/metacubex/mihomo/component/profile/cachefile"
	"github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/log"
)

const cacheFileWait = 10 * time.Second

func openCacheFile() {
	cache := cachefile.Cache()
	if cache.DB != nil {
		return
	}
	db, err := bbolt.Open(constant.Path.Cache(), 0o666, &bbolt.Options{Timeout: cacheFileWait, NoStatistics: true})
	if err != nil {
		log.Warnln("[CacheFile] still can't open the cache file after %s, fake-ip addresses will not resolve: %s", cacheFileWait, err)
		return
	}
	log.Infoln("[CacheFile] opened once the previous engine released it")
	cache.DB = db
}

func closeCacheFile() {
	cache := cachefile.Cache()
	if cache.DB == nil {
		return
	}
	if err := cache.DB.Close(); err != nil {
		log.Warnln("[CacheFile] close failed: %s", err)
	}
	cache.DB = nil
}
