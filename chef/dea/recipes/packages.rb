packages = %w(
  debootstrap
  ruby1.9.3
  build-essential
  quota
  libcurl4-gnutls-dev
  libxml2-dev
  libxslt-dev
  golang
  redis-server
  zip
  unzip
  curl
)

packages.each do |package_name|
  package package_name do
    action :install
  end
end

gem_package "bundler" do
  action :install
  gem_binary "/usr/bin/gem"
end
