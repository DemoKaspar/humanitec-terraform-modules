[vms]
%{for ip in instance_ips~}
${ip} ansible_user=${ssh_username} ansible_ssh_private_key_file=${ssh_key_file} ansible_ssh_common_args='-o StrictHostKeyChecking=no'
%{endfor~}