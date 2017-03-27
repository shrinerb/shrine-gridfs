Gem::Specification.new do |gem|
  gem.name          = "shrine-gridfs"
  gem.version       = "0.3.2"

  gem.required_ruby_version = ">= 2.1"

  gem.summary      = "Provides MongoDB's GridFS storage for Shrine."
  gem.homepage     = "https://github.com/janko-m/shrine-gridfs"
  gem.authors      = ["Janko Marohnić"]
  gem.email        = ["janko.marohnic@gmail.com"]
  gem.license      = "MIT"

  gem.files        = Dir["README.md", "LICENSE.txt", "lib/**/*.rb", "shrine-gridfs.gemspec"]
  gem.require_path = "lib"

  gem.add_dependency "shrine", "~> 2.2"
  gem.add_dependency "mongo", ">= 2.2.2", "< 3"
  gem.add_dependency "down", ">= 2.3.3"

  gem.add_development_dependency "rake"
  gem.add_development_dependency "minitest"
  gem.add_development_dependency "dotenv"
end
