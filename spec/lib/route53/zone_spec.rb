require 'spec_helper'

describe Route53::Zone do
  let(:conn) {
    Route53::Connection.new(
      credentials('access_key'),
      credentials('secret_key')
    )
  }
  let(:sample_zone) { Route53::Zone.new("50projects.com.", "/hostedzone/Z3HXUG22R8JWBK", conn) }

  describe "#initialize" do
    it "auto sets the name to end with a '.'" do
      zone = Route53::Zone.new('foo', '/hostedzone/bar', conn)
      expect(zone.name).to eq('foo.')
    end
  end

  describe "#nameservers" do
    it "returns the name servers assigned to a zone" do
      VCR.use_cassette("aws_zone", :record => :none) do
        expected_nameservers = ["ns-535.awsdns-02.net", "ns-1725.awsdns-23.co.uk", "ns-308.awsdns-38.com", "ns-1452.awsdns-53.org"]
        expect(sample_zone.nameservers).to eq(expected_nameservers)
      end
    end
  end

  describe "#delete_zone" do
    it "deletes a zone" do
      VCR.use_cassette("aws_zone_delete", :record => :none) do
        zone = Route53::Zone.new("example.com.", '/hostedzone/Z3E84CELCS8770', conn)
        resp = zone.delete_zone
        expect(resp.pending?).to be_truthy
        expect(resp.error?).to be_falsey
      end
    end
  end

  describe "#create_zone" do
    it "creates a zone" do
      VCR.use_cassette("aws_zone", :record => :none) do
        new_zone = Route53::Zone.new("example.com.", nil, conn)
        resp = new_zone.create_zone
        expect(resp.pending?).to be_truthy
        expect(resp.error?).to be_falsey
        expect(new_zone.host_url).to eq('/hostedzone/Z3E84CELCS8770')
      end
    end
  end

  describe "#get_records" do
    it "pulls records" do
      VCR.use_cassette("aws_zone_records", :record => :none) do
        zone_records = sample_zone.get_records
        bar_50_proj = zone_records.detect { |r| r.name == 'bar.50projects.com.' }
        foo_50_proj = zone_records.detect { |r| r.name == 'foo.50projects.com.' }
        expect(bar_50_proj.values).to eq(['www.google.com'])
        expect(foo_50_proj.values).to eq(['www.groupon.com'])
      end
    end

    it "filters by type" do
      VCR.use_cassette("aws_zone_records", :record => :none) do
        a_records = sample_zone.get_records('A')
        sample_a_record = a_records.detect { |r| r.name == 'arecord.50projects.com.' }
        expect(a_records.map(&:type).uniq).to eq(['A'])
        expect(sample_a_record.values).to eq(['8.8.8.8'])
      end
    end
  end
end
