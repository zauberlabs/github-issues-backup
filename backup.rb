#!/usr/bin/env ruby
require 'rubygems'
require 'octokit'
require 'json'
require 'grit'
include Grit

user = ""
password = ""

unless ARGV[0]
  puts "Usage: #{$O} [folderBackup]"
  exit
end

folderBackup = ARGV[0]

client = Octokit::Client.new(:login => user, :password => password)

orgName = 'zauberlabs'

if !File.directory?(folderBackup)
    puts "The directory '" + folderBackup + "' doesn't exist"
    exit!
end

client.repositories(orgName).each { |repo|
    puts "Backuping " + repo.name
    dirName = File.join(folderBackup, repo.name)
    if !File.directory?(dirName)
        Dir.mkdir(dirName)
    end
    
    repoName = "%s/%s" % [orgName, repo.name]

    if client.repository(repoName).has_issues
	    ['open', 'closed'].each { |status|
		page = 0

		## navego las multiples paginas
		begin
		    issues = client.list_issues(repoName, {
		         :page  => page, 
		         :state => status
		    })
		    issues.each { |issue|
		         ## file where the issue is saved
		         issueFilename = '%s/%04d.js' % [dirName,issue.number]
		         json = JSON.pretty_generate(client.issue(repoName, issue.number))
		         File.open(issueFilename , 'w') {|f| f.write(json) }
		    }
		    page = page + 1
		end until issues.length != 10
	    }
    else
	puts '    Ignore %s project without issues' % repoName
    end
}

puts 'Commiting...'
repo = Repo.new(folderBackup)
Dir.chdir(folderBackup)
repo.add(".")
repo.commit_index("Backup...")
puts 'Finish commit...'
