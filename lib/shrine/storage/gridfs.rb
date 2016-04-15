require "shrine"
require "mongo"

require "stringio"

class Shrine
  module Storage
    class Gridfs
      attr_reader :client, :prefix, :bucket

      def initialize(client:, prefix: "fs", **options)
        @client = client
        @prefix = prefix
        @bucket = @client.database.fs(bucket_name: @prefix)
        @bucket.send(:ensure_indexes!)
      end

      def upload(io, id, metadata = {})
        filename = metadata["filename"] || id
        file = Mongo::Grid::File.new(io, filename: filename, metadata: metadata)
        result = bucket.insert_one(file)
        id.replace(result.to_s + File.extname(id))
      end

      def download(id)
        tempfile = Tempfile.new(["shrine", File.extname(id)], binmode: true)
        bucket.download_to_stream(bson_id(id), tempfile)
        tempfile.open
        tempfile
      end

      def stream(id)
        content_length = bucket.find(_id: bson_id(id)).first["length"]
        bucket.open_download_stream(bson_id(id)) do |stream|
          stream.each { |chunk| yield chunk, content_length }
        end
      end

      def open(id)
        download(id)
      end

      def read(id)
        stringio = StringIO.new
        bucket.download_to_stream(bson_id(id), stringio)
        stringio.string
      end

      def exists?(id)
        !!bucket.find(_id: bson_id(id)).first
      end

      def delete(id)
        bucket.delete(bson_id(id))
      end

      def multi_delete(ids)
        ids = ids.map { |id| bson_id(id) }
        bucket.files_collection.find(_id: {"$in" => ids}).delete_many
        bucket.chunks_collection.find(files_id: {"$in" => ids}).delete_many
      end

      def url(id, **options)
      end

      def clear!(confirm = nil)
        raise Shrine::Confirm unless confirm == :confirm
        bucket.files_collection.find.delete_many
        bucket.chunks_collection.find.delete_many
      end

      private

      def bson_id(id)
        BSON::ObjectId(File.basename(id, ".*"))
      end
    end
  end
end
