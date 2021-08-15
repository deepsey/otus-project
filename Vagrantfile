MACHINES = {
  :"project-monitor" => {
        :box_name => "generic/centos8",
        :cpus => 1,
        :memory => 512,            
        :ip_addr => '192.168.100.6',
        :ssh_port => '2206'
  },
  :"project-backup" => {
        :box_name => "generic/centos8",
        :cpus => 1,
        :memory => 512,
        :ip_addr => '192.168.100.5',
        :ssh_port => '2205',
        :need_disks => true,                
        :disks => {
              :sata1 => {
              :dfile => './disk1_backup.vdi',
              :size => 4096,
              :port => 1
              }
        }                
  },
  :"project-bastion" => {
        :box_name => "generic/centos8",
        :cpus => 1,
        :memory => 512,   
        :public => {:ip => '192.168.0.100'},                 
        :ip_addr => '192.168.100.2',
        :ssh_port => '2202'
  },     
  :"project-web" => {
        :box_name => "generic/centos8",
        :cpus => 1,
        :memory => 512,            
        :ip_addr => '192.168.100.3',
        :ssh_port => '2203',
  },
  :"project-mysql" => {
        :box_name => "centos/7",
        :cpus => 2,
        :memory => 1024,
        :ip_addr => '192.168.100.4',
        :ssh_port => '2204',
  }, 
}

Vagrant.configure("2") do |config|

  MACHINES.each do |boxname, boxconfig|

      config.vm.define boxname do |box|

          box.vm.box = boxconfig[:box_name]
          box.vm.host_name = boxname.to_s
          box.vm.network "forwarded_port", id: "ssh", guest: 22, host: boxconfig[:ssh_port]
          
          if boxconfig.key?(:public)
             box.vm.network "public_network", boxconfig[:public]
          end
          
          box.vm.network "private_network", ip: boxconfig[:ip_addr]

          box.vm.provider :virtualbox do |vb|
            vb.memory = boxconfig[:memory]
            vb.cpus = boxconfig[:cpus]
            vb.name = boxname.to_s  
            
            if vb.name == 'project-backup'
               needsController = false
               boxconfig[:disks].each do |dname, dconf|
			     unless File.exist?(dconf[:dfile])
			    	vb.customize ['createhd', '--filename', dconf[:dfile], '--variant', 'Fixed', '--size', dconf[:size]]
                                needsController =  true
                 end
	           end
               if needsController == true
                     vb.customize ["storagectl", :id, "--name", "SATA", "--add", "sata" ]
                     boxconfig[:disks].each do |dname, dconf|
                         vb.customize ['storageattach', :id,  '--storagectl', 'SATA', '--port', dconf[:port], '--device', 0, '--type', 'hdd', '--medium', dconf[:dfile]]
                     end
               end
            
            end   
            
                   
          end
          

      end
  end
end
