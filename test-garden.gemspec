require 'test-garden'

Gem::Specification.new do |s|
  s.name = "test-garden"
  s.version = TestGarden::VERSION

  s.required_rubygems_version = Gem::Requirement.new(">= 0")
  s.authors = ["Joel VanderWerf"]
  s.date = Time.now.strftime "%Y-%m-%d"
  s.summary = "A garden of forking tests"
  s.description = "A testing framework for concisely sharing several stages of
setup code across tests."
  s.email = "vjoel@users.sourceforge.net"
  s.extra_rdoc_files = ["README.md", "COPYING"]
  s.files = Dir[
    "README.md", "COPYING", "Rakefile",
    "lib/**/*.rb",
    "examples/**/*.rb",
    "test/**/*.rb"
  ]
  s.test_files = Dir["test/*.rb"]
  s.homepage = "https://github.com/vjoel/test-garden"
  s.license = "BSD"
  s.rdoc_options = [
    "--quiet", "--line-numbers", "--inline-source",
    "--title", "test-garden", "--main", "README.md"]
  s.require_paths = ["lib"]

  s.add_dependency 'wrong', "~> 0.7"
end
