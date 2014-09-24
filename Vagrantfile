# Bug in docker/packer needs to append slash in salt paths:
# https://github.com/mitchellh/packer/issues/1040
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/trusty64"
  config.vm.hostname = "ls-ext"
  config.vm.provision :docker do |d|
    d.pull_images "ubuntu"
  end
  # Docker exports only current folder, so need to put all in one place

end
