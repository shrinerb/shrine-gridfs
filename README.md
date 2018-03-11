# Shrine::Storage::Gridfs

Provides MongoDB's [GridFS] storage for [Shrine].

GridFS is a specification for storing and retrieving files in chunks, and is
convenient when MongoDB is already used in the application.

## Installation

```ruby
gem 'shrine-gridfs'
```

## Usage

You can initialize the GridFS storage with a Mongo connection:

```rb
require "shrine/storage/gridfs"

client = Mongo::Client.new("mongodb://127.0.0.1:27017/mydb")
Shrine::Storage::Gridfs.new(client: client)
```

### Prefix

The default prefix (bucket name) is "fs", you can change it with the `:prefix`
option, which is useful if you want to separate temporary and permanent storage.

```rb
Shrine.storages = {
  cache: Shrine::Storage::Gridfs.new(prefix: "temp", **options),
  store: Shrine::Storage::Gridfs.new(prefix: "fs", **options),
}
```

### Chunk size

By default the Gridfs storage will store files in chunks of 256KB, you can
change that via `:chunk_size`:

```rb
Shrine::Storage::Gridfs.new(chunk_size: 1*1024*1024, **options) # 1MB
```

### Batch size

When Gridfs storage uploads or copies a file, it will ensure that no more
than `:batch_size` of data is loaded into memory at once (defaults to 5MB).

```rb
Shrine::Storage::Gridfs.new(batch_size: 10*1024*1024, **options) # 10MB
```

### URLs

You can generate URLs through which the GridFS files will be streamed with the
`download_endpoint` plugin:

```rb
Shrine.plugin :download_endpoint, storages: [:store]
```
```rb
Rails.application.routes.draw do
  mount Shrine.download_endpoint => "/attachments"
end
```
```rb
user.avatar_url #=> "/attachments/store/9k30fks72j8.jpg"
```

## Development

You can run the tests with Rake:

```rb
$ bundle exec rake test
```

## Inspiration

This gem was inspired by [refile-gridfs].

## License

[MIT](http://opensource.org/licenses/MIT)

[GridFS]: https://docs.mongodb.org/v3.0/core/gridfs/
[Shrine]: https://github.com/shrinerb/shrine
[refile-gridfs]: https://github.com/Titinux/refile-gridfs
