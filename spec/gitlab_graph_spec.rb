# frozen_string_literal: true

require "fileutils"
require File.expand_path("spec_helper", __dir__)

module Danger
  describe Danger::DangerGitlabGraph, host: :gitlab do
    it "should be a plugin" do
      expect(Danger::DangerGitlabGraph.new(nil)).to be_a Danger::Plugin
    end

    describe "with Dangerfile" do
      graph_tmpfile = nil

      before do
        stub_version("11.2.3")

        @dangerfile = testing_dangerfile
        @my_plugin = @dangerfile.gitlab_graph

        allow(@my_plugin.gitlab).to receive(:branch_for_merge).and_return("main")

        stub_const("ENV", ENV.to_hash.merge(testing_env))

        pipelines = File.read("#{File.dirname(__FILE__)}/support/fixtures/pipelines.json")

        # stub requests
        stub_jobs(123456)
        stub_jobs(1119)

        stub_trace(2722)
        stub_trace(2723)

        stub_request(:get, "https://gitlab.com/api/v4/projects/123/pipelines?per_page=10&ref=main&status=success").
          to_return(:status => 200, :body => pipelines, :headers => {})

        stub_request(:post, "https://gitlab.com/api/v4/projects/123/uploads").
          to_return do |request|

          svg_file = request.body[request.body.index("<svg")..request.body.index("</svg>") + 5]
          graph_tmpfile = Tempfile.new(["tmp-graph", ".svg"])
          begin
            graph_tmpfile.write(svg_file)
          ensure
            graph_tmpfile.close
          end

          { :status => 200, :body => {
            markdown: "![description](/link)"
          }.to_json, :headers => {} }
        end

      end

      after do
        graph_tmpfile&.unlink
      end

      it "outputs a markdown image link" do
        @my_plugin.report_metric([{
                                    regex: /took ([0-9]+)/,
                                    series_name: "Performance",
                                    job_name: "test1"
                                  }, {
                                    regex: /slept ([0-9]+)/,
                                    series_name: "IDLE time",
                                    job_name: "test1"
                                  }])

        expect(@dangerfile.status_report[:markdowns][0].message).to eq("![description](/link)")
        expect(graph_tmpfile).not_to be_nil

        expected_graph_file = "#{File.dirname(__FILE__)}/support/fixtures/graph-simple-expected.svg"
        expect(FileUtils.compare_file(graph_tmpfile.path, expected_graph_file)).to be_truthy
      end

      it "warns an error if there is no match" do
        @my_plugin.report_metric([{
                                    regex: /not found ([0-9]+)/,
                                    series_name: "Performance",
                                    job_name: "test1"
                                  }])

        expect(@dangerfile.status_report[:warnings]).to eq(["No updated metric Performance found for job test1"])
      end

      it "warns if there is no such job" do
        @my_plugin.report_metric([{
                                    regex: /took ([0-9]+)/,
                                    series_name: "Performance",
                                    job_name: "not-found-either"
                                  }])

        expect(@dangerfile.status_report[:warnings]).to eq(["Job not-found-either for metric extraction of Performance not found in current pipeline"])
      end

      it "gathers all metrics" do
        metrics = @my_plugin.gather_metric({
                                             regex: /took ([0-9]+)/,
                                             series_name: "Performance",
                                             job_name: "test1"
                                           })

        expect(@dangerfile.status_report[:warnings]).to eq([])
        expect(metrics).to eq([{ :hash => "b23f54ecdc3add9abea9344f66b49f1699bff547", :metric => 16.0, :pipeline_id => 1119 },
                               { :hash => "3333333333333333333333333333333333333333", :metric => 6.0, :pipeline_id => 123456 }])
      end
    end
  end
end
