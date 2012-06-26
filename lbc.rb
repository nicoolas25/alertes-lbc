#!/usr/bin/env ruby

require 'bundler/setup'
require 'sequel'
require 'nokogiri'
require 'open-uri'
require 'pry'
require 'pony'
require 'optparse'
require 'ostruct'
require 'logger'
require 'yaml'

require './patches'
require './config'

options = OpenStruct.new
OptionParser.new do |opts|
  opts.banner = 'Usage: lbc.rb.rb [options]'
  opts.on('-v', '--verbose', 'Verbose mode') {|p| LOG.level = Logger::INFO if p }
  opts.on('-p', '--purge', 'Purge database') {|p| options.purge = p }
  opts.on('-a', '--add', 'Add a query') {|a| options.add = a }
  opts.on('-i', '--interactive', 'Go in an interactive mode') {|i| options.console = i }
  opts.on('-c', '--check', 'Verify the query') {|c| options.check = c }
  opts.on('-l', '--list', 'List all the queries') {|l| options.list = l }
  opts.on('-m', '--mail', 'Send a testmail') {|m| options.testmail = m }
  opts.on('-s', '--sendmail', 'Send a mail if something is new (--check)') {|s| options.sendmail = s }
  opts.on_tail('-h', '--help', 'Show this message') { puts opts and exit }
end.parse!

def dont_check
  options.check = false
end

require './database'
require './request'

if options.purge
  LOG.info 'Purge requests...'
  Request.delete
end

if options.add
  puts 'Give me an url'
  url = gets.chomp
  puts 'Give me a name'
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
  LOG.info 'Starts the REPL...'
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
          :to => CONFIG_EMAIL[RACK_ENV]['email']['to'],
          :subject => "Nouvelles sur le bon coin pour '#{r.name}'",
          :body => "J'ai une nouvelle annonce ici : #{r.url}")
      end
    else
      LOG.info "Nothing new for '#{r.name}'"
    end
  end
end

if options.list
  Request.all.each do |r|
    STDOUT.puts "#{r.name} @ #{r.url}"
  end
end

if options.testmail
  r = Request.first
  Pony.mail(
    :via => :smtp,
    :via_options => SMTP_CONFIG,
    :to => CONFIG['email']['to'],
    :subject => "Nouvelles sur le bon coin pour '#{r.name}'",
    :body => "J'ai une nouvelle annonce ici : #{r.url}")
end
