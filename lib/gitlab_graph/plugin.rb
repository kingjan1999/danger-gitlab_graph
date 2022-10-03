# frozen_string_literal: true
require 'svggraph'

module Danger
  # This is your plugin class. Any attributes or methods you expose here will
  # be available from within your Dangerfile.
  #
  # To be published on the Danger plugins site, you will need to have
  # the public interface documented. Danger uses [YARD](http://yardoc.org/)
  # for generating documentation from your plugin source, and you can verify
  # by running `danger plugins lint` or `bundle exec rake spec`.
  #
  # You should replace these comments with a public description of your library.
  #
  # @example Ensure people are well warned about merging on Mondays
  #
  #          my_plugin.warn_on_mondays
  #
  # @see  kingjan1999/danger-gitlab_graph
  # @tags monday, weekends, time, rattata
  #
  class DangerGitlabGraph < Plugin
    def extract_metric_from_pipeline(project_id, pipeline_id, extraction_regex, job_name)
      all_jobs = gitlab.api.pipeline_jobs(project_id, pipeline_id)
      target_job = all_jobs.find { |x| x.name == job_name }
      return false unless target_job

      job_trace = gitlab.api.job_trace(project_id, target_job.id)

      metric_matches = job_trace.match(extraction_regex)
      unless metric_matches.captures
        return false
      end

      metric_matches.captures[0].to_f
    end

    # A method that you can call from your Dangerfile
    # @return   [Array<String>]
    #
    def report_metric(extraction_regex, job_name, graph_options = {})
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
        ref: target_branch
      })

      previous_metrics = previous_target_branch_pipelines.collect { |pipeline| extract_metric_from_pipeline(project_id, pipeline.id, extraction_regex, job_name) }

      # create graph

      data = previous_metrics + [new_metric]

      fields = previous_target_branch_pipelines.collect { |pipeline| pipeline.id.to_s }
      fields += [pipeline_id]

      default_graph_options = {
        :width => 640,
        :height => 480,
        :graph_title => "Performance-Metrik",
        :show_graph_title => true,
        :x_title => "Pipeline-Ausführungen",
        :y_title => "Metrik-Wert",
        :show_y_title => true,
        :show_x_title => true,
        :number_format => "%.2fs",
        :fields => fields
      }

      g = SVG::Graph::Line.new(default_graph_options.merge(graph_options))

      g.add_data(:data => data)

      temp_file = Tempfile.new('graph')
      begin
        temp_file.write(g.burn_svg_only)
        uploaded_file = gitlab.api.upload_file(project_id, temp_file.path)
        markdown(uploaded_file.markdown)
      ensure
        temp_file.close
        temp_file.unlink
      end
    end
  end
end
