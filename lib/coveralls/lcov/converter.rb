
module Coveralls
  module Lcov
    class Converter
      def initialize(tracefile, source_encoding = Encoding::UTF_8, service_name = "travis-ci", service_job_id = nil)
        @tracefile = tracefile
        @source_encoding = source_encoding
        @service_name = service_name
        @service_job_id = service_job_id
      end

      def convert
        source_files = []
        lcov_info = parse_tracefile
        lcov_info.each do |filename, info|
          source_files << generate_source_file(filename, info)
        end
        payload = {
          service_name: @service_name,
          service_job_id: service_job_id,
          git: git_info,
          source_files: source_files,
        }
        payload
      end

      def parse_tracefile
        lcov_info = Hash.new {|h, k| h[k] = {} }
        source_file = nil
        File.readlines(@tracefile).each do |line|
          case line.chomp
          when /\ASF:(.+)/
            source_file = $1
          when /\ADA:(\d+),(\d+)/
            line_no = $1.to_i
            count = $2.to_i
            lcov_info[source_file][line_no] = count
          when /\Aend_of_record/
            source_file = nil
          end
        end
        lcov_info
      rescue => ex
        warn "Could not read tracefile: #{@tracefile}"
        warn "#{ex.class}: #{ex.message}"
        exit(false)
      end

      def generate_source_file(filename, info)
        source = File.open(filename, "r:#{@source_encoding}", &:read).encode("UTF-8")
        lines = source.lines
        coverage = Array.new(lines.to_a.size)
        source.lines.each_with_index do |_line, index|
          coverage[index] = info[index + 1]
        end
        top_src_dir = Dir.pwd
        {
          name: filename.sub(%r!#{top_src_dir}/!, ""),
          source: source,
          coverage: coverage,
        }
      end

      def git_info
        {
          head: {
            id: `git log -1 --format=%H`,
            committer_email: `git log -1 --format=%ce`,
            committer_name: `git log -1 --format=%cN`,
            author_email: `git log -1 --format=%ae`,
            author_name: `git log -1 --format=%aN`,
            message: `git log -1 --format=%s`,
          },
          remotes: [], # FIXME need this?
          branch: `git rev-parse --abbrev-ref HEAD`,
        }
      end

      def service_job_id
        ENV["TRAVIS_JOB_ID"] || @service_job_id
      end
    end
  end
end
