require 'minitest'

module Testributor
  class Reporter < ::Minitest::StatisticsReporter
    # Super method is doing it's magic. We simply put the results as JSON
    def report
      super
      io.puts aggregated_results.to_json
    end

    # The first lines are based on the original SummaryReporter
    # aggregated_results method.
    def aggregated_results
      filtered_results = results.dup
      filtered_results.reject!(&:skipped?) unless options[:verbose]
      s = filtered_results.join("\n")
      s.force_encoding(io.external_encoding) if
        ::Minitest::ENCS and io.external_encoding and s.encoding != io.external_encoding

      { result: s,
        errors: errors,
        failures: failures,
        count: count,
        assertions: assertions,
        skips: skips,
        total_time: total_time }
    end
  end
end

module Minitest
  # This enables the 'testributor' plugin. After that the next method will be
  # run to replace the default SummaryReporter with ours.
  self.extensions << 'testributor'
  # Remove all reporters and used our's
  def self.plugin_testributor_init options # :nodoc:
    self.reporter.reporters = []
    self.reporter << Testributor::Reporter.new(options[:io], options)
  end
end
