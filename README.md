# Shrine::Gridfs

Provides MongoDB's [GridFS] storage for [Shrine].

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

The default prefix (bucket name) is "fs", you can change it with the `:prefix`
option:

```rb
Shrine::Storage::Gridfs.new(client: client, prefix: "foo")
```

### URLs

You can generate URLs through which the GridFS files will be streamed with the
`download_endpoint` plugin:

```rb
Shrine.plugin :download_endpoint, storages: [:store]
```
```rb
Rails.application.routes.draw do
  mount Shrine::DownloadEndpoint => "/attachments"
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

## License

[MIT](http://opensource.org/licenses/MIT)

[GridFS]: https://docs.mongodb.org/v3.0/core/gridfs/
[Shrine]: https://github.com/janko-m/shrine
