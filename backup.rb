#!/usr/bin/env ruby
require 'rubygems'
require 'octokit'
require 'json'


user = ""
password = ""

client = Octokit::Client.new(:login => user, :password => password)

orgName = 'zauberlabs'

if !File.directory?("issues")
        Dir.mkdir('issues')
end

client.repositories(orgName).each { |repo|
    dirName = File.join("issues", repo.name)
    if !File.directory?(dirName)
        Dir.mkdir(dirName)
    end
    ['open', 'closed'].each { |status|
        page = 0

        ## navego las multiples paginas
        begin
            issues = client.list_issues("%s/%s" % [orgName, repo.name], {
                 :page  => page, 
                 :state => status
            })
            issues.each { |issue|
                 ## file where the issue is saved
                 issueFilename = '%s/%04d.js' % [dirName,issue.number]
                 json = JSON.pretty_generate(client.issue("%s/%s" % [orgName, repo.name], issue.number))
                 File.open(issueFilename , 'w') {|f| f.write(json) }
            }
            page = page + 1
        end until issues.length != 10
    }

}


