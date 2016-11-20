
module Trainmaster

  ##
  # Use this module to read from and write to cache so prefix is
  # consistently enforced.
  #
  module Cache
    CACHE_VERSION = "0.0.1"

    def self.cache_key(key)
      if key.is_a? Hash
        key["_version"] = CACHE_VERSION
        return key
      else
        return {key: key, _version: CACHE_VERSION}
      end
    end

    def self.get(key)
      return Rails.cache.fetch(cache_key(key))
    end

    def self.set(key, value)
      Rails.cache.write(cache_key(key), value)
    end
  end
end
