require "shrine"
require "mongo"
require "down"
require "digest"

class Shrine
  module Storage
    class Gridfs
      attr_reader :client, :prefix, :bucket, :chunk_size

      def initialize(client:, prefix: "fs", chunk_size: 256*1024, batch_size: 5 * 1024*1024, **options)
        @client     = client
        @prefix     = prefix
        @chunk_size = chunk_size
        @batch_size = batch_size
        @bucket     = @client.database.fs(bucket_name: @prefix)

        @bucket.send(:ensure_indexes!)
      end

      def upload(io, id, shrine_metadata: {}, **)
        if copyable?(io, id)
          copy(io, id, shrine_metadata: shrine_metadata)
        else
          create(io, id, shrine_metadata: shrine_metadata)
        end
      end

      def open(id, rewindable: true, **)
        info   = file_info(id) or raise Shrine::FileNotFound, "file #{id.inspect} not found on storage"
        stream = bucket.open_download_stream(bson_id(id))

        Down::ChunkedIO.new(
          size:       info[:length],
          chunks:     stream.enum_for(:each),
          on_close:   -> { stream.close },
          rewindable: rewindable,
        )
      end

      def exists?(id)
        !!file_info(id)
      end

      def delete(id)
        bucket.delete(bson_id(id))
      rescue Mongo::Error::FileNotFound
      end

      def url(id, **)
      end

      def clear!
        files_collection.find.delete_many
        chunks_collection.find.delete_many
      end

      protected

      def file_info(id)
        bucket.find(_id: bson_id(id)).limit(1).first
      end

      def files_collection
        bucket.files_collection
      end

      def chunks_collection
        bucket.chunks_collection
      end

      private

      def create(io, id, shrine_metadata: {})
        filename = shrine_metadata["filename"] || id
        options = {
          content_type: shrine_metadata["mime_type"] || "application/octet-stream",
          metadata:     shrine_metadata,
          chunk_size:   chunk_size,
        }

        file_id = bucket.upload_from_stream(filename, io, options)

        id.replace(file_id.to_s + File.extname(id))
      end

      def copy(io, id, shrine_metadata: {})
        source_storage = io.storage
        source_info    = source_storage.file_info(io.id)
        dest_info      = source_info.merge(_id: BSON::ObjectId.new)

        batch_size = (@batch_size.to_f / chunk_size).ceil
        chunk_batches = source_storage.chunks_collection
          .find(files_id: source_info[:_id])
          .batch_size(batch_size).each_slice(batch_size)

        chunk_batches.each do |chunks|
          chunks.each do |chunk|
            chunk[:_id] = BSON::ObjectId.new
            chunk[:files_id] = dest_info[:_id]
          end

          chunks_collection.insert_many(chunks)

          chunks.each do |chunk|
            chunk[:data].data.clear # deallocate strings
          end
        end

        dest_info[:uploadDate] = Time.now.utc
        dest_info[:filename]   = shrine_metadata["filename"] || id
        files_collection.insert_one(dest_info)
        id.replace(dest_info[:_id].to_s + File.extname(id))
      end

      def copyable?(io, id)
        io.is_a?(UploadedFile) && io.storage.is_a?(Storage::Gridfs)
      end

      def bson_id(id)
        BSON::ObjectId(File.basename(id, ".*"))
      end
    end
  end
end
