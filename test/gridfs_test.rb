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
    @gridfs.clear!(:confirm)
  end

  it "passes the linter" do
    Shrine::Storage::Linter.new(@gridfs, action: :warn).call
  end

  describe "#download" do
    it "preserves the extension" do
      @gridfs.upload(fakeio, id = "foo.jpg")
      tempfile = @gridfs.download(id)

      assert_equal ".jpg", File.extname(tempfile.path)
    end
  end
end
