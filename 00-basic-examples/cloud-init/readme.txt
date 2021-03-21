https://cloudinit.readthedocs.io/en/latest/topics/modules.html#write-files
using write_files with cloud-init, to append content to a file:

write_files:
  - path: /home/user/some-file
    content: | 
       Line to append!
    append: true




https://azure.microsoft.com/en-us/blog/custom-data-and-cloud-init-on-windows-azure/
https://docs.microsoft.com/en-us/azure/templates/microsoft.compute/virtualmachines?tabs=json
https://docs.microsoft.com/en-us/azure/virtual-machines/linux/using-cloud-init

https://cloudinit.readthedocs.io/en/latest/topics/examples.html