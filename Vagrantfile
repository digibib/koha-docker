# Bug in docker/packer needs to append slash in salt paths:
# https://github.com/mitchellh/packer/issues/1040
Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/trusty64"
  config.vm.hostname = "ls-ext"
  config.vm.provision :docker do |d|
    d.pull_images "ubuntu"
  end
  # Docker exports only current folder, so need to put all in one place
  config.vm.synced_folder "../../salt", "/vagrant/salt"
  config.vm.synced_folder "../../pillar", "/vagrant/pillar"  

  config.vm.provision :shell, :inline => <<-PREPARE

  #apt-get -y update
  #apt-get install -y wget unzip curl

  #mkdir -p /home/vagrant/packer
  #cd /home/vagrant/packer
  #wget --quiet https://dl.bintray.com/mitchellh/packer/packer_0.7.1_linux_amd64.zip
  #unzip packer_0.7.1_linux_amd64.zip
  #echo "export PATH=$PATH:/home/vagrant/packer" > /home/vagrant/.bashrc

PREPARE
  
end