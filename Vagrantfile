# to make sure all nodes are created in order, we
# have to force a --no-parallel execution.
ENV['VAGRANT_NO_PARALLEL'] = 'yes'

Vagrant.configure('2') do |config|
  config.vm.provider :libvirt do |lv, config|
    lv.memory = 2048
    lv.cpus = 2
    lv.cpu_mode = 'host-passthrough'
    # lv.nested = true
    lv.keymap = 'pt'
    config.vm.synced_folder '.', '/vagrant', type: 'nfs'
  end

  config.vm.provider :virtualbox do |vb|
    vb.linked_clone = true
    vb.memory = 2048
    vb.cpus = 2
    vb.customize ["modifyvm", :id, "--clipboard-mode", "bidirectional"]
  end

  config.vm.define 'builder' do |config|
    config.vm.box = 'ubuntu-18.04-amd64'
    config.vm.hostname = 'builder.test'
    config.vm.provision :shell, path: 'provision-base.sh'
    config.vm.provision :shell, path: 'provision-tools.sh'
  end
end
