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

    # Gathers metric data from current and pevious pipelines
    # @return Arrray<{pipeline_id => int, :metric => float}>
    def gather_metric(extraction_config, prev_pipeline_count = 10)
      pipeline_id = ENV["CI_PIPELINE_ID"].to_i
      project_id = ENV["CI_PROJECT_ID"]

      target_branch = gitlab.branch_for_merge

      begin
        new_metric = extract_metric_from_pipeline(project_id, pipeline_id, extraction_config[:regex], extraction_config[:job_name])
      rescue JobNotFoundException
        warn("Job #{extraction_config[:job_name]} for metric extraction of #{extraction_config[:series_name]} not found in current pipeline")
        return []
      end

      unless new_metric[:metric]
        warn("No updated metric #{extraction_config[:series_name]} found for job #{extraction_config[:job_name]}")
        return []
      end

      previous_target_branch_pipelines = gitlab.api.pipelines(project_id, {
        status: 'success',
        ref: target_branch,
        per_page: prev_pipeline_count
      })

      previous_metrics = previous_target_branch_pipelines.collect do |pipeline|
        begin
          extract_metric_from_pipeline(project_id, pipeline.id, extraction_config[:regex], extraction_config[:job_name]).merge(hash: pipeline.sha)
        rescue JobNotFoundException
          return { pipeline_id: pipeline.id, metric: false, hash: pipeline.sha }
        end
      end

      previous_metrics + [new_metric.merge(hash: ENV["CI_COMMIT_SHA"])]
    end

    # Creates and comments a graph based on a certain metric, extracted via regex
    # @param extraction_regex Hash-Array: {:regex, :job_name, :series_name}
    # @param job_name Job name to extract from
    # @param prev_pipeline_count
    # @param graph_option see svg-graph doc
    def report_metric(extraction_configs, prev_pipeline_count = 10, graph_options = {})
      project_id = ENV["CI_PROJECT_ID"]

      fields = nil
      all_data = []
      extraction_configs.each do |extraction_config|
        all_metrics = gather_metric(extraction_config, prev_pipeline_count)

        if all_metrics.length == 0
          next
        end

        if fields and all_metrics.length != fields.length
          warn("Not all metrics could be found in an equal amount of jobs. Unable to plot #{extraction_config[:series_name]}")
          next
        end

        data = all_metrics.collect { |val| val[:metric] }

        fields ||= all_metrics.collect { |pipeline| "#{pipeline[:hash][0..7]}" }

        all_data.push({ data: data, title: extraction_config[:series_name] })
      end

      if all_data.length == 0
        return
      end

      default_graph_options = {
        width: 640,
        height: 480,
        graph_title: "Performance Metric",
        show_graph_title: true,
        x_title: "Commit",
        y_title: "Metric Value",
        show_y_title: true,
        show_x_title: true,
        number_format: "%.2fs",
        fields: fields
      }

      # create graph
      g = SVG::Graph::Line.new(default_graph_options.merge(graph_options))

      all_data.each { |elem| g.add_data(data: elem[:data], title: elem[:title]) }

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
      raise JobNotFoundException, "job #{job_name} not found in pipeline #{pipeline_id}" unless target_job

      job_trace = gitlab.api.job_trace(project_id, target_job.id)

      metric_matches = job_trace.match(extraction_regex)
      unless metric_matches&.captures
        return { pipeline_id: pipeline_id, metric: false }
      end

      { pipeline_id: pipeline_id, metric: metric_matches.captures[0].to_f }
    end

    class JobNotFoundException < StandardError

    end
  end
end
