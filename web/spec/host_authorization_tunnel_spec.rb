# frozen_string_literal: true

require_relative "spec_helper"

RSpec.describe PotatoMesh::Application do
  describe "DEVELOPMENT_TUNNEL_HOST_SUFFIXES" do
    it "includes common HTTPS dev tunnel domains so HostAuthorization allows cloudflared/ngrok" do
      expect(described_class::DEVELOPMENT_TUNNEL_HOST_SUFFIXES).to include(
        ".trycloudflare.com",
        ".ngrok-free.app",
      )
    end
  end
end
