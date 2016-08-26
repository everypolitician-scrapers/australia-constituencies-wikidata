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

module Wikidata
  class Constituency
    attr_reader :item

    def initialize(item)
      @item = item
    end

    def to_h
      protected_methods.map { |m|
        v = send(m) rescue nil
        [m, v]
      }.to_h
    end

    class Australia < Constituency

      protected

      def id
        item.id
      end

      def name
        item.label('en')
      end

      def state_id
        item.P131.value.id
      end

      def state
        item.P131.value.label('en')
      end

      def start_date
        item.P571.value
      end

      def end_date
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


