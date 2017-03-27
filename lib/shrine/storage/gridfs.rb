require "shrine"
require "mongo"
require "down"
require "digest"

class Shrine
  module Storage
    class Gridfs
      attr_reader :client, :prefix, :bucket, :chunk_size

      BATCH_SIZE = 5 * 1024 * 1024

      def initialize(client:, prefix: "fs", chunk_size: 256*1024, **options)
        @client     = client
        @prefix     = prefix
        @chunk_size = chunk_size
        @bucket     = @client.database.fs(bucket_name: @prefix)

        @bucket.send(:ensure_indexes!)
      end

      def upload(io, id, shrine_metadata: {}, **)
        file = create_file(id, shrine_metadata: shrine_metadata)

        until io.eof?
          chunk = io.read([BATCH_SIZE, chunk_size].max, buffer ||= "")
          grid_chunks = Mongo::Grid::File::Chunk.split(chunk, file.info, offset ||= 0)

          chunks_collection.insert_many(grid_chunks)

          offset += grid_chunks.count
          grid_chunks.each { |grid_chunk| grid_chunk.data.data.clear } # deallocate strings
          chunk.clear # deallocate string
        end

        files_collection.find(_id: file.id).update_one(
          "$set" => {
            length:     io.size,
            uploadDate: Time.now.utc,
            md5:        file.info.md5.hexdigest,
          }
        )
      end

      def move(io, id, shrine_metadata: {}, **)
        file = create_file(id, shrine_metadata: shrine_metadata)

        chunks_collection.find(files_id: bson_id(io.id)).update_many("$set" => {files_id: file.id})
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

      def create_file(id, shrine_metadata: {})
        file = Mongo::Grid::File.new("",
          filename:     shrine_metadata["filename"] || id,
          content_type: shrine_metadata["mime_type"],
          metadata:     shrine_metadata,
          chunk_size:   chunk_size,
        )
        id.replace(file.id.to_s + File.extname(id))

        bucket.insert_one(file)

        file.info.document[:md5] = Digest::MD5.new
        file
      end

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
