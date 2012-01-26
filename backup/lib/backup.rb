#!/usr/bin/env ruby
require 'rubygems'
require 'octokit'
require 'json'
require 'grit'
require 'ostruct'
require 'trollop'
require 'pathname'


def parse_options
  opts = Trollop::options do
    opt :localrepo, "Path to the local repository where backups are saved", 
      :short => "-r",
      :type => String,
      :required => true
    opt :organization, "Organization as known by Github", 
      :short => "-o",
      :type => String,
      :required => true
    opt :github_user, "Github User", 
      :short => "-u",
      :type => String,
      :required => true
    opt :github_password, "Github Password", 
      :short => "-p",
      :type => String,
      :required => true
  end
  Trollop::die :localrepo, "must exist" unless File.directory? opts[:localrepo]
  opts
end

  
class GithubBackup

  def initialize(walker, local_repo)
    @walker = walker
    @local_repo = Pathname.new local_repo
  end

  def get_or_create_project_dir(project_name)
    projectdir = @local_repo + project_name
    projectdir.mkdir unless projectdir.directory?
  end

  def serialize_issue(issue)
    JSON.pretty_generate( issue.content )
  end

  def save_issue(dirname, issue)
    filename = '%s/%04d.js' % [ dirname, issue.number ]
    File.open(filename , 'w') { |f| f.write(serialize_issue(issue)) }
  end

  def run( orgname )
    orgdir = @local_repo + orgname
    orgdir.mkdir unless orgdir.directory?
    
    @walker.on_repositories orgname do |repo|      
      reponame = "#{orgname}/#{repo.name}"
      puts "Backuping #{reponame}"
      
      projectdir = orgdir + repo.name
      projectdir.mkdir unless projectdir.directory?

      @walker.on_issues(reponame) {|issue| save_issue(projectdir, issue)}
    end

    puts 'Commiting...'
    repo = Grit::Repo.new(@local_repo)
    Dir.chdir(@local_repo)
    repo.add(".")
    repo.commit_index("Backup...")
    puts 'Finish commit...'
  end

end


class GithubIssuesWalker
  def initialize(client) 
    @client = client
  end

  def on_issues(reponame, &block)
    if @client.repository(reponame).has_issues 
      ['open', 'closed'].each do |status|
        page = 0

        begin
            issues = @client.list_issues( reponame, :page => page, :state => status )
            issues.each do |issue|
              yield OpenStruct.new(:number => issue.number, 
                                   :content => @client.issue(reponame, issue.number))
            end
            page += 1
        end until issues.length != 10
      end
    end
  end

  def on_repositories(orgname, &block)
    @client.repositories(orgname).each(&block)   
  end
end

if __FILE__ == $0
  opts = parse_options

  walker = GithubIssuesWalker.new(
            Octokit::Client.new(
              :login => opts[:github_user], 
              :password => opts[:github_password]))
  GithubBackup.new(walker, opts[:localrepo]).run opts[:organization]
end