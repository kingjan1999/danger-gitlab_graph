# frozen_string_literal: true

# adapted from https://github.com/danger/danger/blob/0d23ca3e1095101aa60e9a7b629b7cf02f0b187a/spec/support/gitlab_helper.rb
module Danger
  module Support
    module GitLabHelper
      def expected_headers
        {
          "Accept" => "application/json",
          "PRIVATE-TOKEN" => stub_env["DANGER_GITLAB_API_TOKEN"]
        }
      end

      def stub_env
        {
          "GITLAB_CI" => "1",
          "CI_COMMIT_SHA" => "3333333333333333333333333333333333333333",
          "CI_PROJECT_PATH" => "k0nserv/danger-test",
          "CI_PROJECT_URL" => "https://gitlab.com/k0nserv/danger-test",
          "CI_MERGE_REQUEST_PROJECT_PATH" => "k0nserv/danger-test",
          "CI_MERGE_REQUEST_PROJECT_URL" => "https://gitlab.com/k0nserv/danger-test",
          "DANGER_GITLAB_API_TOKEN" => "a86e56d46ac78b"
        }
      end

      def stub_ci(env = stub_env)
        Danger::GitLabCI.new(env)
      end

      def stub_request_source(env = stub_env)
        Danger::RequestSources::GitLab.new(stub_ci(env), env)
      end

      def stub_jobs(pipeline_id)
        pipeline_jobs = File.read("#{File.dirname(__FILE__)}/fixtures/jobs-#{pipeline_id}.json")

        stub_request(:get, "https://gitlab.com/api/v4/projects/123/pipelines/#{pipeline_id}/jobs").
          to_return(status: 200, body: pipeline_jobs, headers: {})
      end

      def stub_trace(job_id)
        trace_job = File.read("#{File.dirname(__FILE__)}/fixtures/trace-#{job_id}.txt")

        stub_request(:get, "https://gitlab.com/api/v4/projects/123/jobs/#{job_id}/trace").
          to_return(status: 200, body: trace_job, headers: {})
      end

      def stub_version(version)
        url = "https://gitlab.com/api/v4/version"
        WebMock.stub_request(:get, url).with(headers: expected_headers).to_return(
          body: "{\"version\":\"#{version}\",\"revision\":\"1d9280e\"}"
        )
      end
    end
  end
end
