# frozen_string_literal: true
require 'svggraph'

module Danger
  # This plugin retrieves a certain metric from previous job runs and displays them as a graph
  #
  # @example Extract values from job "test" with the given regex
  #
  #          gitlab_graph.report_metric(/performance: ([0-9]+)s/, "test")
  #
  # @see  kingjan1999/danger-gitlab_graph
  # @tags gitlab, graph, performance
  #
  class DangerGitlabGraph < Plugin
    # Creates and comments a graph based on a certain metric, extracted via regex
    # @return   [Array<String>]
    #
    def report_metric(extraction_regex, job_name, prev_pipeline_count = 10, graph_options = {})
      pipeline_id = ENV["CI_PIPELINE_ID"]
      project_id = ENV["CI_PROJECT_ID"]

      target_branch = gitlab.branch_for_merge

      new_metric = extract_metric_from_pipeline(project_id, pipeline_id, extraction_regex, job_name)
      unless new_metric
        warn("No updated metric found for job #{job_name}")
        return
      end

      previous_target_branch_pipelines = gitlab.api.pipelines(project_id, {
        status: 'success',
        ref: target_branch,
        per_page: prev_pipeline_count
      })

      previous_metrics = previous_target_branch_pipelines.collect { |pipeline| extract_metric_from_pipeline(project_id, pipeline.id, extraction_regex, job_name) }
      previous_metrics = previous_metrics.select { |val| val[1] }
      # create graph

      data = previous_metrics.collect { |val| val[1] }
      data = previous_metrics + [new_metric]

      fields = previous_metrics.collect { |pipeline| "Run #{pipeline[0]}" }
      fields += [pipeline_id]

      default_graph_options = {
        :width => 640,
        :height => 480,
        :graph_title => "Performance Metric",
        :show_graph_title => true,
        :x_title => "Pipeline Runs",
        :y_title => "Metric Value",
        :show_y_title => true,
        :show_x_title => true,
        :number_format => "%.2fs",
        :fields => fields
      }

      g = SVG::Graph::Line.new(default_graph_options.merge(graph_options))

      g.add_data(:data => data)

      temp_file = Tempfile.new(%w[graph .svg])
      begin
        temp_file.write(g.burn_svg_only)
        uploaded_file = gitlab.api.upload_file(project_id, temp_file.path)
        markdown(uploaded_file.markdown)
      ensure
        temp_file.close
        temp_file.unlink
      end
    end

    private

    def extract_metric_from_pipeline(project_id, pipeline_id, extraction_regex, job_name)
      all_jobs = gitlab.api.pipeline_jobs(project_id, pipeline_id)
      target_job = all_jobs.find { |x| x.name == job_name }
      return false unless target_job

      job_trace = gitlab.api.job_trace(project_id, target_job.id)

      metric_matches = job_trace.match(extraction_regex)
      unless metric_matches.captures
        return pipeline_id, false
      end

      [pipeline_id, metric_matches.captures[0].to_f]
    end
  end
end
