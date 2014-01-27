require 'spec_helper'

describe Route53::Connection do
  describe "#initialize" do
    it "sets the base_url to the endpoint plus the api" do
      conn = Route53::Connection.new('access_key', 'secret', '1999-01-01', 'https://www.example.com/')
      expect(conn.base_url).to eq('https://www.example.com/1999-01-01')
    end
  end

  describe "#request"

  describe "#get_zones" do
    it "gets back a list of zones" do
      VCR.use_cassette("aws_zones", :record => :none) do
        conn = Route53::Connection.new(credentials('access_key'), credentials('secret_key'))
        expect(conn.get_zones.map(&:name)).to eq(['50projects.com.'])
      end
    end

    it "handles truncated responses"
    it "handles subqueries based on the hostedzone"
  end

  describe "#get_date" do
    let(:conn) { Route53::Connection.new(credentials('access_key'), credentials('secret_key')) }
    let(:expected_date) { "Mon, 27 Jan 2014 20:43:36 GMT" }

    before do
      VCR.turn_off!
      stub_request(:head, "https://route53.amazonaws.com/date").to_return(
        :headers => { 'Date' => expected_date }
      )
    end

    after do
      VCR.turn_on!
    end

    it "makes a request to amazon's /date endpoint" do
      expect(conn.get_date).to eq(expected_date)
    end

    it "doesn't make extra calls to the network after the first request" do
      expect(conn.get_date).to eq(expected_date)
      stub_request(:head, "https://route53.amazonaws.com/date").to_return(
        :headers => { 'Date' => 'Mon, 27 Jan 2014 23:59:59 GMT' }
      )
      expect(conn.get_date).to eq(expected_date)
    end

    it "makes a new call if the first date call was made longer than 30 seconds ago" do
      expect(conn.get_date).to eq(expected_date)
      current_time = Time.now
      Time.stub(:now => current_time + 31)
      stub_request(:head, "https://route53.amazonaws.com/date").to_return(
        :headers => { 'Date' => 'Mon, 27 Jan 2014 23:59:59 GMT' }
      )
      expect(conn.get_date).to eq('Mon, 27 Jan 2014 23:59:59 GMT')
    end
  end
end
