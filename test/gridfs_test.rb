require "test_helper"
require "shrine/storage/linter"
require "mongo"
require "logger"

describe Shrine::Storage::Gridfs do
  def gridfs(options = {})
    options[:client] ||= Mongo::Client.new("mongodb://127.0.0.1:27017/mydb", logger: Logger.new(nil))

    Shrine::Storage::Gridfs.new(options)
  end

  before do
    @gridfs = gridfs
    shrine_class = Class.new(Shrine)
    shrine_class.storages[:gridfs] = @gridfs
    @uploader = shrine_class.new(:gridfs)
  end

  after do
    @gridfs.clear!
  end

  it "passes the linter" do
    Shrine::Storage::Linter.new(@gridfs).call
  end

  describe "#upload" do
    it "allows multiple files with the same filename" do
      @gridfs.upload(fakeio("file1"), id1 = "foo", shrine_metadata: {"filename" => "file.ext"})
      @gridfs.upload(fakeio("file2"), id2 = "bar", shrine_metadata: {"filename" => "file.ext"})

      assert_equal "file1", @gridfs.open(id1).read
      assert_equal "file2", @gridfs.open(id2).read
    end

    it "saves file in batches" do
      content = "a" * 5*1024*1024 + "b" * 5*1024*1024
      @gridfs.upload(fakeio(content), id = "foo")
      assert_equal content, @gridfs.open(id).read

      file_info = @gridfs.bucket.files_collection.find(_id: BSON::ObjectId(id)).first
      assert_equal 10*1024*1024, file_info[:length]
      assert_equal Digest::MD5.hexdigest(content), file_info[:md5]
    end

    it "saves filename and content type" do
      @gridfs.upload(fakeio, id1 = "foo", shrine_metadata: {"filename" => "file.txt", "mime_type" => "text/plain"})
      file_info = @gridfs.bucket.files_collection.find(_id: BSON::ObjectId(id1)).first
      assert_equal "file.txt",   file_info[:filename]
      assert_equal "text/plain", file_info[:contentType]

      @gridfs.upload(fakeio, id2 = "foo")
      file_info = @gridfs.bucket.files_collection.find(_id: BSON::ObjectId(id2)).first
      assert_equal "foo",                      file_info[:filename]
      assert_equal "application/octet-stream", file_info[:contentType]
    end

    it "copies another Gridfs file" do
      content = "a" * 5*1024*1024 + "b" * 5*1024*1024
      uploaded_file = @uploader.upload(fakeio(content))
      source_id = uploaded_file.id
      @gridfs.upload(uploaded_file, dest_id = "bar")

      source_info = @gridfs.bucket.files_collection.find(_id: BSON::ObjectId(source_id)).first
      dest_info   = @gridfs.bucket.files_collection.find(_id: BSON::ObjectId(dest_id)).first

      refute_equal source_info[:_id], dest_info[:_id]
      assert_equal content, @gridfs.open(dest_id).read
      assert_equal "application/octet-stream", dest_info[:contentType]
    end
  end

  describe "#open" do
    it "returns correct #size" do
      @gridfs.upload(fakeio("file"), id = "foo")
      io = @gridfs.open(id)
      assert_equal 4, io.size
    end
  end
end
