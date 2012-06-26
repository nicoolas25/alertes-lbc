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
require './database'
require './request'

require 'sinatra'

class HelloApp < Sinatra::Base
  get '/' do
    @requests = Request.all
    haml :index
  end

  get '/check' do
    Request.all.each do |r|
      if r.refresh!
        LOG.info "Something is new for '#{r.name}' at #{r.url}"
        r.save
        Pony.mail(
          :via => :smtp,
          :via_options => SMTP_CONFIG,
          :to => CONFIG_EMAIL[RACK_ENV]['email']['to'],
          :subject => "Nouvelles sur le bon coin pour '#{r.name}'",
          :body => "J'ai une nouvelle annonce ici : #{r.url}")
      end
    end
    redirect '/'
  end

  get '/add' do
    haml :add
  end

  post '/add' do
    r = Request.create(:name   => params[:name],
                       :url    => params[:url],
                       :period => params[:period])
    redirect '/'
  end

  get '/delete/:id' do |id|
    Request.where(id: id).first.destroy
    redirect '/'
  end
end
