# Copyright © 2025-26 l5yth & contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# frozen_string_literal: true

require "spec_helper"

RSpec.describe PotatoMesh::Application do
  describe ".canonicalize_configured_instance_domain" do
    subject(:canonicalize) { described_class.canonicalize_configured_instance_domain(input) }

    context "with an IPv6 URL" do
      let(:input) { "http://[::1]" }

      it "retains brackets around the literal" do
        expect(canonicalize).to eq("[::1]")
      end
    end

    context "with an IPv6 URL including a non-default port" do
      let(:input) { "http://[::1]:8080" }

      it "keeps the literal bracketed and appends the port" do
        expect(canonicalize).to eq("[::1]:8080")
      end
    end

    context "with a bare IPv6 literal" do
      let(:input) { "::1" }

      it "wraps the literal in brackets" do
        expect(canonicalize).to eq("[::1]")
      end
    end

    context "with a bare IPv6 literal and port" do
      let(:input) { "::1:9000" }

      it "wraps the literal in brackets and preserves the port" do
        expect(canonicalize).to eq("[::1]:9000")
      end
    end

    context "with an IPv4 literal" do
      let(:input) { "http://127.0.0.1" }

      it "returns the literal without brackets" do
        expect(canonicalize).to eq("127.0.0.1")
      end
    end
  end

  describe ".http_listen_url" do
    it "formats IPv4 bind addresses" do
      expect(described_class.http_listen_url("0.0.0.0", 41_447)).to eq("http://0.0.0.0:41447")
    end

    it "brackets IPv6 literals" do
      expect(described_class.http_listen_url("::1", 8080)).to eq("http://[::1]:8080")
    end

    it "passes hostnames through unchanged" do
      expect(described_class.http_listen_url("localhost", 1)).to eq("http://localhost:1")
    end
  end

  describe ".log_web_listen_urls" do
    let(:io) { StringIO.new }
    let(:app_logger) { Logger.new(io) }
    let(:settings_double) { Struct.new(:bind, :port, :logger).new(bind, port, app_logger) }
    let(:bind) { "0.0.0.0" }
    let(:port) { 41_447 }

    before do
      allow(described_class).to receive(:settings).and_return(settings_double)
    end

    it "logs binding and LAN on one line when they differ" do
      allow(described_class).to receive(:discover_local_ip_address).and_return("192.168.0.50")

      described_class.log_web_listen_urls

      expect(io.string).to include("web server: bound http://0.0.0.0:41447 (LAN http://192.168.0.50:41447)")
    end

    it "logs a single listen line when bind and LAN URLs match" do
      allow(described_class).to receive(:discover_local_ip_address).and_return("127.0.0.1")
      settings_double.bind = "127.0.0.1"

      described_class.log_web_listen_urls

      expect(io.string).to include("web server: listening on http://127.0.0.1:41447")
      expect(io.string).not_to include("LAN ")
    end

    it "skips logging when the logger is nil" do
      settings_double.logger = nil
      allow(described_class).to receive(:discover_local_ip_address).and_return("10.0.0.1")

      described_class.log_web_listen_urls

      expect(io.string).to eq("")
    end
  end

  describe ".ip_address_candidates and .discover_local_ip_address with no interfaces" do
    it "returns an empty list when Socket.ip_address_list returns nothing" do
      allow(Socket).to receive(:ip_address_list).and_return([])

      candidates = described_class.ip_address_candidates

      expect(candidates).to eq([])
    end

    it "falls back to 127.0.0.1 when there are no candidate addresses at all" do
      allow(Socket).to receive(:ip_address_list).and_return([])

      result = described_class.discover_local_ip_address

      expect(result).to eq("127.0.0.1")
    end
  end

  describe ".discover_local_ip_address with IPv6-only addresses" do
    it "returns the non-loopback IPv6 address when only IPv6 is available" do
      # Simulate a host that has only a loopback (::1) and a link-local fe80::
      # address – both are non-IPv4, but the link-local candidate is picked
      # as the non-loopback fallback.
      loopback_addr = instance_double(
        Addrinfo,
        ip?: true,
        ipv4?: false,
        ipv4_loopback?: false,
        ipv6_loopback?: true,
        ip_address: "::1",
      )
      link_local_addr = instance_double(
        Addrinfo,
        ip?: true,
        ipv4?: false,
        ipv4_loopback?: false,
        ipv6_loopback?: false,
        ip_address: "fe80::1",
      )

      allow(Socket).to receive(:ip_address_list).and_return([loopback_addr, link_local_addr])

      result = described_class.discover_local_ip_address

      # The first non-loopback address (fe80::1) should be returned.
      expect(result).to eq("fe80::1")
    end

    it "returns the loopback address when every candidate is loopback" do
      loopback_addr = instance_double(
        Addrinfo,
        ip?: true,
        ipv4?: false,
        ipv4_loopback?: false,
        ipv6_loopback?: true,
        ip_address: "::1",
      )

      allow(Socket).to receive(:ip_address_list).and_return([loopback_addr])

      result = described_class.discover_local_ip_address

      expect(result).to eq("::1")
    end
  end
end
