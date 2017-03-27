require "shrine"
require "mongo"
require "down"

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

      def upload(io, id, shrine_metadata: {}, **)
        filename = shrine_metadata["filename"] || id
        file = Mongo::Grid::File.new(io, filename: filename, metadata: shrine_metadata)
        result = bucket.insert_one(file)
        id.replace(result.to_s + File.extname(id))
      end

      def move(io, id, shrine_metadata: {}, **)
        filename = shrine_metadata["filename"] || id
        files_collection.insert_one(_id: (file_id = BSON::ObjectId.new), filename: filename, metadata: shrine_metadata)
        id.replace(file_id.to_s + File.extname(id))

        chunks_collection.find(files_id: bson_id(io.id)).update_many("$set" => {files_id: file_id})
        files_collection.delete_one(_id: bson_id(io.id))
      end

      def movable?(io, id)
        io.is_a?(UploadedFile) && io.storage.is_a?(Storage::Gridfs)
      end

      def open(id)
        content_length = bucket.find(_id: bson_id(id)).first["length"]
        stream = bucket.open_download_stream(bson_id(id))

        Down::ChunkedIO.new(
          size: content_length,
          chunks: stream.enum_for(:each),
          on_close: -> { stream.close },
        )
      end

      def exists?(id)
        !!bucket.find(_id: bson_id(id)).first
      end

      def delete(id)
        bucket.delete(bson_id(id))
      rescue Mongo::Error::FileNotFound
      end

      def multi_delete(ids)
        ids = ids.map { |id| bson_id(id) }
        files_collection.find(_id: {"$in" => ids}).delete_many
        chunks_collection.find(files_id: {"$in" => ids}).delete_many
      end

      def url(id, **)
      end

      def clear!
        files_collection.find.delete_many
        chunks_collection.find.delete_many
      end

      private

      def files_collection
        bucket.files_collection
      end

      def chunks_collection
        bucket.chunks_collection
      end

      def bson_id(id)
        BSON::ObjectId(File.basename(id, ".*"))
      end
    end
  end
end
