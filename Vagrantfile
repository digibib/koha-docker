# Bug in docker/packer needs to append slash in salt paths:
# https://github.com/mitchellh/packer/issues/1040
Vagrant.configure("2") do |config|
  config.ssh.forward_x11 = true
  config.ssh.forward_agent = true

  config.vm.provider "virtualbox" do |vb|
    vb.customize ["modifyvm", :id, "--memory", "1024"]
  end

  config.vm.box = "ubuntu/trusty64"
  config.vm.hostname = "kohadocker"


  config.vm.provision "shell", path: "pip_install.sh"

  config.vm.provision :shell, inline: <<SCRIPT
  pip install docker-py
SCRIPT

  # Temporary fix in order to make docker install on ubuntu/thrusty64,
  # until this issue is resolved:
  # https://github.com/mitchellh/vagrant/issues/5697
  config.vm.provision :shell,
    inline: "sudo apt-get update"

  config.vm.provision :docker do |d|
    d.version = "latest"
  end

end