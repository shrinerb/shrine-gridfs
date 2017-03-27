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
  end

  after do
    @gridfs.clear!
  end

  it "passes the linter" do
    Shrine::Storage::Linter.new(@gridfs).call
  end

  it "allows inserting multiple files with the same filename" do
    @gridfs.upload(fakeio("file1"), id1 = "foo", shrine_metadata: {"filename" => "file.ext"})
    @gridfs.upload(fakeio("file2"), id2 = "bar", shrine_metadata: {"filename" => "file.ext"})

    assert_equal "file1", @gridfs.open(id1).read
    assert_equal "file2", @gridfs.open(id2).read
  end
end
