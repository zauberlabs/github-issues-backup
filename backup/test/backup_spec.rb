require "mocha"
require "ostruct"
require_relative "../lib/backup"

describe GithubBackup do

  it "should fail when backup directory does not exists" do

  end
  # deberia recibir:
  #  directorio donde hacer cambios
  #  
end

describe GithubIssuesWalker do
  
  before :each  do 
    @client = double()
    @walker = GithubIssuesWalker.new(@client)
  end

  describe "on_repositories" do
    it "should iterate over all repositories for an organization" do
      @client.should_receive(:repositories) {%w{repo1 repo2 repo3}}

      data = []
      @walker.on_repositories("org1") {|r| data << r}
      data.should eq(%w{repo1 repo2 repo3})
    end
  end

  describe "on_issues" do
    it "should retrieve open issues" do
      @client.should_receive(:repository) {OpenStruct.new(:has_issues => true)}
      @client.should_receive(:list_issues).with("repo", {:page => 0, :state => "open"}) do
        [1,2,4].collect {|i| OpenStruct.new(:number => i)}
      end
      @client.should_receive(:list_issues).with("repo", {:page => 0, :state => "closed"}) {[]}
      @client.should_receive(:issue).at_least(:once) {"content"}

      data = []
      @walker.on_issues("repo") {|r| data << r}
      data.should have(3).items
    end

    it "should retrieve closed issues" do
      @client.should_receive(:repository) {OpenStruct.new(:has_issues => true)}
      @client.should_receive(:list_issues).with("repo", {:page => 0, :state => "closed"}) do
        [1,2,4].collect {|i| OpenStruct.new(:number => i)}
      end
      @client.should_receive(:list_issues).with("repo", {:page => 0, :state => "open"}) {[]}
      @client.should_receive(:issue).at_least(:once) {"content"}

      data = []
      @walker.on_issues("repo") {|r| data << r}
      data.should have(3).items
    end

    it "should retrieve all issues pages" do
      @client.should_receive(:repository) { OpenStruct.new(:has_issues => true) }
      @client.should_receive(:list_issues).exactly(12).times do |repo, opt |
        values = if opt[:page] < 5 
                   (1..10)
                 else
                   (1..4)
                 end
        values.collect {|i| OpenStruct.new(:number => i)}
      end
      @client.should_receive(:issue).at_least(:once) {"content"}

      data = []
      @walker.on_issues("repo") { |r| data << r }
      data.should have(5*10*2 + 4*2).items
    end

    it "should retrieve issue content for each issue" do 
      @client.should_receive(:repository) { OpenStruct.new(:has_issues => true) }
      @client.should_receive(:list_issues).twice do |repo, opt|
        if opt[:state] == "open"
          [1].collect {|i| OpenStruct.new(:number => i)}
        else
          []
        end
      end
      @client.should_receive(:issue).at_least(:once) {"content"}

      data = []
      @walker.on_issues("repo") {|r| data << r}
      data.should have(1).items
      data[0].content.should eq("content")
    end
  end
end