require 'fileutils'

def remote_name
  ENV.fetch("REMOTE_NAME", "origin")
end

PROJECT_ROOT = `git rev-parse --show-toplevel`.strip
BUILD_DIR    = File.join(PROJECT_ROOT, "build")
TARGET_BRANCH  = "gh-pages"
TARGET_REF = File.join(BUILD_DIR, ".git/refs/remotes/#{remote_name}/#{TARGET_BRANCH}")

directory BUILD_DIR

file TARGET_REF => BUILD_DIR do
  repo_url = nil

  cd PROJECT_ROOT do
    repo_url = `git config --get remote.#{remote_name}.url`.strip
  end

  cd BUILD_DIR do
    sh "git init"
    sh "git remote add #{remote_name} #{repo_url}"
    sh "git fetch #{remote_name}"

    if `git branch -r` =~ Regexp.new( TARGET_BRANCH )
      sh "git checkout #{TARGET_BRANCH}"
    else
      sh "git checkout --orphan #{TARGET_BRANCH}"
      sh "touch index.html"
      sh "git add ."
      sh "git commit -m 'initial #{TARGET_BRANCH} commit'"
      sh "git push #{remote_name} #{TARGET_BRANCH}"
    end
  end
end

# Alias to something meaningful
task :prepare_git_remote_in_build_dir => TARGET_REF

# Fetch upstream changes on TARGET_BRANCH branch
task :sync do
  cd BUILD_DIR do
    sh "git fetch #{remote_name}"
    sh "git reset --hard #{remote_name}/#{TARGET_BRANCH}"
  end
end

# Prevent accidental publishing before committing changes
task :not_dirty do
  puts "***#{ENV['ALLOW_DIRTY']}***"
  unless ENV['ALLOW_DIRTY']
    fail "Directory not clean" if /nothing to commit/ !~ `git status`
  end
end

desc "Compile all files into the build directory"
task :build do
  cd PROJECT_ROOT do
    sh "bundle exec middleman build --clean"
  end
end

desc "Build and publish to Github Pages"
task :publish => [:not_dirty, :prepare_git_remote_in_build_dir, :sync, :build] do
  message = nil
  suffix = ENV["COMMIT_MESSAGE_SUFFIX"]

  cd PROJECT_ROOT do
    head = `git log --pretty="%h" -n1`.strip
    message = ["Site updated to #{head}", suffix].compact.join("\n\n")
  end

  cd BUILD_DIR do
    sh 'git add --all'
    if /nothing to commit/ =~ `git status`
      puts "No changes to commit."
    else
      sh "git commit -m \"#{message}\""
    end
    sh "git push #{remote_name} #{TARGET_BRANCH}"
  end
end
