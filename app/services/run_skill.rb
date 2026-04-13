# frozen_string_literal: true

class RunSkill
  CLAUDE_CLI = 'claude'

  def initialize(root: Rails.root)
    @root = root
  end

  def call(skill_file, arguments = '', pr_number: nil)
    skill_path = @root.join(skill_file)
    raise ArgumentError, "Skill file not found: #{skill_path}" unless skill_path.exist?

    prompt = skill_path.read
    prompt = prompt.gsub('$ARGUMENTS', arguments) if arguments.present?
    pr_filter = pr_number ? ".where(pr_number: #{pr_number})" : ''
    prompt = prompt.gsub('$PR_NUMBER_FILTER', pr_filter)

    pid = spawn(CLAUDE_CLI, '-p', prompt, '--verbose',
                chdir: @root.to_s,
                in: :in, out: :out, err: :err)
    _, status = Process.wait2(pid)

    raise "claude exited with code #{status.exitstatus}" unless status.success?
  rescue Errno::ENOENT
    abort 'Error: claude CLI not found. Install it with: npm install -g @anthropic-ai/claude-code'
  end
end
