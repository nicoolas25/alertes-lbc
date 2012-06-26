#!/usr/bin/env ruby

require "bundler/setup"
require 'sequel'
require 'nokogiri'
require 'open-uri'
require 'pry'
require 'pony'
require 'optparse'
require 'ostruct'
require 'logger'
require 'yaml'

FILEPATH    = File.expand_path(File.dirname(__FILE__))
CONFIG      = YAML.load_file(File.join(FILEPATH, "config", "email.yml"))
SMTP_CONFIG = CONFIG["smtp"].inject({}){|m,(k,v)| m[k.to_sym] = v; m}
LOG         = Logger.new(STDOUT)
LOG.level   = Logger::ERROR

DB = Sequel.sqlite(File.join(FILEPATH, "database.sqlite3"))

options = OpenStruct.new
OptionParser.new do |opts|
  opts.banner = "Usage: lbc.rb.rb [options]"
  opts.on("-v", "--verbose", "Verbose mode") {|p| LOG.level = Logger::INFO if p }
  opts.on("-p", "--purge", "Purge database") {|p| options.purge = p }
  opts.on("-a", "--add", "Add a query") {|a| options.add = a }
  opts.on("-i", "--interactive", "Go in an interactive mode") {|i| options.console = i }
  opts.on("-c", "--check", "Verify the query") {|c| options.check = c }
  opts.on("-m", "--mail", "Send a testmail") {|m| options.testmail = m }
  opts.on("-s", "--sendmail", "Send a mail if something is new (--check)") {|s| options.sendmail = s }
  opts.on_tail("-h", "--help", "Show this message") { puts opts and exit }
end.parse!

unless DB.tables.include?(:requests)
  LOG.info "Create table 'requests'..."
  DB.create_table :requests do
    primary_key :id
    String :url
    String :page_id
    String :name
    Integer :period
    Time :last_verification

    index :url, :unique => true
  end
  LOG.info "Table 'request' have been successfully created!" if DB.tables.include?(:requests)
end

class Request < Sequel::Model(:requests)
  def before_create
    normalize_url!
    refresh!
    super
  end

  def normalize_url!
    uri = URI.parse(url)
    uri.query &&= uri.query.split('&').sort.join('&')
    self.url = uri.to_s
  end

  def refresh!
    @last_page_id = @doc = nil
    is_new = last_page_id != page_id
    self.page_id = last_page_id
    is_new
  end

  def doc
    @doc ||= Nokogiri::HTML(open(url))
  end

  def last_page_id
    @last_page_id ||= /\/(\d+).htm/.match(doc.css("div.list-ads > a:first-child").first[:href])[1]
  end
end

def dont_check
  options.check = false
end

if options.purge
  LOG.info "Purge requests..."
  Request.delete
end

if options.add
  puts "Give me an url"
  url = gets.chomp
  puts "Give me a name"
  name = gets.chomp
  begin
    Request.create(:name => name, :url => url)
  rescue Exception => e
    LOG.error "Exception #{e} raised"
    binding.pry
  end
  exit
end

if options.console
  # start a REPL session
  LOG.info "Starts the REPL..."
  binding.pry
end

if options.check
  Request.all.each do |r|
    if r.refresh!
      LOG.info "Something is new for '#{r.name}' at #{r.url}"
      r.save
      if options.sendmail
        Pony.mail(
          :via => :smtp,
          :via_options => SMTP_CONFIG,
          :to => CONFIG["email"]["to"],
          :subject => "Nouvelles sur le bon coin pour '#{r.name}'",
          :body => "J'ai une nouvelle annonce ici : #{r.url}")
      end
    else
      LOG.info "Nothing new for '#{r.name}'"
    end
  end
end

if options.testmail
  r = Request.first
  Pony.mail(
    :via => :smtp,
    :via_options => SMTP_CONFIG,
    :to => CONFIG["email"]["to"],
    :subject => "Nouvelles sur le bon coin pour '#{r.name}'",
    :body => "J'ai une nouvelle annonce ici : #{r.url}")
end
