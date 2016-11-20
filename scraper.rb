#!/bin/env ruby
# encoding: utf-8

require 'wikidata/fetcher'
require 'rest-client'

WIKIDATA_SPARQL_URL = 'https://query.wikidata.org/sparql'.freeze

def wikidata_sparql(query)
  result = RestClient.get WIKIDATA_SPARQL_URL, params: { query: query, format: 'json' }
  json = JSON.parse(result, symbolize_names: true)
  json[:results][:bindings].map { |res| res[:item][:value].split('/').last }
rescue RestClient::Exception => e
  abort "Wikidata query #{query.inspect} failed: #{e.message}"
end

def p31s(qid)
  query = "SELECT ?item WHERE { ?item wdt:P31 wd:#{qid} . }"
  wikidata_sparql(query)
end

module FieldSerializer
  def self.included(klass)
    klass.extend ClassMethods
  end

  module ClassMethods
    def fields
      @fields ||= {}
    end

    def field(name, &block)
      fields[name] = block
    end
  end

  def to_h
    self.class.fields.map { |name, block|
      v = instance_eval(&block) rescue nil
      [name, v]
    }.to_h
  end
end

module Wikidata
  class Constituency
    include FieldSerializer

    attr_reader :item

    def initialize(item)
      @item = item
    end

    class Australia < Constituency

      field :id do
        item.id
      end

      field :name do
        item.label('en')
      end

      field :state_id do
        item.P131.value.id
      end

      field :state do
        item.P131.value.label('en')
      end

      field :start_date do
        item.P571.value
      end

      field :end_date do
        item.P576.value
      end
    end
  end
end


#---------------------------------------------------------------------

ids = p31s('Q2713747')

Wikisnakker::Item.find(ids).map do |i|
  c = Wikidata::Constituency::Australia.new(i)
  data = c.to_h rescue binding.pry
  ScraperWiki.save_sqlite([:id], data)
end


