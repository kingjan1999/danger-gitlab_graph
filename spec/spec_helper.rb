# frozen_string_literal: true

require "pathname"
ROOT = Pathname.new(File.expand_path("..", __dir__))
$:.unshift("#{ROOT}lib".to_s)
$:.unshift("#{ROOT}spec".to_s)
$LOAD_PATH.unshift File.expand_path("../../lib", __FILE__)
$LOAD_PATH.unshift File.expand_path("../..", __FILE__)

require "bundler/setup"
require "pry"

require "rspec"
require "danger"
require "webmock"
require "webmock/rspec"

if `git remote -v` == ""
  puts "You cannot run tests without setting a local git remote on this repo"
  puts "It's a weird side-effect of Danger's internals."
  exit(0)
end

Dir["spec/support/**/*.rb"].sort.each { |file| require(file) }

# Use coloured output, it's the best.
RSpec.configure do |config|
  config.filter_gems_from_backtrace "bundler"
  config.color = true
  config.tty = true

  config.include Danger::Support::GitLabHelper, host: :gitlab
  # config.include Danger::Support::CIHelper, use: :ci_helper
end

require "danger_plugin"

WebMock.disable_net_connect!(allow: "coveralls.io")

# These functions are a subset of https://github.com/danger/danger/blob/master/spec/spec_helper.rb
# If you are expanding these files, see if it's already been done ^.

# A silent version of the user interface,
# it comes with an extra function `.string` which will
# strip all ANSI colours from the string.

# rubocop:disable Lint/NestedMethodDefinition
def testing_ui
  @output = StringIO.new

  def @output.winsize
    [20, 9999]
  end

  cork = Cork::Board.new(out: @output)

  def cork.string
    out.string.gsub(/\e\[([;\d]+)?m/, "")
  end

  cork
end

# rubocop:enable Lint/NestedMethodDefinition

# Example environment (ENV) that would come from
# running a PR on TravisCI
def testing_env
  {
    "CI_PIPELINE_ID" => "123456",
    "CI_PROJECT_ID" => "123",
    "GITLAB_CI" => "1",
    "CI_COMMIT_SHA" => "3333333333333333333333333333333333333333",
    "CI_COMMIT_SHORT_SHA" => "33333333",
    "CI_PROJECT_PATH" => "k0nserv/danger-test",
    "CI_PROJECT_URL" => "https://gitlab.com/k0nserv/danger-test",
    "DANGER_GITLAB_API_TOKEN" => "a86e56d46ac78b",
    "CI_MERGE_REQUEST_IID" => "145"
  }
end

# A stubbed out Dangerfile for use in tests
def testing_dangerfile
  env = Danger::EnvironmentManager.new(testing_env)
  Danger::Dangerfile.new(env, testing_ui)
end
