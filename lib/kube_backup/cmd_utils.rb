require 'shellwords'
require 'open3'

module KubeBackup
  module CmdUtils
    def pipe_stream(from, to, buffer: nil, skip_piping: false)
      thread = Thread.new do
        begin
          while char = from.getc
            to.write(char) if !skip_piping
            buffer << char if buffer
          end
        rescue IOError => error
          #p error
        end

        #remaining = from.read
        #to.write(remaining) if !skip_piping
        #buffer << remaining if buffer
      end

      #thread.abort_on_exception = true
    end

    def record_stream(from, buffer: nil)
      pipe_stream(from, nil, buffer: buffer, skip_piping: true)
    end

    def cmd(command, *args)
      args = args.flatten

      env_vars = args.last.is_a?(Hash) ? args.pop : {}
      env_vars = env_vars.dup
      modified_env_vars = env_vars.dup

      ENV.each do |key, value|
        env_vars[key] ||= value
      end

      escaped_args = args.map do |arg|
        if arg && arg.to_s.start_with?("|", ">", "<", "&")
          arg.to_s
        else
          Shellwords.escape(arg)
        end
      end

      command = "#{command} #{escaped_args.join(" ")}".strip

      #if verbose_logging?
        KubeBackup.logger.info "RUN #{command.colorize(:green)}"
      #end

      KubeBackup.logger.debug "ENV #{KubeBackup::LogUtil.hash(modified_env_vars)}" if modified_env_vars.size > 0

      stdout_str  = ""
      stderr_str  = ""
      exit_status = nil
      start_time  = Time.now.to_f
      process_error = nil
      io_threads = []

      stdout_str, stderr_str, exit_status = Open3.capture3(env_vars, command)

      if exit_status != 0
        KubeBackup.logger.warn "Process #{exit_status.pid} exit with code #{exit_status.exitstatus}"
      end

      # Open3.popen3(env_vars, command) do |stdin, stdout, stderr, wait_thr|
      #   begin
      #     #if KubeBackup.verbose_logging?
      #     # io_threads << pipe_stream(stdout, STDOUT, buffer: stdout_str)
      #     # io_threads << pipe_stream(stderr, STDERR, buffer: stderr_str)
      #     #else
      #     # io_threads << record_stream(stdout, buffer: stdout_str)
      #     # io_threads << record_stream(stderr, buffer: stderr_str)
      #     #end
      #
      #
      #     puts "complet 0"
      #
      #     exit_status = wait_thr.value
      #
      #     puts "complete 1"
      #     p exit_status
      #
      #     stdout_str = stdout.read
      #     stderr_str = stderr.read
      #
      #     puts "complete 2"
      #
      #
      #   rescue => error
      #     p error
      #     process_error = error
      #   end
      # end

      #io_threads.each(&:value)

      # raise process_error if process_error

      {
        exit_code: exit_status.exitstatus,
        pid: exit_status.pid,
        stdout: stdout_str,
        stderr: stderr_str,
        success: exit_status.success?,
        time: Time.now.to_f - start_time
      }
    end
  end
end
