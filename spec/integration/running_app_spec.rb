require "spec_helper"
require "securerandom"

describe "Running an app", :type => :integration, :requires_warden => true do
  let(:nats) { NatsHelper.new }
  let(:unstaged_url) { "http://localhost:9999/unstaged/sinatra" }
  let(:staged_url) { "http://localhost:9999/staged/sinatra" }
  let(:buildpack_cache_download_uri) { "http://localhost:9999/buildpack_cache" }
  let(:buildpack_cache_upload_uri) { "http://localhost:9999/buildpack_cache" }
  let(:app_id) { SecureRandom.hex(8) }
  let(:original_memory) do
    2 * 2048 # from config/dea.yml
  end

  before do
    setup_fake_buildpack("start_command")

    nats.request("staging", {
      "async" => false,
      "app_id" => app_id,
      "properties" => {
        "buildpack" => fake_buildpack_url("start_command"),
      },
      "download_uri" => unstaged_url,
      "upload_uri" => staged_url,
      "buildpack_cache_upload_uri" => buildpack_cache_upload_uri,
      "buildpack_cache_download_uri" => buildpack_cache_download_uri
    })
  end

  before do
    nats.publish("dea.#{dea_id}.start", {
      "index" => 1,
      "droplet" => app_id,
      "version" => "some-version",
      "name" => "some-app-name",
      "uris" => [],
      "prod" => false,
      "sha1" => sha1_url(staged_url),
      "executableUri" => staged_url,
      "cc_partition" => "foo",
      "limits" => {
        "mem" => 64,
        "disk" => 128,
        "fds" => 32
      },
      "services" => []
    })
    wait_until_instance_started(app_id)
  end

  after do
    nats.publish("dea.stop", { "droplet" => app_id })
    wait_until_instance_gone(app_id)
  end

  describe "starting the app" do
    it "decreases the dea's available memory" do
      expect(dea_memory).to eql(original_memory - (64 * 9/8))
    end
  end

  describe "stopping the app" do
    it "restores the dea's available memory" do
      nats.publish("dea.stop", { "droplet" => app_id })
      wait_until_instance_gone(app_id)
      expect(dea_memory).to eql(original_memory)
    end
  end

  def wait_until_instance_started(app_id)
    wait_until do
      nats.request("dea.find.droplet", {
        "droplet" => app_id,
        "states" => ["RUNNING"]
      }, :timeout => 1)
    end
  end

  def wait_until_instance_gone(app_id)
    wait_until do
      !nats.request("dea.find.droplet", {
        "droplet" => app_id,
      }, :timeout => 1)
    end
  end

  def wait_until(&block)
    Timeout.timeout(5) do
      loop { return if block.call }
    end
  end

  def sha1_url(url)
    `curl --silent #{url} | sha1sum`.split(/\s/).first
  end
end
