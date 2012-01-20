#!/usr/bin/env ruby
require 'net/http'
require 'json'
require 'savon'
require 'rubygems'
require 'highline/import'

def get_password(prompt="Enter Password")
   ask(prompt) {|q| q.echo = false}
end

Savon.configure do |config|
  config.log = false            # disable logging
  config.log_level = :info      # changing the log level
end

HTTPI.log_level = :info

client = Savon::Client.new do
  wsdl.document = "mantis.wsdl.xml"
end

###
 
mantis_user = ask("Enter mantis username")
mantis_password = get_password("Enter mantis password")

puts "Available root projects (user can have access to other projects not listed here):"

begin
	resp = client.request :mc_projects_get_user_accessible do
	  soap.body = {
		:username    => mantis_user,
		:password    => mantis_password
	  }
	end
rescue Savon::Error => error
  puts "Error logging in."
  Process.exit
end

response = resp.to_hash


response[:mc_projects_get_user_accessible_response][:return][:item].each do|project|
   puts project[:name] + "(" + project[:id] + ")"
end

mantis_project_id = ask("Enter mantis project id")

begin
	issues_resp = client.request :mc_project_get_issues do
	  soap.body = {
		:username    => mantis_user,
		:password    => mantis_password,
		:project_id  => mantis_project_id
	  }
	end
rescue Savon::Error => error
  puts "Error fetching project issues."
  Process.exit
end

gh_user = ask("Enter github user")
gh_password = get_password("Enter github password")
gh_owner = ask("Enter github project owner")
gh_project = ask("Enter github project name")

if ask("WARNING! You are about to import your mantis issues into your GitHub project. So far, Github issues CANNOT be deleted so this cannot be undone Are you sure you want to continue? (Y/N)") != 'Y'
   Process.exit
end

uri = URI('https://api.github.com/repos/' + gh_owner + '/' + gh_project + '/issues')

response = issues_resp.to_hash

if response.has_key?:mc_project_get_issues_response
   response[:mc_project_get_issues_response][:return][:item].each do|issue|
	  puts "============= Issue:" + issue[:summary]
      puts "Description: " + issue[:description]

	  if issue.has_key?:handler
		puts "Assignee:" + issue[:handler][:email]
	  else 
		puts "Unassigned!"
	  end

	  puts "Status: " + issue[:status][:name]
      puts "Resolution:" + issue[:resolution][:name]

# if closed, close issue!

		req = Net::HTTP::Post.new(uri.path)
		req.basic_auth gh_user, gh_password

		req.body = { 
			"title" => issue[:summary],
			"body" => issue[:description]
#			"assignee": "frangz",
#			"milestone": 1,
#			"labels": [
#			  "Label1",
#			  "Label2"
#			 ]
		  }.to_json

		res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') do |http|
		  http.request(req)
		end

		response = JSON.parse(res.body)

		puts "Created issue " + response['number']

=begin
	  if issue[:notes].has_key?:item
		  puts "=== Comments:"
		  if issue[:notes][:item].class == Hash
 			puts issue[:notes][:item][:reporter][:email]
			puts issue[:notes][:item][:text]
	      else issue[:notes][:item].class == Array 
		  	issue[:notes][:item].each do|comment|
	 			puts comment[:reporter][:email]
				puts comment[:text]
			end
		  end
      end 
=end

   end
else
   puts "Error in response"
end







=begin
uri = URI('https://api.github.com/repos/zauberlabs/github-issues-backup/issues')
req = Net::HTTP::Post.new(uri.path)
req.basic_auth 'zauberci', 'compilame12esto'

req.body = { 
    "title" => "My Test Issue 2!",
    "body" => "Issue body",
    "assignee": "frangz",
    "milestone": 1,
    "labels": [
      "Label1",
      "Label2"
     ]
  }.to_json

res = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => uri.scheme == 'https') do |http|
  http.request(req)
end

response = JSON.parse(res.body)

puts "Created issue " + response['number']
=end
