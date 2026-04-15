# frozen_string_literal: true

require 'open3'

class RunSkill
  CLAUDE_CLI = 'claude'

  def initialize(root: Rails.root)
    @root = root
  end

  def call(skill_file, arguments = '', pr_number: nil, config: nil, output_file: nil)
    skill_path = @root.join(skill_file)
    raise ArgumentError, "Skill file not found: #{skill_path}" unless skill_path.exist?

    prompt = skill_path.read
    prompt = prompt.gsub('$ARGUMENTS', arguments) if arguments.present?
    pr_filter     = pr_number ? ".where(pr_number: #{pr_number})" : ''
    config_filter = config    ? ".where(config: '#{config}')"     : ''
    prompt = prompt.gsub('$PR_NUMBER_FILTER', pr_filter)
    prompt = prompt.gsub('$CONFIG_FILTER', config_filter)
    prompt = prompt.gsub('$CONFIG', config.to_s)

    if output_file
      FileUtils.mkdir_p(File.dirname(output_file))
      Open3.popen2(CLAUDE_CLI, '-p', prompt, '--verbose', chdir: @root.to_s) do |_stdin, stdout, wait_thr|
        File.open(output_file, 'w') do |f|
          stdout.each_line do |line|
            $stdout.print line
            $stdout.flush
            f.print line
          end
        end
        status = wait_thr.value
        raise "claude exited with code #{status.exitstatus}" unless status.success?
      end
    else
      pid = spawn(CLAUDE_CLI, '-p', prompt, '--verbose',
                  chdir: @root.to_s,
                  in: :in, out: :out, err: :err)
      _, status = Process.wait2(pid)
      raise "claude exited with code #{status.exitstatus}" unless status.success?
    end
  rescue Errno::ENOENT
    abort 'Error: claude CLI not found. Install it with: npm install -g @anthropic-ai/claude-code'
  end
end
